/**
 * Quantis Voice Bridge v3 — Jarvis Ultra-Responsive Mode
 * 
 * Corrections & Optimisations majeures :
 * 1. Déblocage automatique de l'AudioContext dès le premier clic/touche utilisateur
 * 2. ClapDetector calibré pour les pièces réelles (détection par ratio d'énergie + fenêtre 1000ms)
 * 3. Finalisation automatique du transcript : si silence (1.5s) ou clic "Valider", le texte partiel est IMMÉDIATEMENT soumis
 * 4. Chime audio de réveil (bip sci-fi discret) pour confirmation sonore immédiate
 * 5. Tolérance de silence et auto-restart robuste
 */
(function() {
  'use strict';

  // ═══════════════════════════════════════════
  // AUDIO FEEDBACK (CHIMES JARVIS)
  // ═══════════════════════════════════════════
  const SoundFx = {
    playWakeChime: function(audioCtx) {
      if (!audioCtx || audioCtx.state !== 'running') return;
      try {
        const now = audioCtx.currentTime;
        const osc1 = audioCtx.createOscillator();
        const osc2 = audioCtx.createOscillator();
        const gain = audioCtx.createGain();

        osc1.type = 'sine';
        osc1.frequency.setValueAtTime(587.33, now); // D5
        osc1.frequency.exponentialRampToValueAtTime(880, now + 0.12); // A5

        osc2.type = 'sine';
        osc2.frequency.setValueAtTime(880, now + 0.12);
        osc2.frequency.exponentialRampToValueAtTime(1174.66, now + 0.24); // D6

        gain.gain.setValueAtTime(0.12, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);

        osc1.connect(gain);
        osc2.connect(gain);
        gain.connect(audioCtx.destination);

        osc1.start(now);
        osc1.stop(now + 0.12);
        osc2.start(now + 0.12);
        osc2.stop(now + 0.35);
      } catch (_) {}
    }
  };

  // ═══════════════════════════════════════════
  // CLAP DETECTOR — Détection de double clap réaliste
  // ═══════════════════════════════════════════
  const ClapDetector = {
    audioContext: null,
    analyser: null,
    stream: null,
    isRunning: false,
    
    // Paramètres acoustiques adaptés aux micros et pièces réelles
    MIN_THRESHOLD: 0.12,       // Seuil minimal absolu
    CLAP_MAX_DURATION: 320,    // Durée max d'un clap incluant réverbération (ms)
    DOUBLE_CLAP_WINDOW: 1000,  // Intervalle max entre 2 claps (1 seconde)
    COOLDOWN: 1500,            // Pause anti-rebond après activation
    
    _lastClapTime: 0,
    _clapCount: 0,
    _lastActivation: 0,
    _rafId: null,
    _isClapPhase: false,
    _clapStartTime: 0,
    _ambientNoiseLevel: 0.03,
    
    start: function(onWakeUp) {
      const self = this;
      if (self._unsupported) return Promise.resolve();
      self._onWakeUp = onWakeUp;
      if (self.isRunning && self.audioContext) {
        if (self.audioContext.state === 'suspended') {
          self.audioContext.resume();
        }
        return Promise.resolve();
      }

      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        self._unsupported = true;
        console.warn('[ClapDetector] getUserMedia non supporté');
        return Promise.resolve();
      }

      return navigator.mediaDevices.getUserMedia({ audio: true, video: false })
        .then(function(stream) {
          self.stream = stream;
          const AC = window.AudioContext || window.webkitAudioContext;
          self.audioContext = new AC();
          const source = self.audioContext.createMediaStreamSource(stream);
          self.analyser = self.audioContext.createAnalyser();
          self.analyser.fftSize = 512;
          self.analyser.smoothingTimeConstant = 0.2;
          source.connect(self.analyser);
          
          self.isRunning = true;
          self._detect();
          console.log('[ClapDetector] Surveillance active. AudioContext state:', self.audioContext.state);
        })
        .catch(function(err) {
          console.warn('[ClapDetector] Micro en attente d\'autorisation utilisateur:', err.message);
        });
    },
    
    pause: function() {
      this.isRunning = false;
      if (this._rafId) {
        cancelAnimationFrame(this._rafId);
        this._rafId = null;
      }
    },
    
    resume: function() {
      if (!this.analyser || !this.audioContext) return;
      if (this.audioContext.state === 'suspended') {
        this.audioContext.resume();
      }
      this.isRunning = true;
      this._clapCount = 0;
      this._detect();
    },
    
    _detect: function() {
      const self = this;
      if (!self.isRunning || !self.analyser) return;
      
      const bufferLength = self.analyser.frequencyBinCount;
      const dataArray = new Float32Array(bufferLength);
      
      function loop() {
        if (!self.isRunning) return;
        
        self.analyser.getFloatTimeDomainData(dataArray);
        
        // Calculer le pic d'amplitude et la moyenne du signal
        let peak = 0;
        let sum = 0;
        for (let i = 0; i < bufferLength; i++) {
          const v = Math.abs(dataArray[i]);
          if (v > peak) peak = v;
          sum += v;
        }
        const avg = sum / bufferLength;
        // Mise à jour lente du bruit ambiant
        self._ambientNoiseLevel = self._ambientNoiseLevel * 0.95 + avg * 0.05;

        // Rapport d'énergie instantanée (pic / moyenne) pour détecter le claquement sec
        const energyRatio = avg > 0.005 ? (peak / avg) : (peak / 0.005);
        const now = performance.now();
        
        // Un clap produit un pic > 0.12 avec une impulsion soudaine (energyRatio > 2.5)
        if (peak > 0.12 && energyRatio > 2.2 && !self._isClapPhase) {
          self._isClapPhase = true;
          self._clapStartTime = now;
          
          const timeSinceLastClap = now - self._lastClapTime;
          self._lastClapTime = now;
          
          if (self._clapCount === 0) {
            self._clapCount = 1;
            console.log('[ClapDetector] 👏 Premier clap détecté (peak=' + peak.toFixed(2) + '). En attente du 2ème...');
          } else if (timeSinceLastClap < self.DOUBLE_CLAP_WINDOW && timeSinceLastClap > 100) {
            // DOUBLE CLAP CONFIRMÉ !
            const timeSinceActivation = now - self._lastActivation;
            if (timeSinceActivation > self.COOLDOWN) {
              self._lastActivation = now;
              self._clapCount = 0;
              console.log('[ClapDetector] 👏👏 Double clap confirmé ! Wake-up Quantis !');
              SoundFx.playWakeChime(self.audioContext);
              if (self._onWakeUp) self._onWakeUp();
            }
          }
          
          setTimeout(function() {
            if (now === self._lastClapTime) {
              self._clapCount = 0;
            }
          }, self.DOUBLE_CLAP_WINDOW + 100);
        } else if (self._isClapPhase && (now - self._clapStartTime > 100)) {
          // Relâchement après 100ms de période réfractaire
          self._isClapPhase = false;
        }
        
        self._rafId = requestAnimationFrame(loop);
      }
      
      loop();
    }
  };

  // ═══════════════════════════════════════════
  // AUDIO ANALYSER — Niveau pour le visualiseur
  // ═══════════════════════════════════════════
  const AudioAnalyser = {
    analyser: null,
    _rafId: null,
    isRunning: false,
    
    start: function(audioContext, stream, onLevel) {
      if (this.isRunning) return;
      try {
        const source = audioContext.createMediaStreamSource(stream);
        this.analyser = audioContext.createAnalyser();
        this.analyser.fftSize = 256;
        source.connect(this.analyser);
        this.isRunning = true;
        this._onLevel = onLevel;
        this._loop();
      } catch (_) {}
    },
    
    stop: function() {
      this.isRunning = false;
      if (this._rafId) {
        cancelAnimationFrame(this._rafId);
        this._rafId = null;
      }
    },
    
    _loop: function() {
      const self = this;
      if (!self.isRunning || !self.analyser) return;
      
      const dataArray = new Uint8Array(self.analyser.frequencyBinCount);
      self.analyser.getByteFrequencyData(dataArray);
      let sum = 0;
      for (let i = 0; i < dataArray.length; i++) sum += dataArray[i];
      const normalized = Math.min(1.0, (sum / dataArray.length) / 100.0);
      if (self._onLevel) self._onLevel(normalized);
      
      self._rafId = requestAnimationFrame(function() { self._loop(); });
    }
  };

  // ═══════════════════════════════════════════
  // VOICE RECOGNIZER — STT ultra-réactif
  // ═══════════════════════════════════════════
  const VoiceRecognizer = {
    recognition: null,
    isListening: false,
    _autoRestart: false,
    _silenceTimer: null,
    _currentAccumulatedText: '',
    SILENCE_TIMEOUT: 1800,  // 1.8s de silence après avoir parlé -> validation auto !
    
    start: function(lang, callbacks) {
      const self = this;
      if (self.isListening) self.stop();
      
      const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (!SR) {
        if (callbacks.onError) callbacks.onError('SpeechRecognition non supporté');
        return;
      }
      
      self._callbacks = callbacks;
      self._currentAccumulatedText = '';
      self.recognition = new SR();
      self.recognition.lang = lang || 'fr-FR';
      self.recognition.continuous = true;
      self.recognition.interimResults = true;
      self.recognition.maxAlternatives = 1;
      self._autoRestart = true;
      
      self.recognition.onstart = function() {
        self.isListening = true;
        if (callbacks.onListenStart) callbacks.onListenStart();

        // Détection Brave : avertir l'utilisateur si aucun résultat ne parvient à cause du blocage Brave
        const isBrave = (navigator.brave && typeof navigator.brave.isBrave === 'function') || 
                        navigator.userAgent.includes('Brave');
        if (isBrave) {
          setTimeout(function() {
            if (self.isListening && !self._currentAccumulatedText) {
              console.warn('[VoiceRecognizer] Brave bloque la reconnaissance vocale Google par défaut.');
              if (callbacks.onPartialTranscript) {
                callbacks.onPartialTranscript("⚠️ Brave bloque la voix Google : Activez l'option dans brave://settings/privacy ou utilisez Google Chrome.");
              }
            }
          }, 3500);
        }
      };
      
      self.recognition.onresult = function(event) {
        let interim = '';
        let finalChunk = '';
        
        for (let i = event.resultIndex; i < event.results.length; ++i) {
          const transcript = event.results[i][0].transcript;
          if (event.results[i].isFinal) {
            finalChunk += transcript + ' ';
          } else {
            interim += transcript;
          }
        }
        
        if (finalChunk.trim().length > 0) {
          self._currentAccumulatedText = (self._currentAccumulatedText + ' ' + finalChunk).trim();
        }
        
        const fullCurrentText = (self._currentAccumulatedText + ' ' + interim).trim();
        
        if (fullCurrentText.length > 0) {
          if (callbacks.onPartialTranscript) {
            callbacks.onPartialTranscript(fullCurrentText);
          }
          // Armer le timer de silence automatique
          self._resetSilenceTimer(fullCurrentText);
        }
      };
      
      self.recognition.onerror = function(event) {
        console.warn('[VoiceRecognizer] Event error:', event.error);
        if (event.error === 'no-speech' || event.error === 'aborted') {
          return;
        }
        if (callbacks.onError) callbacks.onError(event.error);
      };
      
      self.recognition.onend = function() {
        console.log('[VoiceRecognizer] Session terminée. autoRestart=', self._autoRestart, 'isListening=', self.isListening);
        if (self._autoRestart && self.isListening) {
          // Attendre 150ms que Chrome libère l'interface audio avant de redémarrer
          setTimeout(function() {
            if (self._autoRestart && self.isListening) {
              try {
                self.recognition.start();
                console.log('[VoiceRecognizer] Auto-restart actif réussi.');
              } catch (e) {
                console.log('[VoiceRecognizer] Nouvelle instance après coupure...');
                try {
                  self.start(lang, callbacks);
                } catch(e2) {
                  console.warn('[VoiceRecognizer] Échec start instance:', e2);
                }
              }
            }
          }, 150);
          return;
        }
        self._flushFinal();
        self.isListening = false;
        self._clearSilenceTimer();
        if (callbacks.onListenEnd) callbacks.onListenEnd();
      };
      
      try {
        self.recognition.start();
      } catch(err) {
        console.error('[VoiceRecognizer] Erreur démarrage:', err);
        if (callbacks.onError) callbacks.onError(err.toString());
      }
    },
    
    _flushFinal: function() {
      const self = this;
      if (self._currentAccumulatedText && self._currentAccumulatedText.trim().length > 0) {
        const textToSubmit = self._currentAccumulatedText.trim();
        self._currentAccumulatedText = '';
        if (self._callbacks && self._callbacks.onFinalTranscript) {
          console.log('[VoiceRecognizer] Envoi transcription finale:', textToSubmit);
          self._callbacks.onFinalTranscript(textToSubmit);
        }
      }
    },
    
    stop: function() {
      this._autoRestart = false;
      this._clearSilenceTimer();
      this._flushFinal();
      if (this.recognition) {
        try { this.recognition.stop(); } catch(e) {}
      }
      this.isListening = false;
    },
    
    _resetSilenceTimer: function(currentText) {
      const self = this;
      self._clearSilenceTimer();
      self._silenceTimer = setTimeout(function() {
        if (currentText && currentText.trim().length > 0) {
          console.log('[VoiceRecognizer] Silence détecté après parole. Validation automatique de :', currentText);
          self._currentAccumulatedText = currentText;
          self._flushFinal();
          self.stop();
        }
      }, self.SILENCE_TIMEOUT);
    },
    
    _clearSilenceTimer: function() {
      if (this._silenceTimer) {
        clearTimeout(this._silenceTimer);
        this._silenceTimer = null;
      }
    }
  };

  // ═══════════════════════════════════════════
  // VOICE SYNTH — Synthèse vocale fluide
  // ═══════════════════════════════════════════
  const VoiceSynth = {
    currentUtterance: null,
    isSpeaking: false,
    _selectedVoice: null,
    
    init: function() {
      const self = this;
      if (!('speechSynthesis' in window)) return;
      
      function loadVoices() {
        const voices = window.speechSynthesis.getVoices();
        if (voices.length > 0) {
          self._selectedVoice = voices.find(function(v) {
            return v.lang.startsWith('fr') && 
                   (v.name.includes('Google') || v.name.includes('Natural') || 
                    v.name.includes('Thomas') || v.name.includes('Henri') ||
                    v.name.includes('Audrey'));
          }) || voices.find(function(v) { return v.lang.startsWith('fr'); });
        }
      }
      
      loadVoices();
      if (window.speechSynthesis.onvoiceschanged !== undefined) {
        window.speechSynthesis.onvoiceschanged = loadVoices;
      }
    },
    
    speak: function(text, callbacks) {
      const self = this;
      if (!('speechSynthesis' in window)) return;
      
      try {
        if (window.speechSynthesis.paused) {
          window.speechSynthesis.resume();
        }
      } catch(_) {}
      
      window.speechSynthesis.cancel();
      if (!text || text.trim() === '') return;
      
      let clean = text
        .replace(/[*#_`~>|]/g, ' ')
        .replace(/\[([^\]]+)\]\([^\)]+\)/g, '$1')
        .replace(/\n+/g, '. ')
        .replace(/\s+/g, ' ')
        .trim();
      
      const utterance = new SpeechSynthesisUtterance(clean);
      utterance.lang = 'fr-FR';
      utterance.rate = 1.05;
      utterance.pitch = 1.0;
      
      if (self._selectedVoice) {
        utterance.voice = self._selectedVoice;
      }
      
      utterance.onstart = function() {
        self.isSpeaking = true;
        if (callbacks && callbacks.onStart) callbacks.onStart();
      };
      
      utterance.onboundary = function(event) {
        if (event.name === 'word' && callbacks && callbacks.onWord) {
          const word = clean.substring(event.charIndex, event.charIndex + (event.charLength || 6));
          callbacks.onWord(word, event.charIndex, clean.length);
        }
      };
      
      utterance.onend = function() {
        self.isSpeaking = false;
        if (callbacks && callbacks.onEnd) callbacks.onEnd();
      };
      
      utterance.onerror = function() {
        self.isSpeaking = false;
        if (callbacks && callbacks.onEnd) callbacks.onEnd();
      };
      
      self.currentUtterance = utterance;
      window.speechSynthesis.speak(utterance);
    },
    
    stop: function() {
      this.isSpeaking = false;
      if ('speechSynthesis' in window) {
        window.speechSynthesis.cancel();
      }
    }
  };

  // ═══════════════════════════════════════════
  // QUANTIS VOICE BRIDGE — API window.QuantisVoice
  // ═══════════════════════════════════════════
  window.QuantisVoice = {
    mode: 'standby',
    clapDetector: ClapDetector,
    recognizer: VoiceRecognizer,
    synth: VoiceSynth,
    audioAnalyser: AudioAnalyser,
    
    listeners: {
      onWakeUp: null,
      onPartialTranscript: null,
      onFinalTranscript: null,
      onAudioLevel: null,
      onListenStart: null,
      onListenEnd: null,
      onSpeakStart: null,
      onSpeakEnd: null,
      onSpeakWord: null,
      onSilenceTimeout: null,
      onError: null
    },
    
    initJarvis: function() {
      const self = this;
      VoiceSynth.init();
      
      // Démarrer la détection de claps en arrière-plan
      ClapDetector.start(function() {
        console.log('[QuantisVoice] 👏👏 Double clap confirmé ! Démarrage automatique de l\'écoute...');
        self.startListening();
        if (self.listeners.onWakeUp) {
          self.listeners.onWakeUp();
        }
      });
      
      console.log('[QuantisVoice] Initialisé. Tapez 2 fois dans les mains 👏👏 ou cliquez le micro.');
      return true;
    },
    
    startListening: function(lang) {
      const self = this;
      self.mode = 'active';
      
      // Débloquer AudioContext si suspendu
      if (ClapDetector.audioContext && ClapDetector.audioContext.state === 'suspended') {
        ClapDetector.audioContext.resume();
      }
      
      // Chime discret à l'activation
      if (ClapDetector.audioContext) {
        SoundFx.playWakeChime(ClapDetector.audioContext);
      }
      
      ClapDetector.pause();
      
      function hookAnalyser(ctx, stream) {
        AudioAnalyser.start(ctx, stream, function(level) {
          if (self.listeners.onAudioLevel) self.listeners.onAudioLevel(level);
        });
      }

      if (ClapDetector.audioContext && ClapDetector.stream) {
        hookAnalyser(ClapDetector.audioContext, ClapDetector.stream);
      } else if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        navigator.mediaDevices.getUserMedia({ audio: true }).then(function(stream) {
          const AC = window.AudioContext || window.webkitAudioContext;
          if (!ClapDetector.audioContext) ClapDetector.audioContext = new AC();
          ClapDetector.stream = stream;
          hookAnalyser(ClapDetector.audioContext, stream);
        }).catch(function(_) {});
      }
      
      VoiceRecognizer.start(lang || 'fr-FR', {
        onListenStart: function() {
          if (self.listeners.onListenStart) self.listeners.onListenStart();
        },
        onPartialTranscript: function(text) {
          if (self.listeners.onPartialTranscript) self.listeners.onPartialTranscript(text);
        },
        onFinalTranscript: function(text) {
          if (self.listeners.onFinalTranscript) self.listeners.onFinalTranscript(text);
        },
        onListenEnd: function() {
          if (self.listeners.onListenEnd) self.listeners.onListenEnd();
        },
        onError: function(err) {
          if (self.listeners.onError) self.listeners.onError(err);
        }
      });
    },
    
    stopListening: function() {
      VoiceRecognizer.stop();
      AudioAnalyser.stop();
      this.mode = 'standby';
      ClapDetector.resume();
    },
    
    speak: function(text) {
      const self = this;
      self.mode = 'speaking';
      
      VoiceSynth.speak(text, {
        onStart: function() {
          if (self.listeners.onSpeakStart) self.listeners.onSpeakStart();
        },
        onWord: function(word, charIndex, totalLength) {
          if (self.listeners.onSpeakWord) self.listeners.onSpeakWord(word, charIndex, totalLength);
        },
        onEnd: function() {
          self.mode = 'standby';
          if (self.listeners.onSpeakEnd) self.listeners.onSpeakEnd();
          ClapDetector.resume();
        }
      });
    },
    
    stopSpeaking: function() {
      VoiceSynth.stop();
      this.mode = 'standby';
      ClapDetector.resume();
    },
    
    isSupported: function() {
      const hasSpeech = 'SpeechRecognition' in window || 'webkitSpeechRecognition' in window;
      const hasSynthesis = 'speechSynthesis' in window;
      const hasMic = !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
      return hasSpeech && hasSynthesis && hasMic;
    },
    
    init: function() { return this.isSupported(); }
  };

  // ═══════════════════════════════════════════
  // AUTO-UNLOCK AUDIOCONTEXT SUR INTERACTION
  // ═══════════════════════════════════════════
  function autoUnlockAudio() {
    if (ClapDetector.audioContext && ClapDetector.audioContext.state === 'suspended') {
      ClapDetector.audioContext.resume().then(function() {
        console.log('[QuantisVoice] AudioContext débloqué avec succès suite à interaction.');
      });
    }
    // Si la surveillance des claps n'était pas active
    if (!ClapDetector.isRunning) {
      ClapDetector.start(function() {
        if (window.QuantisVoice.listeners.onWakeUp) {
          window.QuantisVoice.listeners.onWakeUp();
        }
      });
    }
  }

  if (typeof window !== 'undefined') {
    window.addEventListener('click', autoUnlockAudio, { passive: true });
    window.addEventListener('keydown', autoUnlockAudio, { passive: true });
    window.addEventListener('touchstart', autoUnlockAudio, { passive: true });
    window.addEventListener('load', function() {
      window.QuantisVoice.synth.init();
    });
  }
})();

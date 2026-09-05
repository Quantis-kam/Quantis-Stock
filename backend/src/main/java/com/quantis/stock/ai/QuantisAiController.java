package com.quantis.stock.ai;

import com.quantis.stock.ai.dto.ChatRequest;
import com.quantis.stock.ai.dto.ChatResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * Contrôleur REST pour l'assistant Quantis AI.
 *
 * Endpoints :
 * - POST /quantis/chat         — Envoyer un message à Quantis
 * - DELETE /quantis/chat/{id}  — Effacer une conversation
 * - GET  /quantis/suggestions  — Obtenir des suggestions contextuelles
 * - GET  /quantis/status       — Vérifier le statut de l'IA
 */
@Slf4j
@RestController
@RequestMapping("/quantis")
@RequiredArgsConstructor
public class QuantisAiController {

    private final QuantisAiService aiService;
    private final QuantisAiConfig aiConfig;

    /**
     * Envoie un message à l'assistant Quantis et reçoit une réponse.
     */
    @PostMapping("/chat")
    public ResponseEntity<ChatResponse> chat(
            @Valid @RequestBody ChatRequest request,
            Authentication authentication) {

        String userEmail = authentication.getName();
        log.info("Chat Quantis — User: {}, Message: {}", userEmail,
                request.getMessage().substring(0, Math.min(50, request.getMessage().length())));

        ChatResponse response = aiService.chat(request, userEmail);
        return ResponseEntity.ok(response);
    }

    /**
     * Endpoint SSE pour streamer les étapes d'exécution et de réflexion en temps réel.
     */
    @PostMapping(value = "/chat-stream", produces = org.springframework.http.MediaType.TEXT_EVENT_STREAM_VALUE)
    public org.springframework.web.servlet.mvc.method.annotation.SseEmitter chatStream(
            @Valid @RequestBody ChatRequest request,
            Authentication authentication) {

        String userEmail = authentication.getName();
        org.springframework.web.servlet.mvc.method.annotation.SseEmitter emitter = 
                new org.springframework.web.servlet.mvc.method.annotation.SseEmitter(60_000L);

        java.util.concurrent.CompletableFuture.runAsync(() -> {
            try {
                // 1. Étape d'analyse initiale
                emitter.send(org.springframework.web.servlet.mvc.method.annotation.SseEmitter.event()
                        .name("step")
                        .data(Map.of("step", "thinking", "label", "Quantis analyse votre demande...", "icon", "🧠")));

                // 2. Détection visuelle de l'outil pour feedback immédiat dans le HUD
                String msg = request.getMessage().toLowerCase();
                if (msg.contains("stock") || msg.contains("ajoute") || msg.contains("reapprovisionnement") || msg.contains("réapprovisionnement")) {
                    emitter.send(org.springframework.web.servlet.mvc.method.annotation.SseEmitter.event()
                            .name("step")
                            .data(Map.of("step", "tool_call", "label", "Mise à jour des stocks en base...", "icon", "📦")));
                } else if (msg.contains("rupture") || msg.contains("alerte")) {
                    emitter.send(org.springframework.web.servlet.mvc.method.annotation.SseEmitter.event()
                            .name("step")
                            .data(Map.of("step", "tool_call", "label", "Recherche des produits sous seuil critique...", "icon", "⚠️")));
                } else if (msg.contains("vente") || msg.contains("chiffre") || msg.contains("ca") || msg.contains("patrimoine")) {
                    emitter.send(org.springframework.web.servlet.mvc.method.annotation.SseEmitter.event()
                            .name("step")
                            .data(Map.of("step", "tool_call", "label", "Consolidation des données financières...", "icon", "💰")));
                }

                // 3. Exécution métier complète
                ChatResponse response = aiService.chat(request, userEmail);

                // 4. Notification de succès et résultat
                emitter.send(org.springframework.web.servlet.mvc.method.annotation.SseEmitter.event()
                        .name("step")
                        .data(Map.of("step", "tool_result", "label", "Action terminée avec succès", "icon", "✅")));

                // 5. Réponse finale pour synthèse vocale et affichage
                emitter.send(org.springframework.web.servlet.mvc.method.annotation.SseEmitter.event()
                        .name("complete")
                        .data(response));

                emitter.complete();
            } catch (Exception e) {
                log.error("Erreur streaming SSE Quantis: {}", e.getMessage(), e);
                try {
                    emitter.send(org.springframework.web.servlet.mvc.method.annotation.SseEmitter.event()
                            .name("error")
                            .data(Map.of("error", e.getMessage())));
                } catch (Exception ignored) {}
                emitter.completeWithError(e);
            }
        });

        return emitter;
    }

    /**
     * Efface l'historique d'une conversation.
     */
    @DeleteMapping("/chat/{conversationId}")
    public ResponseEntity<Map<String, String>> clearConversation(
            @PathVariable String conversationId) {
        aiService.clearConversation(conversationId);
        return ResponseEntity.ok(Map.of("status", "cleared", "conversationId", conversationId));
    }

    /**
     * Retourne les suggestions initiales pour le widget de chat.
     */
    @GetMapping("/suggestions")
    public ResponseEntity<List<String>> getSuggestions() {
        return ResponseEntity.ok(List.of(
            "📊 Comment va mon stock aujourd'hui ?",
            "⚠️ Y a-t-il des produits en rupture ?",
            "💰 Quel est le chiffre d'affaires ce mois-ci ?",
            "📦 Rechercher un produit",
            "➕ Ajouter un nouveau produit",
            "📈 Voir les ventes de l'année"
        ));
    }

    /**
     * Vérifie le statut de l'assistant IA.
     */
    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> getStatus() {
        return ResponseEntity.ok(Map.of(
            "enabled", aiConfig.isEnabled(),
            "provider", aiConfig.getProvider(),
            "model", aiConfig.getModel(),
            "assistantName", aiConfig.getAssistantName(),
            "hasApiKey", !aiConfig.getApiKey().isBlank()
        ));
    }
}

package com.quantis.stock.ai;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * Configuration de Quantis AI — Assistant intelligent de gestion de stock.
 *
 * Supporte deux modes :
 * - Cloud API (Gemini / OpenAI) — recommandé en production
 * - Ollama (local, gratuit) — pour le développement offline
 */
@Data
@Configuration
@ConfigurationProperties(prefix = "quantis.ai")
public class QuantisAiConfig {

    /** Active/désactive l'assistant IA */
    private boolean enabled = true;

    /** Provider : "gemini", "openai", ou "ollama" */
    private String provider = "gemini";

    /** Clé API pour le provider cloud (Gemini ou OpenAI) */
    private String apiKey = "";

    /** Modèle à utiliser */
    private String model = "gemini-2.0-flash";

    /** URL de base pour Ollama (mode local) */
    private String ollamaHost = "http://localhost:11434";

    /** Modèle Ollama à utiliser */
    private String ollamaModel = "qwen3:8b";

    /** Température (0.0 = déterministe, 1.0 = créatif) */
    private double temperature = 0.3;

    /** Nombre maximum de tokens en sortie */
    private int maxTokens = 4096;

    /** Nombre maximum de messages dans l'historique de conversation */
    private int maxHistoryMessages = 20;

    /** Timeout HTTP en secondes */
    private int timeoutSeconds = 60;

    /** Demander confirmation avant les actions destructives */
    private boolean confirmDestructiveActions = true;

    /**
     * Nom de l'assistant affiché dans le chat.
     */
    private String assistantName = "Quantis";
}

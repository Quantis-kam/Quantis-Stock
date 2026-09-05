package com.quantis.stock.ai.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * Réponse de Quantis AI au frontend.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatResponse {

    /** Message texte de l'assistant */
    private String message;

    /** ID de conversation */
    private String conversationId;

    /** Timestamp de la réponse */
    @Builder.Default
    private Instant timestamp = Instant.now();

    /** Actions exécutées par l'IA (pour affichage dans le chat) */
    private List<ExecutedAction> actions;

    /** Actions en attente de confirmation utilisateur */
    private PendingAction pendingAction;

    /** Suggestions de questions/actions suivantes */
    private List<String> suggestions;

    /** Données structurées à afficher (tableau, graphique, etc.) */
    private Map<String, Object> data;

    /** Type de la réponse pour le rendu frontend */
    @Builder.Default
    private ResponseType type = ResponseType.TEXT;

    public enum ResponseType {
        TEXT,           // Message texte simple
        ACTION_RESULT,  // Résultat d'une action exécutée
        CONFIRMATION,   // Demande de confirmation avant action
        DATA_TABLE,     // Données tabulaires à afficher
        CHART_DATA,     // Données pour un graphique
        ERROR           // Erreur
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ExecutedAction {
        private String name;
        private String description;
        private boolean success;
        private String result;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PendingAction {
        private String actionId;
        private String toolName;
        private String description;
        private Map<String, Object> parameters;
    }
}

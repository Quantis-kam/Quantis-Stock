package com.quantis.stock.ai.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import jakarta.validation.constraints.NotBlank;
import java.util.List;

/**
 * Requête de chat envoyée par le frontend Flutter.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatRequest {

    /** Message de l'utilisateur */
    @NotBlank(message = "Le message ne peut pas être vide")
    private String message;

    /** ID de conversation pour maintenir le contexte */
    private String conversationId;

    /** Historique des messages précédents (optionnel — le backend gère aussi) */
    private List<ChatMessage> history;

    /** Si true, l'utilisateur confirme une action proposée par l'IA */
    private boolean confirmAction;

    /** ID de l'action à confirmer */
    private String actionId;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ChatMessage {
        private String role;  // "user" ou "assistant"
        private String content;
    }
}

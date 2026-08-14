package com.quantis.stock.dto;

import lombok.Data;

import java.util.List;

/**
 * Requête de synchronisation en lot — reçoit toutes les actions faites hors-ligne.
 */
@Data
public class SyncRequest {

    private List<SyncAction> actions;

    @Data
    public static class SyncAction {
        /** UUID unique de l'action (idempotence) */
        private String uuid;

        /** Type: MOUVEMENT_STOCK, DOCUMENT, PAIEMENT, CLIENT, etc. */
        private String type;

        /** Payload JSON de l'action */
        private java.util.Map<String, Object> data;

        /** Timestamp côté client (ISO-8601) */
        private String clientTimestamp;
    }
}

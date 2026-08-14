package com.quantis.stock.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;

/**
 * Réponse de synchronisation — résultat par action.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SyncResponse {

    @Builder.Default
    private List<SyncResult> results = new ArrayList<>();

    private int totalReceived;
    private int totalProcessed;
    private int totalSkipped;
    private int totalFailed;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SyncResult {
        private String uuid;
        private String status; // OK, SKIPPED (doublon), FAILED
        private String message;
    }
}

package com.quantis.stock.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.quantis.stock.dto.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

/**
 * Service de synchronisation — traite les actions offline en lot.
 * Chaque action est idempotente grâce à son UUID.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SyncService {

    private final StockService stockService;
    private final ObjectMapper objectMapper;

    @Transactional
    public SyncResponse processBatch(List<SyncRequest.SyncAction> actions, String userEmail) {
        List<SyncResponse.SyncResult> results = new ArrayList<>();
        int processed = 0, skipped = 0, failed = 0;

        for (SyncRequest.SyncAction action : actions) {
            try {
                SyncResponse.SyncResult result = processAction(action, userEmail);
                results.add(result);
                switch (result.getStatus()) {
                    case "OK" -> processed++;
                    case "SKIPPED" -> skipped++;
                    case "FAILED" -> failed++;
                }
            } catch (Exception e) {
                log.error("Sync error for UUID {}: {}", action.getUuid(), e.getMessage());
                results.add(SyncResponse.SyncResult.builder()
                        .uuid(action.getUuid())
                        .status("FAILED")
                        .message(e.getMessage())
                        .build());
                failed++;
            }
        }

        log.info("Sync batch: {} received, {} processed, {} skipped, {} failed",
                actions.size(), processed, skipped, failed);

        return SyncResponse.builder()
                .results(results)
                .totalReceived(actions.size())
                .totalProcessed(processed)
                .totalSkipped(skipped)
                .totalFailed(failed)
                .build();
    }

    private SyncResponse.SyncResult processAction(SyncRequest.SyncAction action, String userEmail) {
        return switch (action.getType()) {
            case "MOUVEMENT_STOCK" -> processStockMovement(action, userEmail);
            default -> SyncResponse.SyncResult.builder()
                    .uuid(action.getUuid())
                    .status("FAILED")
                    .message("Type d'action inconnu: " + action.getType())
                    .build();
        };
    }

    private SyncResponse.SyncResult processStockMovement(SyncRequest.SyncAction action, String userEmail) {
        try {
            MouvementRequest request = objectMapper.convertValue(action.getData(), MouvementRequest.class);
            request.setUuidSync(action.getUuid());
            stockService.enregistrerMouvement(request, userEmail);
            return SyncResponse.SyncResult.builder()
                    .uuid(action.getUuid())
                    .status("OK")
                    .message("Mouvement enregistré")
                    .build();
        } catch (com.quantis.stock.exception.BusinessException e) {
            if (e.getMessage() != null && e.getMessage().contains("UUID déjà traité")) {
                return SyncResponse.SyncResult.builder()
                        .uuid(action.getUuid())
                        .status("SKIPPED")
                        .message("Doublon — déjà synchronisé")
                        .build();
            }
            throw e;
        }
    }
}

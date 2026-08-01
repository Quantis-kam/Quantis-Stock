package com.quantis.stock.service;

import com.quantis.stock.model.AuditLog;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.repository.AuditLogRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Service d'audit — enregistre les actions sensibles.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuditService {

    private final AuditLogRepository auditLogRepository;

    public void logAction(Utilisateur utilisateur, String action, String entite,
                          Long entiteId, String details, String ipAddress) {
        AuditLog auditLog = AuditLog.builder()
                .utilisateur(utilisateur)
                .action(action)
                .entite(entite)
                .entiteId(entiteId)
                .details(details)
                .ipAddress(ipAddress)
                .build();
        auditLogRepository.save(auditLog);
        log.debug("Audit: {} {} {} [id={}] par {}", action, entite, entiteId,
                utilisateur != null ? utilisateur.getEmail() : "system", ipAddress);
    }

    public void logLogin(Utilisateur utilisateur, String ipAddress) {
        logAction(utilisateur, "LOGIN", "Utilisateur", utilisateur.getId(), null, ipAddress);
    }

    public void logLogout(Utilisateur utilisateur, String ipAddress) {
        logAction(utilisateur, "LOGOUT", "Utilisateur", utilisateur.getId(), null, ipAddress);
    }
}

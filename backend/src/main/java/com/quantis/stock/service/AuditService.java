package com.quantis.stock.service;

import com.quantis.stock.model.AuditLog;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.repository.AuditLogRepository;
import com.quantis.stock.repository.UtilisateurRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

/**
 * Service d'audit — enregistre les actions sensibles.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuditService {

    private final AuditLogRepository auditLogRepository;
    private final UtilisateurRepository utilisateurRepository;

    public void logAction(Utilisateur utilisateur, String action, String entite,
                          Long entiteId, String details, String ipAddress) {
        String safeIp = ipAddress != null && ipAddress.length() > 45
                ? ipAddress.substring(0, 45)
                : ipAddress;
        try {
            AuditLog auditLog = AuditLog.builder()
                    .utilisateur(utilisateur)
                    .action(action)
                    .entite(entite)
                    .entiteId(entiteId)
                    .details(details)
                    .ipAddress(safeIp)
                    .build();
            auditLogRepository.save(auditLog);
            log.debug("Audit: {} {} {} [id={}] par {}", action, entite, entiteId,
                    utilisateur != null ? utilisateur.getEmail() : "system", safeIp);
        } catch (Exception e) {
            log.warn("Échec enregistrement audit ({} {}): {}", action, entite, e.getMessage());
        }
    }

    public void logAction(String action, String entite, Long entiteId, String details) {
        Utilisateur currentUser = null;
        try {
            if (SecurityContextHolder.getContext().getAuthentication() != null) {
                String email = SecurityContextHolder.getContext().getAuthentication().getName();
                if (email != null && !email.equals("anonymousUser")) {
                    currentUser = utilisateurRepository.findByEmail(email).orElse(null);
                }
            }
        } catch (Exception e) {
            log.warn("Erreur lors de la récupération de l'utilisateur courant pour l'audit", e);
        }
        logAction(currentUser, action, entite, entiteId, details, null);
    }

    public void logLogin(Utilisateur utilisateur, String ipAddress) {
        logAction(utilisateur, "LOGIN", "Utilisateur", utilisateur.getId(), null, ipAddress);
    }

    public void logLogout(Utilisateur utilisateur, String ipAddress) {
        logAction(utilisateur, "LOGOUT", "Utilisateur", utilisateur.getId(), null, ipAddress);
    }
}

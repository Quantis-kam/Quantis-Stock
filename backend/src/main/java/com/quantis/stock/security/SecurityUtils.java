package com.quantis.stock.security;

import com.quantis.stock.model.Entreprise;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.model.enums.Role;
import com.quantis.stock.repository.EntrepriseRepository;
import com.quantis.stock.repository.UtilisateurRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.util.Optional;

/**
 * Utilitaire centralisé de contexte de sécurité et multi-tenancy.
 * Permet d'extraire l'utilisateur courant, son entreprise et ses privilèges.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SecurityUtils {

    private final UtilisateurRepository utilisateurRepository;
    private final EntrepriseRepository entrepriseRepository;

    public Optional<Authentication> getAuthentication() {
        return Optional.ofNullable(SecurityContextHolder.getContext().getAuthentication());
    }

    public Optional<String> getCurrentUserEmail() {
        return getAuthentication()
                .filter(Authentication::isAuthenticated)
                .map(Authentication::getName);
    }

    public Optional<Utilisateur> getCurrentUser() {
        return getCurrentUserEmail()
                .flatMap(utilisateurRepository::findByEmail);
    }

    public boolean isSuperAdmin() {
        return getAuthentication()
                .map(auth -> auth.getAuthorities().stream()
                        .anyMatch(a -> a.getAuthority().equals("ROLE_SUPER_ADMIN") || a.getAuthority().equals("SUPER_ADMIN")))
                .orElse(false);
    }

    public Optional<Entreprise> getCurrentEntreprise() {
        Optional<Utilisateur> userOpt = getCurrentUser();
        if (userOpt.isPresent() && userOpt.get().getEntreprise() != null) {
            return Optional.of(userOpt.get().getEntreprise());
        }
        // Pour les super-admins sans entreprise attribuée, retourner la 1ère entreprise par défaut s'il s'agit d'une opération de consultation standard
        return entrepriseRepository.findAll().stream().findFirst();
    }

    public Long getCurrentEntrepriseId() {
        return getCurrentEntreprise().map(Entreprise::getId).orElse(null);
    }
}

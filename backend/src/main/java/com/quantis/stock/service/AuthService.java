package com.quantis.stock.service;

import com.quantis.stock.dto.*;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.Depot;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.model.enums.Role;
import com.quantis.stock.repository.DepotRepository;
import com.quantis.stock.repository.UtilisateurRepository;
import com.quantis.stock.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service d'authentification — login, register, refresh.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UtilisateurRepository utilisateurRepository;
    private final DepotRepository depotRepository;
    private final com.quantis.stock.repository.EntrepriseRepository entrepriseRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final AuditService auditService;
    private final com.quantis.stock.security.SecurityUtils securityUtils;

    /**
     * Authentification par email + mot de passe.
     */
    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request, String ipAddress) {
        Utilisateur user = utilisateurRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new BusinessException("Email ou mot de passe incorrect"));

        if (!passwordEncoder.matches(request.getMotDePasse(), user.getMotDePasseHash())) {
            throw new BusinessException("Email ou mot de passe incorrect");
        }

        if (!user.getActif()) {
            throw new BusinessException("Compte désactivé. Contactez l'administrateur.");
        }

        boolean isSuperAdmin = user.getRole() == Role.SUPER_ADMIN;

        // Contrôle de licence et d'abonnement mensuel (sauf pour le superadmin plateforme)
        if (!isSuperAdmin && user.getEntreprise() != null) {
            com.quantis.stock.model.Entreprise ent = user.getEntreprise();
            if (!ent.isLicenceValide() || "EXPIREE".equalsIgnoreCase(ent.getStatutLicence())) {
                throw new com.quantis.stock.exception.LicenceExpireeException(
                        ent.getNom(),
                        ent.getDateExpirationLicence(),
                        ent.getCodeUssdRenouvellement(),
                        ent.getMontantAbonnement()
                );
            }
            if (Boolean.FALSE.equals(ent.getEstActif())) {
                throw new BusinessException("Votre entreprise est actuellement suspendue. Veuillez contacter l'administrateur de la plateforme.");
            }
        }

        auditService.logLogin(user, ipAddress);
        return buildAuthResponse(user);
    }

    /**
     * Enregistrement d'un nouvel utilisateur (action réservée aux administrateurs).
     */
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (utilisateurRepository.existsByEmail(request.getEmail())) {
            throw new BusinessException("Un compte avec cet email existe déjà");
        }

        if (request.getRole() == Role.SUPER_ADMIN && !securityUtils.isSuperAdmin()) {
            throw new BusinessException("Seul le SuperAdmin peut créer un compte SuperAdmin");
        }

        com.quantis.stock.model.Entreprise entreprise = null;
        if (securityUtils.isSuperAdmin() && request.getEntrepriseId() != null) {
            entreprise = entrepriseRepository.findById(request.getEntrepriseId()).orElse(null);
        } else {
            entreprise = securityUtils.getCurrentEntreprise().orElse(null);
        }

        Depot depot = null;
        if (request.getDepotId() != null) {
            depot = depotRepository.findById(request.getDepotId())
                    .orElseThrow(() -> new ResourceNotFoundException("Dépôt", "id", request.getDepotId()));
            if (!securityUtils.isSuperAdmin() && entreprise != null) {
                if (depot.getEntreprise() == null || !depot.getEntreprise().getId().equals(entreprise.getId())) {
                    throw new BusinessException("Ce dépôt n'appartient pas à votre entreprise");
                }
            }
        }

        Utilisateur user = Utilisateur.builder()
                .nom(request.getNom())
                .prenom(request.getPrenom())
                .email(request.getEmail())
                .motDePasseHash(passwordEncoder.encode(request.getMotDePasse()))
                .role(request.getRole())
                .depot(depot)
                .entreprise(entreprise)
                .actif(true)
                .build();

        user = utilisateurRepository.save(user);
        log.info("Nouvel utilisateur créé: {} ({}) pour entreprise: {}", user.getEmail(), user.getRole(),
                entreprise != null ? entreprise.getNom() : "N/A");
        auditService.logAction("CREATE", "Utilisateur", user.getId(), "Création utilisateur " + user.getEmail());

        return buildAuthResponse(user);
    }

    /**
     * Rafraîchissement du token d'accès.
     */
    public AuthResponse refreshToken(RefreshTokenRequest request) {
        String refreshToken = request.getRefreshToken();

        if (!jwtTokenProvider.validateToken(refreshToken)) {
            throw new BusinessException("Refresh token invalide ou expiré");
        }

        String email = jwtTokenProvider.getEmailFromToken(refreshToken);
        Utilisateur user = utilisateurRepository.findByEmail(email)
                .orElseThrow(() -> new BusinessException("Utilisateur introuvable"));

        if (!user.getActif()) {
            throw new BusinessException("Compte désactivé");
        }

        return buildAuthResponse(user);
    }

    /**
     * Déconnexion d'un utilisateur.
     */
    @Transactional
    public void logout(String email, String ipAddress) {
        Utilisateur user = utilisateurRepository.findByEmail(email).orElse(null);
        if (user != null) {
            auditService.logLogout(user, ipAddress);
        }
    }

    /**
     * Construit la réponse d'authentification avec tokens et métadonnées d'entreprise.
     */
    private AuthResponse buildAuthResponse(Utilisateur user) {
        String accessToken = jwtTokenProvider.generateAccessToken(
                user.getId(), user.getEmail(), user.getRole().name());
        String refreshToken = jwtTokenProvider.generateRefreshToken(user.getEmail());

        java.util.List<String> permissions = user.getPermissionsEffectives().stream()
                .map(Enum::name)
                .collect(java.util.stream.Collectors.toList());

        com.quantis.stock.model.Entreprise entreprise = user.getEntreprise();
        if (entreprise == null) {
            entreprise = entrepriseRepository.findAll().stream().findFirst().orElse(null);
        }

        boolean isSuperAdmin = user.getRole() == Role.SUPER_ADMIN;

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .utilisateur(AuthResponse.UserDto.builder()
                        .id(user.getId())
                        .nom(user.getNom())
                        .prenom(user.getPrenom())
                        .email(user.getEmail())
                        .role(user.getRole().name())
                        .isSuperAdmin(isSuperAdmin)
                        .depot(user.getDepot() != null ? user.getDepot().getNom() : null)
                        .entrepriseId(entreprise != null ? entreprise.getId() : null)
                        .entrepriseNom(entreprise != null ? entreprise.getNom() : (isSuperAdmin ? "Quantis-Stock Platform" : "Quantis SARL"))
                        .entrepriseMonnaie(entreprise != null ? entreprise.getMonnaie() : "FCFA")
                        .formatFacture(entreprise != null ? entreprise.getFormatFacture() : "FAC-{YYYY}-{NNNNN}")
                        .logoUrl(entreprise != null ? entreprise.getLogoUrl() : null)
                        .permissions(permissions)
                        .dateExpirationLicence(entreprise != null && entreprise.getDateExpirationLicence() != null ? entreprise.getDateExpirationLicence().toString() : null)
                        .statutLicence(entreprise != null ? entreprise.getStatutLicence() : "ACTIVE")
                        .codeUssdRenouvellement(entreprise != null ? entreprise.getCodeUssdRenouvellement() : "*144*2*1*65189261*20200#")
                        .build())
                .build();
    }
}

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
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final AuditService auditService;

    /**
     * Authentification par email + mot de passe.
     */
    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request, String ipAddress) {
        Utilisateur user = utilisateurRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new BusinessException("Email ou mot de passe incorrect"));

        if (!user.getActif()) {
            throw new BusinessException("Compte désactivé. Contactez l'administrateur.");
        }

        if (!passwordEncoder.matches(request.getMotDePasse(), user.getMotDePasseHash())) {
            throw new BusinessException("Email ou mot de passe incorrect");
        }

        auditService.logLogin(user, ipAddress);
        return buildAuthResponse(user);
    }

    /**
     * Inscription d'un nouvel utilisateur (réservé Admin).
     */
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (utilisateurRepository.existsByEmail(request.getEmail())) {
            throw new BusinessException("Un compte avec cet email existe déjà");
        }

        Depot depot = null;
        if (request.getDepotId() != null) {
            depot = depotRepository.findById(request.getDepotId())
                    .orElseThrow(() -> new ResourceNotFoundException("Dépôt", "id", request.getDepotId()));
        }

        Utilisateur user = Utilisateur.builder()
                .nom(request.getNom())
                .prenom(request.getPrenom())
                .email(request.getEmail())
                .motDePasseHash(passwordEncoder.encode(request.getMotDePasse()))
                .role(request.getRole())
                .depot(depot)
                .actif(true)
                .build();

        user = utilisateurRepository.save(user);
        log.info("Nouvel utilisateur créé: {} ({})", user.getEmail(), user.getRole());

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
     * Construit la réponse d'authentification avec tokens.
     */
    private AuthResponse buildAuthResponse(Utilisateur user) {
        String accessToken = jwtTokenProvider.generateAccessToken(
                user.getId(), user.getEmail(), user.getRole().name());
        String refreshToken = jwtTokenProvider.generateRefreshToken(user.getEmail());

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
                        .depot(user.getDepot() != null ? user.getDepot().getNom() : null)
                        .build())
                .build();
    }
}

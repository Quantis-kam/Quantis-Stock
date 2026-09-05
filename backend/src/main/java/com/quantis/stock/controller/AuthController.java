package com.quantis.stock.controller;

import com.quantis.stock.dto.*;
import com.quantis.stock.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

/**
 * Contrôleur d'authentification.
 * Endpoints publics : /auth/login, /auth/refresh
 * Endpoint protégé : /auth/register (ADMIN uniquement)
 */
@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    /**
     * POST /auth/login — Connexion
     */
    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthResponse>> login(
            @Valid @RequestBody LoginRequest request,
            HttpServletRequest httpRequest) {
        AuthResponse response = authService.login(request, httpRequest.getRemoteAddr());
        return ResponseEntity.ok(ApiResponse.success("Connexion réussie", response));
    }

    /**
     * POST /auth/register — Création d'un utilisateur (ADMIN)
     */
    @PostMapping("/register")
    @PreAuthorize("hasAuthority('CRUD_UTILISATEURS')")
    public ResponseEntity<ApiResponse<AuthResponse>> register(
            @Valid @RequestBody RegisterRequest request) {
        AuthResponse response = authService.register(request);
        return new ResponseEntity<>(
                ApiResponse.success("Utilisateur créé avec succès", response),
                HttpStatus.CREATED);
    }

    /**
     * POST /auth/refresh — Rafraîchissement du token
     */
    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<AuthResponse>> refresh(
            @Valid @RequestBody RefreshTokenRequest request) {
        AuthResponse response = authService.refreshToken(request);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * POST /auth/logout — Déconnexion de l'utilisateur
     */
    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(
            org.springframework.security.core.Authentication auth,
            HttpServletRequest httpRequest) {
        if (auth != null) {
            authService.logout(auth.getName(), httpRequest.getRemoteAddr());
        }
        return ResponseEntity.ok(ApiResponse.success("Déconnexion réussie", null));
    }
}

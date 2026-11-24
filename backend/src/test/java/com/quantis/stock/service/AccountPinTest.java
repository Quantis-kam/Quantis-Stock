package com.quantis.stock.service;

import com.quantis.stock.dto.AuthResponse;
import com.quantis.stock.dto.LoginRequest;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.model.Entreprise;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.model.enums.Role;
import com.quantis.stock.repository.DepotRepository;
import com.quantis.stock.repository.EntrepriseRepository;
import com.quantis.stock.repository.UtilisateurRepository;
import com.quantis.stock.security.JwtTokenProvider;
import com.quantis.stock.security.SecurityUtils;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("Tests Code PIN rattaché au compte utilisateur")
class AccountPinTest {

    @Mock private UtilisateurRepository utilisateurRepository;
    @Mock private DepotRepository depotRepository;
    @Mock private EntrepriseRepository entrepriseRepository;
    @Mock private JwtTokenProvider jwtTokenProvider;
    @Mock private AuditService auditService;
    @Mock private SecurityUtils securityUtils;

    @Spy
    private PasswordEncoder passwordEncoder = new BCryptPasswordEncoder(4);

    @InjectMocks
    private AuthService authService;

    @Test
    @DisplayName("Login retourne hasPin=false avant création puis hasPin=true après enregistrement sur le compte")
    void loginAndPinLifecycleAttachedToAccount() {
        Entreprise ent = Entreprise.builder().id(1L).nom("Boutique Test").estActif(true).statutLicence("ACTIVE").build();
        Utilisateur user = Utilisateur.builder()
                .id(7L)
                .nom("Ouédraogo")
                .prenom("Salif")
                .email("salif@boutique.bf")
                .motDePasseHash(passwordEncoder.encode("Secret123!"))
                .role(Role.ADMIN)
                .entreprise(ent)
                .actif(true)
                .build();

        when(utilisateurRepository.findByEmail("salif@boutique.bf")).thenReturn(Optional.of(user));
        when(utilisateurRepository.save(any(Utilisateur.class))).thenAnswer(inv -> inv.getArgument(0));
        when(jwtTokenProvider.generateAccessToken(anyLong(), anyString(), anyString())).thenReturn("access-jwt");
        when(jwtTokenProvider.generateRefreshToken(anyString())).thenReturn("refresh-jwt");

        // 1. Avant création du PIN
        LoginRequest loginReq = new LoginRequest();
        loginReq.setEmail("salif@boutique.bf");
        loginReq.setMotDePasse("Secret123!");

        AuthResponse firstLogin = authService.login(loginReq, "127.0.0.1");
        assertThat(firstLogin.getUtilisateur().getHasPin()).isFalse();

        // 2. Définition du code PIN 2468 rattaché au compte (hashé BCrypt)
        Map<String, Object> setRes = authService.setUserPin("salif@boutique.bf", "2468");
        assertThat(setRes.get("hasPin")).isEqualTo(true);
        assertThat(user.getPinHash()).isNotBlank().doesNotContain("2468");

        // 3. Reconnexion par email + mot de passe -> hasPin est désormais true (ne redemande plus de créer le PIN)
        AuthResponse secondLogin = authService.login(loginReq, "127.0.0.1");
        assertThat(secondLogin.getUtilisateur().getHasPin()).isTrue();

        // 4. Vérification du code PIN côté serveur (bon vs mauvais)
        Map<String, Object> validCheck = authService.verifyUserPin("salif@boutique.bf", "2468");
        assertThat(validCheck.get("valid")).isEqualTo(true);
        assertThat(validCheck.get("hasPin")).isEqualTo(true);

        Map<String, Object> wrongCheck = authService.verifyUserPin("salif@boutique.bf", "0000");
        assertThat(wrongCheck.get("valid")).isEqualTo(false);
        assertThat(wrongCheck.get("hasPin")).isEqualTo(true);
    }

    @Test
    @DisplayName("setUserPin rejette tout format différent de 4 chiffres")
    void setUserPinRejectsInvalidFormat() {
        assertThatThrownBy(() -> authService.setUserPin("salif@boutique.bf", "12"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("4 chiffres");
        assertThatThrownBy(() -> authService.setUserPin("salif@boutique.bf", "abcd"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("4 chiffres");
    }
}


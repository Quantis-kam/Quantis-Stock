package com.quantis.stock.config;

import com.quantis.stock.model.UniteMesure;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.model.enums.Role;
import com.quantis.stock.repository.UniteMesureRepository;
import com.quantis.stock.repository.UtilisateurRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Initialisation minimale et idempotente pour l'environnement de production :
 * - Crée le compte SuperAdmin plateforme si aucun SUPER_ADMIN n'existe encore
 * - Crée les unités de mesure standards si la table est vide
 * Ne crée aucune donnée factice ni boutique de démonstration.
 */
@Slf4j
@Component
@Profile("prod")
@RequiredArgsConstructor
public class ProdBootstrapInitializer implements CommandLineRunner {

    private final UtilisateurRepository utilisateurRepository;
    private final UniteMesureRepository uniteMesureRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.bootstrap.super-admin-email:superadmin@quantisbf.com}")
    private String superAdminEmail;

    @Value("${app.bootstrap.super-admin-password:Admin@2026}")
    private String superAdminPassword;

    @Override
    public void run(String... args) {
        if (!utilisateurRepository.existsByEmail(superAdminEmail)) {
            Utilisateur superAdmin = Utilisateur.builder()
                    .nom("Quantis")
                    .prenom("SuperAdmin")
                    .email(superAdminEmail)
                    .motDePasseHash(passwordEncoder.encode(superAdminPassword))
                    .role(Role.SUPER_ADMIN)
                    .actif(true)
                    .build();
            utilisateurRepository.save(superAdmin);
            log.info("SuperAdmin plateforme initialisé : {}", superAdminEmail);
            if ("Admin@2026".equals(superAdminPassword)) {
                log.warn("Mot de passe SuperAdmin par défaut actif — pensez à le changer dès votre première connexion !");
            }
        }

        if (uniteMesureRepository.count() == 0) {
            List<UniteMesure> defaults = List.of(
                    UniteMesure.builder().nom("Pièce").abreviation("pce").build(),
                    UniteMesure.builder().nom("Carton").abreviation("ctn").build(),
                    UniteMesure.builder().nom("Kilogramme").abreviation("kg").build(),
                    UniteMesure.builder().nom("Litre").abreviation("L").build(),
                    UniteMesure.builder().nom("Sac").abreviation("sac").build(),
                    UniteMesure.builder().nom("Boîte").abreviation("bte").build(),
                    UniteMesure.builder().nom("Paquet").abreviation("pqt").build(),
                    UniteMesure.builder().nom("Bidon").abreviation("bdn").build(),
                    UniteMesure.builder().nom("Mètre").abreviation("m").build(),
                    UniteMesure.builder().nom("Douzaine").abreviation("dz").build()
            );
            uniteMesureRepository.saveAll(defaults);
            log.info("{} unités de mesure standards créées.", defaults.size());
        }
    }
}


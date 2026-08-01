package com.quantis.stock.config;

import com.quantis.stock.model.Depot;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.model.enums.Role;
import com.quantis.stock.repository.DepotRepository;
import com.quantis.stock.repository.UtilisateurRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * Initialise les données de base au démarrage (profil dev uniquement).
 * - Dépôt principal
 * - Utilisateur Admin par défaut
 */
@Slf4j
@Component
@Profile("dev")
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {

    private final UtilisateurRepository utilisateurRepository;
    private final DepotRepository depotRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
        // Créer le dépôt principal si absent
        if (depotRepository.count() == 0) {
            Depot depotPrincipal = Depot.builder()
                    .nom("Dépôt Principal")
                    .adresse("Ouagadougou, Burkina Faso")
                    .telephone("+226 70 00 00 00")
                    .estActif(true)
                    .build();
            depotPrincipal = depotRepository.save(depotPrincipal);
            log.info("✅ Dépôt principal créé: {}", depotPrincipal.getNom());

            // Créer l'admin par défaut
            if (!utilisateurRepository.existsByEmail("admin@quantis.tech")) {
                Utilisateur admin = Utilisateur.builder()
                        .nom("Administrateur")
                        .prenom("Quantis")
                        .email("admin@quantis.tech")
                        .motDePasseHash(passwordEncoder.encode("Admin@2026"))
                        .role(Role.ADMIN)
                        .depot(depotPrincipal)
                        .actif(true)
                        .build();
                utilisateurRepository.save(admin);
                log.info("✅ Admin par défaut créé: admin@quantis.tech / Admin@2026");
            }
        }
    }
}

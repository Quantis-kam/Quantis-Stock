package com.quantis.stock.config;

import com.quantis.stock.model.*;
import com.quantis.stock.model.enums.Role;
import com.quantis.stock.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Initialise les données de base au démarrage (profil dev uniquement).
 * - Dépôt principal
 * - Utilisateur Admin par défaut
 * - Unités de mesure par défaut
 * - Catégories par défaut
 */
@Slf4j
@Component
@Profile("dev")
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {

    private final UtilisateurRepository utilisateurRepository;
    private final DepotRepository depotRepository;
    private final EntrepriseRepository entrepriseRepository;
    private final PasswordEncoder passwordEncoder;
    private final UniteMesureRepository uniteMesureRepository;
    private final CategorieRepository categorieRepository;
    private final ProduitRepository produitRepository;
    private final ClientRepository clientRepository;
    private final DocumentRepository documentRepository;
    private final CommandeFournisseurRepository commandeFournisseurRepository;
    private final FournisseurRepository fournisseurRepository;
    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) {
        // Migration de colonnes enum vers VARCHAR pour compatibilité dynamique
        try {
            jdbcTemplate.execute("ALTER TABLE utilisateur ALTER COLUMN role VARCHAR(50)");
            jdbcTemplate.execute("ALTER TABLE document ALTER COLUMN type VARCHAR(30)");
            jdbcTemplate.execute("ALTER TABLE document ALTER COLUMN statut VARCHAR(30)");
        } catch (Exception e) {
            log.debug("Notice migration schéma: {}", e.getMessage());
        }

        // Créer l'entreprise par défaut si absente
        Entreprise defaultEntreprise = null;
        if (entrepriseRepository.count() == 0) {
            defaultEntreprise = Entreprise.builder()
                    .nom("Quantis SARL")
                    .nif("BF000123456A")
                    .rccm("BF-OUA-2026-B-1234")
                    .telephone("+226 25 30 00 00")
                    .email("contact@quantis.tech")
                    .adresse("Avenue Kwame N'Krumah, Ouagadougou")
                    .monnaie("FCFA")
                    .formatFacture("FAC-{YYYY}-{NNNNN}")
                    .estActif(true)
                    .build();
            defaultEntreprise = entrepriseRepository.save(defaultEntreprise);
            log.info("✅ Entreprise par défaut créée: Quantis SARL");
        } else {
            defaultEntreprise = entrepriseRepository.findAll().get(0);
        }

        // 1. Créer le Super Admin de la plateforme si absent
        if (!utilisateurRepository.existsByEmail("superadmin@quantis.tech")) {
            Utilisateur superAdmin = Utilisateur.builder()
                    .nom("Plateforme")
                    .prenom("SuperAdmin")
                    .email("superadmin@quantis.tech")
                    .motDePasseHash(passwordEncoder.encode("Admin@2026"))
                    .role(Role.SUPER_ADMIN)
                    .actif(true)
                    .build();
            utilisateurRepository.save(superAdmin);
            log.info("👑 Super Admin Plateforme créé: superadmin@quantis.tech / Admin@2026");
        }

        // 2. Créer le dépôt principal si absent
        if (depotRepository.count() == 0) {
            Depot depotPrincipal = Depot.builder()
                    .nom("Dépôt Principal")
                    .adresse("Ouagadougou, Burkina Faso")
                    .telephone("+226 70 00 00 00")
                    .entreprise(defaultEntreprise)
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
                        .entreprise(defaultEntreprise)
                        .actif(true)
                        .build();
                utilisateurRepository.save(admin);
                log.info("✅ Admin par défaut créé: admin@quantis.tech / Admin@2026");
            }
        }

        // 3. Créer les unités de mesure par défaut si absent
        if (uniteMesureRepository.count() == 0) {
            uniteMesureRepository.save(UniteMesure.builder().nom("Kilogramme").abreviation("kg").build());
            uniteMesureRepository.save(UniteMesure.builder().nom("Litre").abreviation("L").build());
            uniteMesureRepository.save(UniteMesure.builder().nom("Pièce").abreviation("pcs").build());
            uniteMesureRepository.save(UniteMesure.builder().nom("Sac").abreviation("sac").build());
            uniteMesureRepository.save(UniteMesure.builder().nom("Carton").abreviation("ctn").build());
            log.info("✅ Unités de mesure initiales créées");
        }

        // 4. Créer les catégories par défaut si absent
        if (categorieRepository.count() == 0) {
            Categorie alimentation = Categorie.builder().nom("Alimentation").description("Produits alimentaires").entreprise(defaultEntreprise).build();
            categorieRepository.save(alimentation);

            Categorie boissons = Categorie.builder().nom("Boissons").description("Boissons et liquides").entreprise(defaultEntreprise).build();
            categorieRepository.save(boissons);

            Categorie divers = Categorie.builder().nom("Divers").description("Articles divers").entreprise(defaultEntreprise).build();
            categorieRepository.save(divers);

            log.info("✅ Catégories initiales créées");
        }

        // 5. Backfill multi-tenant vers defaultEntreprise pour les entités orphelines
        Long defaultEntId = defaultEntreprise.getId();
        try {
            jdbcTemplate.update("UPDATE produit SET entreprise_id = ? WHERE entreprise_id IS NULL", defaultEntId);
            jdbcTemplate.update("UPDATE client SET entreprise_id = ? WHERE entreprise_id IS NULL", defaultEntId);
            jdbcTemplate.update("UPDATE fournisseur SET entreprise_id = ? WHERE entreprise_id IS NULL", defaultEntId);
            jdbcTemplate.update("UPDATE document SET entreprise_id = ? WHERE entreprise_id IS NULL", defaultEntId);
            jdbcTemplate.update("UPDATE categorie SET entreprise_id = ? WHERE entreprise_id IS NULL", defaultEntId);
            jdbcTemplate.update("UPDATE cloture_comptable SET entreprise_id = ? WHERE entreprise_id IS NULL", defaultEntId);
            jdbcTemplate.update("UPDATE session_caisse SET entreprise_id = ? WHERE entreprise_id IS NULL", defaultEntId);
            jdbcTemplate.update("UPDATE mouvement_caisse SET entreprise_id = ? WHERE entreprise_id IS NULL", defaultEntId);
            jdbcTemplate.update("UPDATE utilisateur SET entreprise_id = ? WHERE entreprise_id IS NULL AND role != 'SUPER_ADMIN'", defaultEntId);
        } catch (Exception e) {
            log.debug("Backfill entreprise notice: {}", e.getMessage());
        }

        // 6. Création d'une 2ème entreprise de test (Faso Distribution) pour valider le multi-tenant
        Entreprise fasoDist = entrepriseRepository.findAll().stream()
                .filter(e -> e.getNom().contains("Faso Distribution"))
                .findFirst()
                .orElseGet(() -> {
                    Entreprise e = Entreprise.builder()
                            .nom("Faso Distribution & Quincaillerie SARL")
                            .nif("BF000987654Z")
                            .rccm("BF-OUA-2026-B-9988")
                            .telephone("+226 25 40 10 20")
                            .email("contact@faso-distribution.bf")
                            .adresse("Boulevard des Tensoba, Ouagadougou")
                            .monnaie("FCFA")
                            .formatFacture("FD-{YYYY}-{NNNNN}")
                            .estActif(true)
                            .build();
                    return entrepriseRepository.save(e);
                });

        Depot depotFaso = depotRepository.findAll().stream()
                .filter(d -> d.getEntreprise() != null && d.getEntreprise().getId().equals(fasoDist.getId()))
                .findFirst()
                .orElseGet(() -> {
                    Depot d = Depot.builder()
                            .nom("Entrepôt Quincaillerie & Ciment")
                            .adresse("Boulevard des Tensoba")
                            .telephone("+226 25 40 10 21")
                            .entreprise(fasoDist)
                            .estActif(true)
                            .build();
                    return depotRepository.save(d);
                });

        if (!utilisateurRepository.existsByEmail("admin@faso-distribution.bf")) {
            Utilisateur adminFaso = Utilisateur.builder()
                    .nom("Kaboré")
                    .prenom("Moussa")
                    .email("admin@faso-distribution.bf")
                    .motDePasseHash(passwordEncoder.encode("Admin@2026"))
                    .role(Role.ADMIN)
                    .depot(depotFaso)
                    .entreprise(fasoDist)
                    .actif(true)
                    .build();
            utilisateurRepository.save(adminFaso);
            log.info("🏢 Admin Faso Distribution créé: admin@faso-distribution.bf / Admin@2026");
        }

        // Produits spécifiques à Faso Distribution
        if (produitRepository.countByEntrepriseId(fasoDist.getId()) == 0) {
            UniteMesure sac = uniteMesureRepository.findByNomIgnoreCase("Sac").orElse(null);
            UniteMesure pcs = uniteMesureRepository.findByNomIgnoreCase("Pièce").orElse(null);

            Produit p1 = Produit.builder()
                    .entreprise(fasoDist)
                    .sku("CIM-DAN-50")
                    .codeBarres("618110001001")
                    .nom("Ciment Dangote 42.5R (Sac 50kg)")
                    .description("Ciment haute résistance pour gros œuvre")
                    .prixAchat(new java.math.BigDecimal("4200.00"))
                    .prixVente(new java.math.BigDecimal("4900.00"))
                    .tauxTva(new java.math.BigDecimal("18.00"))
                    .seuilAlerte(50)
                    .unite(sac)
                    .actif(true)
                    .build();
            produitRepository.save(p1);

            Produit p2 = Produit.builder()
                    .entreprise(fasoDist)
                    .sku("FER-BET-12")
                    .codeBarres("618110001002")
                    .nom("Fer à béton Haute Adhérence 12mm")
                    .description("Barre de fer 12m pour armatures béton armé")
                    .prixAchat(new java.math.BigDecimal("5500.00"))
                    .prixVente(new java.math.BigDecimal("6800.00"))
                    .tauxTva(new java.math.BigDecimal("18.00"))
                    .seuilAlerte(30)
                    .unite(pcs)
                    .actif(true)
                    .build();
            produitRepository.save(p2);

            Produit p3 = Produit.builder()
                    .entreprise(fasoDist)
                    .sku("BROU-PRO-01")
                    .codeBarres("618110001003")
                    .nom("Brouette Renforcée Chantier 90L")
                    .description("Brouette professionnelle cuve emboutie roue pleine")
                    .prixAchat(new java.math.BigDecimal("22000.00"))
                    .prixVente(new java.math.BigDecimal("28500.00"))
                    .tauxTva(new java.math.BigDecimal("18.00"))
                    .seuilAlerte(10)
                    .unite(pcs)
                    .actif(true)
                    .build();
            produitRepository.save(p3);

            log.info("🧱 Produits de Faso Distribution créés");
        }

        // Client spécifique à Faso Distribution
        Client cFaso = clientRepository.findAll().stream()
                .filter(c -> c.getEntreprise() != null && c.getEntreprise().getId().equals(fasoDist.getId()))
                .findFirst()
                .orElseGet(() -> {
                    Client c = Client.builder()
                            .entreprise(fasoDist)
                            .nom("Soma BTP & Construction SARL")
                            .telephone("+226 70 88 99 00")
                            .email("achats@somabtp.bf")
                            .adresse("Zone Sonatur Ouaga 2000")
                            .soldeCredit(java.math.BigDecimal.ZERO)
                            .actif(true)
                            .build();
                    return clientRepository.save(c);
                });

        // Factures de vente pour Faso Distribution
        if (documentRepository.countByEntrepriseId(fasoDist.getId()) == 0) {
            Utilisateur adminFaso = utilisateurRepository.findByEmail("admin@faso-distribution.bf").orElse(null);
            if (adminFaso != null && cFaso != null) {
                Document doc1 = Document.builder()
                        .type(com.quantis.stock.model.enums.TypeDocument.FACTURE)
                        .numero("FD-2026-00001")
                        .client(cFaso)
                        .depot(depotFaso)
                        .entreprise(fasoDist)
                        .statut(com.quantis.stock.model.enums.StatutDocument.VALIDE)
                        .totalHt(new java.math.BigDecimal("3250000.00"))
                        .totalTva(new java.math.BigDecimal("585000.00"))
                        .totalTtc(new java.math.BigDecimal("3835000.00"))
                        .dateDocument(java.time.LocalDate.now().minusDays(3))
                        .utilisateur(adminFaso)
                        .build();
                documentRepository.save(doc1);

                Document doc2 = Document.builder()
                        .type(com.quantis.stock.model.enums.TypeDocument.FACTURE)
                        .numero("FD-2026-00002")
                        .client(cFaso)
                        .depot(depotFaso)
                        .entreprise(fasoDist)
                        .statut(com.quantis.stock.model.enums.StatutDocument.VALIDE)
                        .totalHt(new java.math.BigDecimal("1700000.00"))
                        .totalTva(new java.math.BigDecimal("306000.00"))
                        .totalTtc(new java.math.BigDecimal("2006000.00"))
                        .dateDocument(java.time.LocalDate.now().minusDays(1))
                        .utilisateur(adminFaso)
                        .build();
                documentRepository.save(doc2);

                log.info("📄 Factures créées pour Faso Distribution (CA Total: 5 841 000 FCFA)");
            }
        }

        // Achats Fournisseur pour Faso Distribution
        if (commandeFournisseurRepository.countAchatsByEntrepriseId(fasoDist.getId()) == 0) {
            Fournisseur fourFaso = Fournisseur.builder()
                    .entreprise(fasoDist)
                    .nom("CIMAF Burkina Industrie")
                    .telephone("+226 25 38 40 50")
                    .email("commandes@cimaf.bf")
                    .adresse("Zone Industrielle de Kossodo")
                    .actif(true)
                    .build();
            fourFaso = fournisseurRepository.save(fourFaso);

            Utilisateur adminFaso = utilisateurRepository.findByEmail("admin@faso-distribution.bf").orElse(null);
            if (adminFaso != null) {
                CommandeFournisseur cmdFaso = CommandeFournisseur.builder()
                        .numero("CMD-FD-2026-001")
                        .fournisseur(fourFaso)
                        .depot(depotFaso)
                        .statut(com.quantis.stock.model.enums.StatutCommande.RECUE)
                        .totalHt(new java.math.BigDecimal("2950000.00"))
                        .dateCommande(java.time.LocalDate.now().minusDays(7))
                        .utilisateur(adminFaso)
                        .build();
                commandeFournisseurRepository.save(cmdFaso);
                log.info("📦 Commande fournisseur créée pour Faso Distribution (2 950 000 FCFA)");
            }
        }

        // Seeder TechCorp Logistics si présent
        entrepriseRepository.findAll().stream()
                .filter(e -> e.getNom().contains("TechCorp"))
                .findFirst()
                .ifPresent(techCorp -> {
                    if (documentRepository.countByEntrepriseId(techCorp.getId()) == 0) {
                        Utilisateur adminTech = utilisateurRepository.findByEmail("admin@techcorp.bf").orElse(null);
                        Depot depotTech = depotRepository.findAll().stream()
                                .filter(d -> d.getEntreprise() != null && d.getEntreprise().getId().equals(techCorp.getId()))
                                .findFirst().orElse(null);
                        if (adminTech != null && depotTech != null) {
                            Client cTech = Client.builder()
                                    .entreprise(techCorp)
                                    .nom("Global Logistics Client")
                                    .telephone("+226 71 00 11 22")
                                    .email("contact@globallog.bf")
                                    .soldeCredit(java.math.BigDecimal.ZERO)
                                    .actif(true)
                                    .build();
                            cTech = clientRepository.save(cTech);

                            Document docTech = Document.builder()
                                    .type(com.quantis.stock.model.enums.TypeDocument.FACTURE)
                                    .numero("TC-2026-00001")
                                    .client(cTech)
                                    .depot(depotTech)
                                    .entreprise(techCorp)
                                    .statut(com.quantis.stock.model.enums.StatutDocument.VALIDE)
                                    .totalHt(new java.math.BigDecimal("1200000.00"))
                                    .totalTva(new java.math.BigDecimal("216000.00"))
                                    .totalTtc(new java.math.BigDecimal("1416000.00"))
                                    .dateDocument(java.time.LocalDate.now().minusDays(2))
                                    .utilisateur(adminTech)
                                    .build();
                            documentRepository.save(docTech);

                            Fournisseur fTech = Fournisseur.builder()
                                    .entreprise(techCorp)
                                    .nom("Atlas Transport & Transit")
                                    .telephone("+226 25 31 12 34")
                                    .email("atlas@transport.bf")
                                    .actif(true)
                                    .build();
                            fTech = fournisseurRepository.save(fTech);

                            CommandeFournisseur cmdTech = CommandeFournisseur.builder()
                                    .numero("CMD-TC-2026-001")
                                    .fournisseur(fTech)
                                    .depot(depotTech)
                                    .statut(com.quantis.stock.model.enums.StatutCommande.RECUE)
                                    .totalHt(new java.math.BigDecimal("680000.00"))
                                    .dateCommande(java.time.LocalDate.now().minusDays(5))
                                    .utilisateur(adminTech)
                                    .build();
                            commandeFournisseurRepository.save(cmdTech);
                        }
                    }
                });

        // Initialisation / mise à jour des licences & abonnements mensuels
        defaultEntreprise.setDateExpirationLicence(java.time.LocalDate.now().plusMonths(2));
        defaultEntreprise.setStatutLicence("ACTIVE");
        defaultEntreprise.setMontantAbonnement(20200.0);
        defaultEntreprise.setCodeUssdRenouvellement("*144*2*1*65189261*20200#");
        entrepriseRepository.save(defaultEntreprise);

        if (fasoDist != null) {
            fasoDist.setDateExpirationLicence(java.time.LocalDate.now().plusDays(25));
            fasoDist.setStatutLicence("ACTIVE");
            fasoDist.setMontantAbonnement(20200.0);
            fasoDist.setCodeUssdRenouvellement("*144*2*1*65189261*20200#");
            entrepriseRepository.save(fasoDist);
        }

        entrepriseRepository.findAll().stream()
                .filter(e -> e.getNom().contains("TechCorp"))
                .findFirst()
                .ifPresent(tc -> {
                    // Configuré avec licence expirée pour validation du modal de réabonnement
                    tc.setDateExpirationLicence(java.time.LocalDate.now().minusDays(5));
                    tc.setStatutLicence("EXPIREE");
                    tc.setMontantAbonnement(20200.0);
                    tc.setCodeUssdRenouvellement("*144*2*1*65189261*20200#");
                    entrepriseRepository.save(tc);
                    log.info("🔑 Licence TechCorp configurée: EXPIREE (Test réabonnement Orange Money *144*2*1*65189261*20200#)");
                });
    }
}

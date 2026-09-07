package com.quantis.stock.service;

import com.quantis.stock.model.*;
import com.quantis.stock.model.enums.*;
import com.quantis.stock.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class DataSeederService {

    private final EntrepriseRepository entrepriseRepository;
    private final DepotRepository depotRepository;
    private final CategorieRepository categorieRepository;
    private final UniteMesureRepository uniteMesureRepository;
    private final ProduitRepository produitRepository;
    private final StockCourantRepository stockCourantRepository;
    private final ClientRepository clientRepository;
    private final FournisseurRepository fournisseurRepository;
    private final SessionCaisseRepository sessionCaisseRepository;
    private final MouvementCaisseRepository mouvementCaisseRepository;
    private final ClotureComptableRepository clotureRepository;
    private final UtilisateurRepository utilisateurRepository;

    @Transactional
    public Map<String, Object> seedRealisticData() {
        log.info("Démarrage de l'injection des données réelles du terrain...");

        // 1. Profil Entreprise
        Entreprise ent = entrepriseRepository.findAll().stream().findFirst().orElseGet(() -> {
            Entreprise e = new Entreprise();
            e.setNom("Quantis Supermarché & Négoce");
            return e;
        });
        ent.setNom("Quantis Supermarché & Négoce SARL");
        ent.setNif("0014589230K");
        ent.setRccm("BF-OUA-2024-B-12845");
        ent.setTelephone("+226 25 30 40 50");
        ent.setEmail("contact@quantis.tech");
        ent.setAdresse("Avenue Kwame Nkrumah, 01 BP 456 Ouagadougou");
        ent.setMonnaie("FCFA");
        final Entreprise defaultEntreprise = entrepriseRepository.save(ent);

        // Utilisateur Admin
        Utilisateur admin = utilisateurRepository.findByEmail("admin@quantis.tech").orElse(null);

        // 2. Dépôts
        Depot depotCentralTemp = depotRepository.findAll().stream()
                .filter(d -> d.getNom().contains("Central") || d.getNom().contains("Principal"))
                .findFirst()
                .orElseGet(() -> {
                    Depot d = new Depot();
                    d.setNom("Dépôt Central (Zone Industrielle)");
                    d.setAdresse("Zone Industrielle Gounghin");
                    d.setTelephone("+226 25 34 12 00");
                    d.setEntreprise(defaultEntreprise);
                    d.setEstActif(true);
                    return depotRepository.save(d);
                });
        if (depotCentralTemp.getEntreprise() == null) {
            depotCentralTemp.setEntreprise(defaultEntreprise);
            depotCentralTemp = depotRepository.save(depotCentralTemp);
        }
        final Depot depotCentral = depotCentralTemp;

        Depot boutiqueTemp = depotRepository.findAll().stream()
                .filter(d -> d.getNom().contains("Boutique") || d.getNom().contains("Comptoir"))
                .findFirst()
                .orElseGet(() -> {
                    Depot d = new Depot();
                    d.setNom("Boutique & Comptoir Vente");
                    d.setAdresse("Avenue Kwame Nkrumah");
                    d.setTelephone("+226 25 30 40 51");
                    d.setEntreprise(defaultEntreprise);
                    d.setEstActif(true);
                    return depotRepository.save(d);
                });
        if (boutiqueTemp.getEntreprise() == null) {
            boutiqueTemp.setEntreprise(defaultEntreprise);
            boutiqueTemp = depotRepository.save(boutiqueTemp);
        }
        final Depot boutique = boutiqueTemp;

        // 3. Unités de mesure
        Map<String, UniteMesure> unites = new HashMap<>();
        for (String uNom : List.of("Unité", "Sac", "Carton", "Pack", "Bouteille", "Paquet")) {
            UniteMesure u = uniteMesureRepository.findByNomIgnoreCase(uNom)
                    .or(() -> uniteMesureRepository.findByAbreviationIgnoreCase(uNom.substring(0, Math.min(3, uNom.length())).toUpperCase()))
                    .orElseGet(() -> uniteMesureRepository.save(new UniteMesure(null, uNom.substring(0, Math.min(3, uNom.length())).toUpperCase(), uNom)));
            unites.put(uNom, u);
        }

        // 4. Catégories
        Map<String, Categorie> categories = new HashMap<>();
        for (String cNom : List.of("Alimentation Générale", "Boissons & Fraîcheur", "Hygiène & Entretien", "Épicerie & Café")) {
            Categorie c = categorieRepository.findByNom(cNom)
                    .orElseGet(() -> {
                        Categorie cat = new Categorie();
                        cat.setNom(cNom);
                        cat.setDescription("Catégorie " + cNom);
                        return categorieRepository.save(cat);
                    });
            categories.put(cNom, c);
        }

        // 5. Produits réels (10 articles de forte rotation)
        List<Object[]> produitsDefs = List.of(
                new Object[]{"RIZ-25K-01", "Riz Parfumé Royal 25kg", "Alimentation Générale", "Sac", "14000", "16500", 5, 45},
                new Object[]{"HUILE-5L-02", "Huile Végétale Dinor 5L", "Alimentation Générale", "Bouteille", "6500", "7800", 10, 60},
                new Object[]{"SUCRE-1K-03", "Sucre en morceaux SOSUCO 1kg", "Alimentation Générale", "Paquet", "850", "1000", 20, 110},
                new Object[]{"LAIT-BR-04", "Lait concentré Bonnet Rouge 400g", "Alimentation Générale", "Unité", "1200", "1450", 15, 80},
                new Object[]{"PATE-MAM-05", "Pâtes Alimentaires Maman 500g", "Alimentation Générale", "Paquet", "350", "450", 30, 140},
                new Object[]{"EAU-LAF-06", "Eau Minérale Lafi 1.5L (Pack x6)", "Boissons & Fraîcheur", "Pack", "2100", "2500", 10, 70},
                new Object[]{"COCA-33-07", "Coca-Cola Canette 33cl (Pack x24)", "Boissons & Fraîcheur", "Carton", "10500", "12500", 8, 35},
                new Object[]{"SAVON-DIA-08", "Savon de ménage Diama 400g", "Hygiène & Entretien", "Carton", "8000", "9500", 5, 50},
                new Object[]{"OMO-1KG-09", "Lessive en Poudre Omo 1kg", "Hygiène & Entretien", "Paquet", "1500", "1900", 10, 40},
                new Object[]{"NESCAFE-10", "Café Nescafé Classic 200g", "Épicerie & Café", "Unité", "2800", "3400", 8, 30}
        );

        List<Produit> savedProduits = new ArrayList<>();
        for (Object[] def : produitsDefs) {
            String sku = (String) def[0];
            String nom = (String) def[1];
            String catNom = (String) def[2];
            String unitNom = (String) def[3];
            BigDecimal pAchat = new BigDecimal((String) def[4]);
            BigDecimal pVente = new BigDecimal((String) def[5]);
            int seuil = (int) def[6];
            int stockQte = (int) def[7];

            Produit p = produitRepository.findBySku(sku).orElseGet(() -> new Produit());
            p.setSku(sku);
            p.setNom(nom);
            p.setCategorie(categories.get(catNom));
            p.setUnite(unites.get(unitNom));
            p.setPrixAchat(pAchat);
            p.setPrixVente(pVente);
            p.setSeuilAlerte(seuil);
            p.setTauxTva(new BigDecimal("18.00"));
            p.setActif(true);
            p = produitRepository.save(p);
            savedProduits.add(p);

            // Stock courant dans la boutique
            final Produit pRef = p;
            StockCourant sc = stockCourantRepository.findByProduitIdAndVarianteIsNullAndDepotId(p.getId(), boutique.getId())
                    .orElseGet(() -> StockCourant.builder()
                            .produit(pRef)
                            .depot(boutique)
                            .quantite(BigDecimal.ZERO)
                            .build());
            sc.setQuantite(BigDecimal.valueOf(stockQte));
            stockCourantRepository.save(sc);
        }

        // 6. Clients réels avec crédits
        Client c1 = clientRepository.findAll().stream().filter(c -> c.getNom().contains("Ouedraogo")).findFirst().orElseGet(() -> new Client());
        c1.setNom("ETS Ouedraogo & Frères");
        c1.setTelephone("+226 70 20 30 40");
        c1.setEmail("ouedraogo.freres@gmail.com");
        c1.setAdresse("Grand Marché Rood-Woko, Ouaga");
        c1.setSoldeCredit(new BigDecimal("75000.00"));
        c1.setActif(true);
        c1 = clientRepository.save(c1);

        Client c2 = clientRepository.findAll().stream().filter(c -> c.getNom().contains("Délice")).findFirst().orElseGet(() -> new Client());
        c2.setNom("Restaurant Le Délice Gourmand");
        c2.setTelephone("+226 76 11 22 33");
        c2.setEmail("contact@delice-gourmand.bf");
        c2.setAdresse("Avenue Babanguida, Ouaga");
        c2.setSoldeCredit(new BigDecimal("125000.00"));
        c2.setActif(true);
        c2 = clientRepository.save(c2);

        Client c3 = clientRepository.findAll().stream().filter(c -> c.getNom().contains("Comptoir")).findFirst().orElseGet(() -> new Client());
        c3.setNom("Client Divers / Comptoir");
        c3.setTelephone("+226 70 00 00 00");
        c3.setAdresse("Ouagadougou");
        c3.setSoldeCredit(BigDecimal.ZERO);
        c3.setActif(true);
        c3 = clientRepository.save(c3);

        // 7. Fournisseurs réels avec dettes
        Fournisseur f1 = fournisseurRepository.findAll().stream().filter(f -> f.getNom().contains("CITEC")).findFirst().orElseGet(() -> new Fournisseur());
        f1.setNom("SN CITEC Burkina");
        f1.setTelephone("+226 20 97 00 00");
        f1.setEmail("commandes@sn-citec.com");
        f1.setAdresse("Bobo-Dioulasso, Zone Industrielle");
        f1.setSoldeDette(new BigDecimal("350000.00"));
        f1.setActif(true);
        f1 = fournisseurRepository.save(f1);

        Fournisseur f2 = fournisseurRepository.findAll().stream().filter(f -> f.getNom().contains("SODIBO")).findFirst().orElseGet(() -> new Fournisseur());
        f2.setNom("SODIBO / Brakina");
        f2.setTelephone("+226 25 37 40 00");
        f2.setEmail("distribution@brakina-bf.com");
        f2.setAdresse("Zone Industrielle Kossodo, Ouaga");
        f2.setSoldeDette(new BigDecimal("180000.00"));
        f2.setActif(true);
        f2 = fournisseurRepository.save(f2);

        // 8. Session de caisse active avec mouvements
        if (admin != null) {
            final Utilisateur adminRef = admin;
            SessionCaisse session = sessionCaisseRepository.findByCaissierIdAndStatut(admin.getId(), StatutSessionCaisse.OUVERTE)
                    .orElseGet(() -> {
                        SessionCaisse s = SessionCaisse.builder()
                                .caissier(adminRef)
                                .depot(boutique)
                                .fondCaisseOuverture(new BigDecimal("50000.00"))
                                .totalEntrees(BigDecimal.ZERO)
                                .totalSorties(BigDecimal.ZERO)
                                .soldeTheorique(new BigDecimal("50000.00"))
                                .statut(StatutSessionCaisse.OUVERTE)
                                .dateOuverture(Instant.now())
                                .build();
                        return sessionCaisseRepository.save(s);
                    });

            // Mouvements de caisse récents
            if (mouvementCaisseRepository.count() < 4) {
                MouvementCaisse mc1 = MouvementCaisse.builder()
                        .sessionCaisse(session)
                        .utilisateur(admin)
                        .type(TypeCaisse.ENTREE)
                        .montant(new BigDecimal("75000.00"))
                        .categorie("Ventes Comptoir")
                        .libelle("Encaissement matinée POS")
                        .dateMouvement(LocalDate.now())
                        .build();
                mouvementCaisseRepository.save(mc1);

                MouvementCaisse mc2 = MouvementCaisse.builder()
                        .sessionCaisse(session)
                        .utilisateur(admin)
                        .type(TypeCaisse.SORTIE)
                        .montant(new BigDecimal("12000.00"))
                        .categorie("Transport & Logistique")
                        .libelle("Frais déchargement camion livraison")
                        .dateMouvement(LocalDate.now())
                        .build();
                mouvementCaisseRepository.save(mc2);

                MouvementCaisse mc3 = MouvementCaisse.builder()
                        .sessionCaisse(session)
                        .utilisateur(admin)
                        .type(TypeCaisse.ENTREE)
                        .montant(new BigDecimal("45000.00"))
                        .categorie("Règlement Client")
                        .libelle("Acompte reçu sur facture ETS Ouedraogo")
                        .dateMouvement(LocalDate.now())
                        .build();
                mouvementCaisseRepository.save(mc3);

                session.setTotalEntrees(session.getTotalEntrees().add(new BigDecimal("120000.00")));
                session.setTotalSorties(session.getTotalSorties().add(new BigDecimal("12000.00")));
                session.recalculerSoldeTheorique();
                sessionCaisseRepository.save(session);
            }
        }

        // 9. Clôture comptable passée (Août 2026)
        if (!clotureRepository.existsByPeriode("2026-08")) {
            ClotureComptable clotureAout = ClotureComptable.builder()
                    .periode("2026-08")
                    .libelle("Arrêté Mensuel — Août 2026")
                    .dateDebut(LocalDate.of(2026, 8, 1))
                    .dateFin(LocalDate.of(2026, 8, 31))
                    .dateCloture(Instant.now().minusSeconds(86400 * 2))
                    .cloturePar(admin)
                    .chiffreAffairesTtc(new BigDecimal("4850000.00"))
                    .chiffreAffairesHt(new BigDecimal("4110169.00"))
                    .totalTvaCollectee(new BigDecimal("739831.00"))
                    .totalAchatsHt(new BigDecimal("3250000.00"))
                    .totalDepensesCaisse(new BigDecimal("215000.00"))
                    .totalEntreesCaisse(new BigDecimal("4720000.00"))
                    .margeBruteEstimee(new BigDecimal("860169.00"))
                    .valeurStockFinPeriode(new BigDecimal("3890000.00"))
                    .totalCreancesClients(new BigDecimal("200000.00"))
                    .totalDettesFournisseurs(new BigDecimal("530000.00"))
                    .soldeCaisseFinal(new BigDecimal("4505000.00"))
                    .statut("VERROUILLE")
                    .notes("Clôture d'Août 2026 vérifiée et validée sans anomalie de caisse. Inventaire physique conforme.")
                    .build();
            clotureRepository.save(clotureAout);
        }

        log.info("Données réelles injectées avec succès !");

        return Map.of(
                "success", true,
                "produits", savedProduits.size(),
                "clients", clientRepository.count(),
                "fournisseurs", fournisseurRepository.count(),
                "clotures", clotureRepository.count()
        );
    }
}

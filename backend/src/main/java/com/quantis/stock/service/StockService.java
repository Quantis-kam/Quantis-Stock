package com.quantis.stock.service;

import com.quantis.stock.dto.MouvementRequest;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.*;
import com.quantis.stock.model.enums.TypeMouvement;
import com.quantis.stock.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Collections;
import java.util.List;
import com.quantis.stock.security.SecurityUtils;

/**
 * Service de gestion de stock — mouvements et mise à jour du stock courant.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StockService {

    private final StockCourantRepository stockCourantRepository;
    private final MouvementStockRepository mouvementStockRepository;
    private final ProduitRepository produitRepository;
    private final VarianteProduitRepository varianteProduitRepository;
    private final DepotRepository depotRepository;
    private final UtilisateurRepository utilisateurRepository;
    private final AuditService auditService;
    private final SecurityUtils securityUtils;

    // =================== MOUVEMENTS ===================

    /**
     * Enregistre un mouvement de stock et met à jour le stock courant.
     */
    @Transactional
    public MouvementStock enregistrerMouvement(MouvementRequest request, String userEmail) {
        // Idempotence : vérifier si le UUID existe déjà
        if (request.getUuidSync() != null && mouvementStockRepository.existsByUuidSync(request.getUuidSync())) {
            log.info("Mouvement déjà traité (UUID: {}), ignoré", request.getUuidSync());
            return mouvementStockRepository.findByUuidSync(request.getUuidSync()).orElseThrow();
        }

        // Validations métier
        validateMouvement(request);

        Produit produit = produitRepository.findById(request.getProduitId())
                .orElseThrow(() -> new ResourceNotFoundException("Produit", "id", request.getProduitId()));

        VarianteProduit variante = null;
        if (request.getVarianteId() != null) {
            variante = varianteProduitRepository.findById(request.getVarianteId())
                    .orElseThrow(() -> new ResourceNotFoundException("Variante", "id", request.getVarianteId()));
        }

        Utilisateur utilisateur = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        // Construire le mouvement
        MouvementStock mouvement = MouvementStock.builder()
                .produit(produit)
                .variante(variante)
                .type(request.getType())
                .motif(request.getMotif())
                .quantite(request.getQuantite())
                .reference(request.getReference())
                .commentaire(request.getCommentaire())
                .utilisateur(utilisateur)
                .build();

        if (request.getUuidSync() != null) {
            mouvement.setUuidSync(request.getUuidSync());
        }

        // Dépôts source et destination
        Depot depotSource = null;
        Depot depotDest = null;

        if (request.getDepotSourceId() != null) {
            depotSource = depotRepository.findById(request.getDepotSourceId())
                    .orElseThrow(() -> new ResourceNotFoundException("Dépôt source", "id", request.getDepotSourceId()));
            mouvement.setDepotSource(depotSource);
        }
        if (request.getDepotDestId() != null) {
            depotDest = depotRepository.findById(request.getDepotDestId())
                    .orElseThrow(() -> new ResourceNotFoundException("Dépôt destination", "id", request.getDepotDestId()));
            mouvement.setDepotDest(depotDest);
        }

        // Appliquer le mouvement sur le stock courant
        switch (request.getType()) {
            case ENTREE -> appliquerEntree(produit, variante, depotDest, request.getQuantite());
            case SORTIE -> appliquerSortie(produit, variante, depotSource, request.getQuantite(), request.isForcerSortie());
            case TRANSFERT -> {
                appliquerSortie(produit, variante, depotSource, request.getQuantite(), request.isForcerSortie());
                appliquerEntree(produit, variante, depotDest, request.getQuantite());
            }
            case AJUSTEMENT -> appliquerAjustement(produit, variante, depotDest != null ? depotDest : depotSource, request.getQuantite());
        }

        mouvement = mouvementStockRepository.save(mouvement);
        log.info("Mouvement {} enregistré: {} x {} [{}]",
                request.getType(), request.getQuantite(), produit.getNom(), mouvement.getUuidSync());
        auditService.logAction("STOCK_MOVE", "Stock", mouvement.getId(), 
                String.format("Mouvement %s: %s x %s (%s)", request.getType(), request.getQuantite(), produit.getNom(), request.getMotif()));

        return mouvement;
    }

    // =================== STOCK COURANT ===================

    @Transactional(readOnly = true)
    public List<StockCourant> getStockByProduit(Long produitId) {
        if (!securityUtils.isSuperAdmin()) {
            Long entrepriseId = securityUtils.getCurrentEntrepriseId();
            Produit produit = produitRepository.findById(produitId)
                    .orElseThrow(() -> new ResourceNotFoundException("Produit", "id", produitId));
            if (produit.getEntreprise() != null && !produit.getEntreprise().getId().equals(entrepriseId)) {
                throw new BusinessException("Accès refusé : ce produit n'appartient pas à votre entreprise");
            }
        }
        return stockCourantRepository.findByProduitId(produitId);
    }

    @Transactional(readOnly = true)
    public List<StockCourant> getStockByDepot(Long depotId) {
        Depot depot = depotRepository.findById(depotId)
                .orElseThrow(() -> new ResourceNotFoundException("Dépôt", "id", depotId));
        if (!securityUtils.isSuperAdmin()) {
            Long currentEntrepriseId = securityUtils.getCurrentEntrepriseId();
            if (depot.getEntreprise() == null || !depot.getEntreprise().getId().equals(currentEntrepriseId)) {
                throw new BusinessException("Accès refusé : ce dépôt n'appartient pas à votre entreprise");
            }
        }
        return stockCourantRepository.findByDepotId(depotId);
    }

    @Transactional(readOnly = true)
    public List<StockCourant> getAlertesBasses() {
        if (securityUtils.isSuperAdmin()) {
            return stockCourantRepository.findAlertesBasses();
        }
        Long entrepriseId = securityUtils.getCurrentEntrepriseId();
        return entrepriseId != null ? stockCourantRepository.findAlertesBassesByEntrepriseId(entrepriseId) : Collections.emptyList();
    }

    @Transactional(readOnly = true)
    public List<StockCourant> getRuptures() {
        if (securityUtils.isSuperAdmin()) {
            return stockCourantRepository.findRuptures();
        }
        Long entrepriseId = securityUtils.getCurrentEntrepriseId();
        return entrepriseId != null ? stockCourantRepository.findRupturesByEntrepriseId(entrepriseId) : Collections.emptyList();
    }

    @Transactional(readOnly = true)
    public List<StockCourant> getAlertesParDepot(Long depotId) {
        Depot depot = depotRepository.findById(depotId)
                .orElseThrow(() -> new ResourceNotFoundException("Dépôt", "id", depotId));
        if (!securityUtils.isSuperAdmin()) {
            Long currentEntrepriseId = securityUtils.getCurrentEntrepriseId();
            if (depot.getEntreprise() == null || !depot.getEntreprise().getId().equals(currentEntrepriseId)) {
                throw new BusinessException("Accès refusé : ce dépôt n'appartient pas à votre entreprise");
            }
        }
        return stockCourantRepository.findAlertesBassesByDepot(depotId);
    }

    @Transactional(readOnly = true)
    public Page<MouvementStock> getHistoriqueMouvements(Pageable pageable) {
        if (securityUtils.isSuperAdmin()) {
            return mouvementStockRepository.findAllByOrderByCreatedAtDesc(pageable);
        }
        Long entrepriseId = securityUtils.getCurrentEntrepriseId();
        if (entrepriseId != null) {
            return mouvementStockRepository.findByEntrepriseIdOrderByCreatedAtDesc(entrepriseId, pageable);
        }
        return Page.empty(pageable);
    }

    @Transactional(readOnly = true)
    public Page<MouvementStock> getMouvementsByProduit(Long produitId, Pageable pageable) {
        if (!securityUtils.isSuperAdmin()) {
            Long entrepriseId = securityUtils.getCurrentEntrepriseId();
            Produit produit = produitRepository.findById(produitId)
                    .orElseThrow(() -> new ResourceNotFoundException("Produit", "id", produitId));
            if (produit.getEntreprise() != null && !produit.getEntreprise().getId().equals(entrepriseId)) {
                throw new BusinessException("Accès refusé : ce produit n'appartient pas à votre entreprise");
            }
        }
        return mouvementStockRepository.findByProduitId(produitId, pageable);
    }

    @Transactional(readOnly = true)
    public Page<MouvementStock> filterMouvements(
            Long depotId, TypeMouvement type, Long produitId,
            java.time.Instant start, java.time.Instant end, Pageable pageable) {
        Long entrepriseId = securityUtils.isSuperAdmin() ? null : securityUtils.getCurrentEntrepriseId();
        return mouvementStockRepository.filterMouvements(entrepriseId, depotId, type, produitId, start, end, pageable);
    }

    @Transactional(readOnly = true)
    public List<Depot> getAllDepots() {
        if (securityUtils.isSuperAdmin()) {
            return depotRepository.findByEstActifTrue();
        }
        Long entrepriseId = securityUtils.getCurrentEntrepriseId();
        return entrepriseId != null ? depotRepository.findByEntrepriseIdAndEstActifTrue(entrepriseId) : Collections.emptyList();
    }

    @Transactional
    public void reconcilierInventaire(com.quantis.stock.dto.ReconciliationRequest request, String userEmail) {
        Depot depot = depotRepository.findById(request.getDepotId())
                .orElseThrow(() -> new ResourceNotFoundException("Dépôt", "id", request.getDepotId()));
        
        Utilisateur utilisateur = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        for (com.quantis.stock.dto.ReconciliationItem item : request.getItems()) {
            Produit produit = produitRepository.findById(item.getProduitId())
                    .orElseThrow(() -> new ResourceNotFoundException("Produit", "id", item.getProduitId()));

            VarianteProduit variante = null;
            if (item.getVarianteId() != null) {
                variante = varianteProduitRepository.findById(item.getVarianteId())
                        .orElseThrow(() -> new ResourceNotFoundException("Variante", "id", item.getVarianteId()));
            }

            // Récupérer le stock courant actuel
            StockCourant stock = getOrCreateStock(produit, variante, depot);
            BigDecimal quantiteTheorique = stock.getQuantite();
            BigDecimal quantitePhysique = item.getQuantitePhysique();

            // S'il y a un écart, on fait l'ajustement
            if (quantiteTheorique.compareTo(quantitePhysique) != 0) {
                // Créer le mouvement d'ajustement
                MouvementStock mouvement = MouvementStock.builder()
                        .produit(produit)
                        .variante(variante)
                        .type(TypeMouvement.AJUSTEMENT)
                        .motif(com.quantis.stock.model.enums.MotifMouvement.INVENTAIRE)
                        .quantite(quantitePhysique)
                        .depotSource(depot)
                        .depotDest(depot)
                        .reference(request.getReference())
                        .commentaire(request.getCommentaire() != null ? request.getCommentaire() : "Rapprochement d'inventaire physique")
                        .utilisateur(utilisateur)
                        .build();

                mouvementStockRepository.save(mouvement);

                // Appliquer l'ajustement
                stock.setQuantite(quantitePhysique);
                stockCourantRepository.save(stock);
            }
        }
        auditService.logAction(utilisateur, "INVENTAIRE", "Stock", depot.getId(),
                "Réconciliation d'inventaire pour le dépôt " + depot.getNom() + " (Réf: " + request.getReference() + ")", null);
        log.info("Réconciliation d'inventaire effectuée pour le dépôt '{}' par '{}'", depot.getNom(), userEmail);
    }

    // =================== LOGIQUE INTERNE ===================

    private void validateMouvement(MouvementRequest request) {
        switch (request.getType()) {
            case ENTREE -> {
                if (request.getDepotDestId() == null)
                    throw new BusinessException("Le dépôt de destination est requis pour une ENTREE");
            }
            case SORTIE -> {
                if (request.getDepotSourceId() == null)
                    throw new BusinessException("Le dépôt source est requis pour une SORTIE");
            }
            case TRANSFERT -> {
                if (request.getDepotSourceId() == null || request.getDepotDestId() == null)
                    throw new BusinessException("Les dépôts source et destination sont requis pour un TRANSFERT");
                if (request.getDepotSourceId().equals(request.getDepotDestId()))
                    throw new BusinessException("Les dépôts source et destination doivent être différents");
            }
            case AJUSTEMENT -> {
                if (request.getDepotSourceId() == null && request.getDepotDestId() == null)
                    throw new BusinessException("Un dépôt est requis pour un AJUSTEMENT");
            }
        }
    }

    private void appliquerEntree(Produit produit, VarianteProduit variante, Depot depot, BigDecimal quantite) {
        StockCourant stock = getOrCreateStock(produit, variante, depot);
        stock.setQuantite(stock.getQuantite().add(quantite));
        stockCourantRepository.save(stock);
    }

    private void appliquerSortie(Produit produit, VarianteProduit variante, Depot depot, BigDecimal quantite, boolean forcerSortie) {
        StockCourant stock = getOrCreateStock(produit, variante, depot);
        BigDecimal nouveauStock = stock.getQuantite().subtract(quantite);
        if (nouveauStock.compareTo(BigDecimal.ZERO) < 0 && !forcerSortie) {
            throw new BusinessException(String.format(
                    "Stock insuffisant pour '%s' dans '%s'. Disponible: %s, Demandé: %s",
                    produit.getNom(), depot.getNom(), stock.getQuantite(), quantite));
        }
        stock.setQuantite(nouveauStock);
        stockCourantRepository.save(stock);
    }

    private void appliquerAjustement(Produit produit, VarianteProduit variante, Depot depot, BigDecimal nouvelleQuantite) {
        StockCourant stock = getOrCreateStock(produit, variante, depot);
        stock.setQuantite(nouvelleQuantite);
        stockCourantRepository.save(stock);
    }

    private StockCourant getOrCreateStock(Produit produit, VarianteProduit variante, Depot depot) {
        if (variante != null) {
            return stockCourantRepository
                    .findByProduitIdAndVarianteIdAndDepotId(produit.getId(), variante.getId(), depot.getId())
                    .orElseGet(() -> StockCourant.builder()
                            .produit(produit).variante(variante).depot(depot)
                            .quantite(BigDecimal.ZERO).build());
        } else {
            return stockCourantRepository
                    .findByProduitIdAndVarianteIsNullAndDepotId(produit.getId(), depot.getId())
                    .orElseGet(() -> StockCourant.builder()
                            .produit(produit).depot(depot)
                            .quantite(BigDecimal.ZERO).build());
        }
    }

    /**
     * Calcule la vélocité de vente sur 30 jours et génère des suggestions de réapprovisionnement intelligentes.
     */
    @Transactional(readOnly = true)
    public List<com.quantis.stock.dto.ReapprovisionnementSuggestionDto> getSuggestionsReapprovisionnement() {
        java.time.Instant start30Days = java.time.Instant.now().minus(30, java.time.temporal.ChronoUnit.DAYS);
        List<Produit> produits = produitRepository.findByActifTrue();
        List<com.quantis.stock.dto.ReapprovisionnementSuggestionDto> suggestions = new java.util.ArrayList<>();

        for (Produit p : produits) {
            BigDecimal stockTotal = stockCourantRepository.getQuantiteTotaleParProduit(p.getId());
            if (stockTotal == null) {
                stockTotal = BigDecimal.ZERO;
            }

            BigDecimal sorties30Jours = mouvementStockRepository.sumSortiesSince(p.getId(), start30Days);
            if (sorties30Jours == null) {
                sorties30Jours = BigDecimal.ZERO;
            }

            BigDecimal ventesMoyJour = sorties30Jours.divide(BigDecimal.valueOf(30), 2, java.math.RoundingMode.HALF_UP);
            int seuil = p.getSeuilAlerte() != null ? p.getSeuilAlerte() : 5;
            BigDecimal seuilBd = BigDecimal.valueOf(seuil);

            Integer joursAutonomie = null;
            if (ventesMoyJour.compareTo(BigDecimal.ZERO) > 0) {
                joursAutonomie = stockTotal.divide(ventesMoyJour, 0, java.math.RoundingMode.DOWN).intValue();
            }

            // Statut d'urgence
            String urgence = "NORMAL";
            boolean besoinReappro = false;

            if (stockTotal.compareTo(BigDecimal.ZERO) <= 0) {
                urgence = "CRITIQUE";
                besoinReappro = true;
            } else if (stockTotal.compareTo(seuilBd) <= 0 || (joursAutonomie != null && joursAutonomie <= 7)) {
                urgence = "CRITIQUE";
                besoinReappro = true;
            } else if (joursAutonomie != null && joursAutonomie <= 15) {
                urgence = "ATTENTION";
                besoinReappro = true;
            }

            if (besoinReappro || stockTotal.compareTo(seuilBd) <= 0) {
                // Quantité suggérée pour couvrir 30 jours de vente + seuil de sécurité
                BigDecimal besoin30Jours = ventesMoyJour.multiply(BigDecimal.valueOf(30)).setScale(0, java.math.RoundingMode.CEILING);
                if (besoin30Jours.compareTo(BigDecimal.valueOf(10)) < 0) {
                    besoin30Jours = BigDecimal.valueOf(10); // Minimum 10 unités
                }
                BigDecimal quantiteSuggeree = besoin30Jours.add(seuilBd).subtract(stockTotal);
                if (quantiteSuggeree.compareTo(BigDecimal.ZERO) < 0) {
                    quantiteSuggeree = BigDecimal.valueOf(10);
                }

                BigDecimal prixAchat = p.getPrixAchat() != null ? p.getPrixAchat() : BigDecimal.ZERO;
                BigDecimal montantEstime = quantiteSuggeree.multiply(prixAchat);

                suggestions.add(com.quantis.stock.dto.ReapprovisionnementSuggestionDto.builder()
                        .produitId(p.getId())
                        .sku(p.getSku())
                        .nom(p.getNom())
                        .categorie(p.getCategorie() != null ? p.getCategorie().getNom() : null)
                        .unite(p.getUnite() != null ? p.getUnite().getNom() : "Unité")
                        .stockActuel(stockTotal)
                        .seuilAlerte(seuil)
                        .ventesMoisDernier(sorties30Jours)
                        .ventesMoyennesJour(ventesMoyJour)
                        .joursAutonomie(joursAutonomie)
                        .quantiteSuggeree(quantiteSuggeree)
                        .prixAchat(prixAchat)
                        .montantTotalEstime(montantEstime)
                        .statutUrgence(urgence)
                        .build());
            }
        }

        // Trier : CRITIQUE d'abord, puis jours d'autonomie croissants
        suggestions.sort((a, b) -> {
            if (a.getStatutUrgence().equals(b.getStatutUrgence())) {
                int ja1 = a.getJoursAutonomie() != null ? a.getJoursAutonomie() : 999;
                int ja2 = b.getJoursAutonomie() != null ? b.getJoursAutonomie() : 999;
                return Integer.compare(ja1, ja2);
            }
            return a.getStatutUrgence().equals("CRITIQUE") ? -1 : 1;
        });

        return suggestions;
    }
}

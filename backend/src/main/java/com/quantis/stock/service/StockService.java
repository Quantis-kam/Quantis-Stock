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
import java.util.List;

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
            case SORTIE -> appliquerSortie(produit, variante, depotSource, request.getQuantite());
            case TRANSFERT -> {
                appliquerSortie(produit, variante, depotSource, request.getQuantite());
                appliquerEntree(produit, variante, depotDest, request.getQuantite());
            }
            case AJUSTEMENT -> appliquerAjustement(produit, variante, depotDest != null ? depotDest : depotSource, request.getQuantite());
        }

        mouvement = mouvementStockRepository.save(mouvement);
        log.info("Mouvement {} enregistré: {} x {} [{}]",
                request.getType(), request.getQuantite(), produit.getNom(), mouvement.getUuidSync());

        return mouvement;
    }

    // =================== STOCK COURANT ===================

    @Transactional(readOnly = true)
    public List<StockCourant> getStockByProduit(Long produitId) {
        return stockCourantRepository.findByProduitId(produitId);
    }

    @Transactional(readOnly = true)
    public List<StockCourant> getStockByDepot(Long depotId) {
        return stockCourantRepository.findByDepotId(depotId);
    }

    @Transactional(readOnly = true)
    public List<StockCourant> getAlertesBasses() {
        return stockCourantRepository.findAlertesBasses();
    }

    @Transactional(readOnly = true)
    public List<StockCourant> getRuptures() {
        return stockCourantRepository.findRuptures();
    }

    @Transactional(readOnly = true)
    public List<StockCourant> getAlertesParDepot(Long depotId) {
        return stockCourantRepository.findAlertesBassesByDepot(depotId);
    }

    @Transactional(readOnly = true)
    public Page<MouvementStock> getHistoriqueMouvements(Pageable pageable) {
        return mouvementStockRepository.findAllByOrderByCreatedAtDesc(pageable);
    }

    @Transactional(readOnly = true)
    public Page<MouvementStock> getMouvementsByProduit(Long produitId, Pageable pageable) {
        return mouvementStockRepository.findByProduitId(produitId, pageable);
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

    private void appliquerSortie(Produit produit, VarianteProduit variante, Depot depot, BigDecimal quantite) {
        StockCourant stock = getOrCreateStock(produit, variante, depot);
        BigDecimal nouveauStock = stock.getQuantite().subtract(quantite);
        if (nouveauStock.compareTo(BigDecimal.ZERO) < 0) {
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
}

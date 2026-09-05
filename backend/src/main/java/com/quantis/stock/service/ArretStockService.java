package com.quantis.stock.service;

import com.quantis.stock.dto.ArretStockRequest;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.*;
import com.quantis.stock.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ArretStockService {

    private final ArretStockRepository arretStockRepository;
    private final StockCourantRepository stockCourantRepository;
    private final UtilisateurRepository utilisateurRepository;
    private final DepotRepository depotRepository;
    private final AuditService auditService;

    @Transactional
    public ArretStock creerArretStock(String userEmail, ArretStockRequest request) {
        Utilisateur user = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        Depot depot = null;
        List<StockCourant> stocks;
        if (request.getDepotId() != null) {
            depot = depotRepository.findById(request.getDepotId())
                    .orElseThrow(() -> new ResourceNotFoundException("Dépôt", "id", request.getDepotId()));
            stocks = stockCourantRepository.findByDepotId(depot.getId());
        } else {
            stocks = stockCourantRepository.findAll();
        }

        if (stocks.isEmpty()) {
            throw new BusinessException("Aucun stock trouvé pour réaliser un arrêt de stock.");
        }

        String datePrefix = DateTimeFormatter.ofPattern("yyyyMMdd-HHmm")
                .withZone(ZoneId.systemDefault())
                .format(Instant.now());
        String ref = "ARR-" + datePrefix + "-" + (arretStockRepository.count() + 1);

        BigDecimal totalAchat = BigDecimal.ZERO;
        BigDecimal totalVente = BigDecimal.ZERO;
        List<LigneArretStock> lignes = new ArrayList<>();

        ArretStock arretStock = ArretStock.builder()
                .reference(ref)
                .depot(depot)
                .entreprise(user.getEntreprise())
                .dateArret(Instant.now())
                .utilisateur(user)
                .notes(request.getNotes())
                .nbrProduits(stocks.size())
                .build();

        for (StockCourant s : stocks) {
            BigDecimal qte = s.getQuantite() != null ? s.getQuantite() : BigDecimal.ZERO;
            BigDecimal pxAchat = s.getProduit().getPrixAchat() != null ? s.getProduit().getPrixAchat() : BigDecimal.ZERO;
            BigDecimal pxVente = s.getProduit().getPrixVente() != null ? s.getProduit().getPrixVente() : BigDecimal.ZERO;

            BigDecimal valAchat = qte.multiply(pxAchat);
            BigDecimal valVente = qte.multiply(pxVente);

            totalAchat = totalAchat.add(valAchat);
            totalVente = totalVente.add(valVente);

            LigneArretStock ligne = LigneArretStock.builder()
                    .arretStock(arretStock)
                    .produit(s.getProduit())
                    .variante(s.getVariante())
                    .quantiteProjetee(qte)
                    .prixAchatUnitaire(pxAchat)
                    .prixVenteUnitaire(pxVente)
                    .valeurAchatTotale(valAchat)
                    .valeurVenteTotale(valVente)
                    .build();

            lignes.add(ligne);
        }

        arretStock.setValeurTotaleAchat(totalAchat);
        arretStock.setValeurTotaleVente(totalVente);
        arretStock.setLignes(lignes);

        ArretStock saved = arretStockRepository.save(arretStock);

        auditService.logAction("CREATION_ARRET_STOCK", "ArretStock", saved.getId(),
                "Création arrêt de stock " + saved.getReference() + " par " + userEmail +
                " (Valeur Achat: " + totalAchat + " FCFA, Produits: " + stocks.size() + ")");

        return saved;
    }

    @Transactional(readOnly = true)
    public Page<ArretStock> findAll(Pageable pageable) {
        return arretStockRepository.findAll(pageable);
    }

    @Transactional(readOnly = true)
    public ArretStock findById(Long id) {
        return arretStockRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("ArretStock", "id", id));
    }
}

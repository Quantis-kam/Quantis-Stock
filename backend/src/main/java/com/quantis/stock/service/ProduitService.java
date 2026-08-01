package com.quantis.stock.service;

import com.quantis.stock.dto.ProduitRequest;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.*;
import com.quantis.stock.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;

/**
 * Service CRUD pour les produits et variantes.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ProduitService {

    private final ProduitRepository produitRepository;
    private final CategorieRepository categorieRepository;
    private final UniteMesureRepository uniteMesureRepository;
    private final VarianteProduitRepository varianteProduitRepository;

    @Transactional(readOnly = true)
    public Page<Produit> findAll(Pageable pageable) {
        return produitRepository.findByActifTrue(pageable);
    }

    @Transactional(readOnly = true)
    public Produit findById(Long id) {
        return produitRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Produit", "id", id));
    }

    @Transactional(readOnly = true)
    public Produit findBySku(String sku) {
        return produitRepository.findBySku(sku)
                .orElseThrow(() -> new ResourceNotFoundException("Produit", "sku", sku));
    }

    @Transactional(readOnly = true)
    public Produit findByCodeBarres(String codeBarres) {
        return produitRepository.findByCodeBarres(codeBarres)
                .orElseThrow(() -> new ResourceNotFoundException("Produit", "codeBarres", codeBarres));
    }

    @Transactional(readOnly = true)
    public Page<Produit> search(String query, Pageable pageable) {
        return produitRepository.search(query, pageable);
    }

    @Transactional(readOnly = true)
    public Page<Produit> findByCategorie(Long categorieId, Pageable pageable) {
        return produitRepository.findByCategorieId(categorieId, pageable);
    }

    @Transactional
    public Produit create(ProduitRequest request) {
        if (produitRepository.existsBySku(request.getSku())) {
            throw new BusinessException("Un produit avec le SKU '" + request.getSku() + "' existe déjà");
        }
        if (request.getCodeBarres() != null && produitRepository.existsByCodeBarres(request.getCodeBarres())) {
            throw new BusinessException("Un produit avec ce code-barres existe déjà");
        }

        Produit produit = Produit.builder()
                .sku(request.getSku())
                .codeBarres(request.getCodeBarres())
                .nom(request.getNom())
                .description(request.getDescription())
                .prixAchat(request.getPrixAchat())
                .prixVente(request.getPrixVente())
                .imageUrl(request.getImageUrl())
                .build();

        if (request.getTauxTva() != null) produit.setTauxTva(request.getTauxTva());
        if (request.getSeuilAlerte() != null) produit.setSeuilAlerte(request.getSeuilAlerte());

        // Catégorie
        if (request.getCategorieId() != null) {
            Categorie cat = categorieRepository.findById(request.getCategorieId())
                    .orElseThrow(() -> new ResourceNotFoundException("Catégorie", "id", request.getCategorieId()));
            produit.setCategorie(cat);
        }

        // Unité
        if (request.getUniteId() != null) {
            UniteMesure unite = uniteMesureRepository.findById(request.getUniteId())
                    .orElseThrow(() -> new ResourceNotFoundException("Unité", "id", request.getUniteId()));
            produit.setUnite(unite);
        }

        produit = produitRepository.save(produit);

        // Variantes
        if (request.getVariantes() != null && !request.getVariantes().isEmpty()) {
            for (ProduitRequest.VarianteRequest vr : request.getVariantes()) {
                VarianteProduit variante = VarianteProduit.builder()
                        .produit(produit)
                        .attribut(vr.getAttribut())
                        .valeur(vr.getValeur())
                        .skuVariante(vr.getSkuVariante())
                        .codeBarresVariante(vr.getCodeBarresVariante())
                        .prixAchatOverride(vr.getPrixAchatOverride())
                        .prixVenteOverride(vr.getPrixVenteOverride())
                        .build();
                varianteProduitRepository.save(variante);
            }
        }

        log.info("Produit créé: {} [{}]", produit.getNom(), produit.getSku());
        return produit;
    }

    @Transactional
    public Produit update(Long id, ProduitRequest request) {
        Produit produit = findById(id);

        // Vérifier unicité SKU si changé
        if (!produit.getSku().equals(request.getSku()) && produitRepository.existsBySku(request.getSku())) {
            throw new BusinessException("Un produit avec le SKU '" + request.getSku() + "' existe déjà");
        }

        produit.setSku(request.getSku());
        produit.setCodeBarres(request.getCodeBarres());
        produit.setNom(request.getNom());
        produit.setDescription(request.getDescription());
        produit.setPrixAchat(request.getPrixAchat());
        produit.setPrixVente(request.getPrixVente());
        produit.setImageUrl(request.getImageUrl());
        if (request.getTauxTva() != null) produit.setTauxTva(request.getTauxTva());
        if (request.getSeuilAlerte() != null) produit.setSeuilAlerte(request.getSeuilAlerte());

        if (request.getCategorieId() != null) {
            produit.setCategorie(categorieRepository.findById(request.getCategorieId())
                    .orElseThrow(() -> new ResourceNotFoundException("Catégorie", "id", request.getCategorieId())));
        }
        if (request.getUniteId() != null) {
            produit.setUnite(uniteMesureRepository.findById(request.getUniteId())
                    .orElseThrow(() -> new ResourceNotFoundException("Unité", "id", request.getUniteId())));
        }

        log.info("Produit mis à jour: {} [{}]", produit.getNom(), produit.getSku());
        return produitRepository.save(produit);
    }

    @Transactional
    public void softDelete(Long id) {
        Produit produit = findById(id);
        produit.setActif(false);
        produitRepository.save(produit);
        log.info("Produit désactivé: {} [{}]", produit.getNom(), produit.getSku());
    }
}

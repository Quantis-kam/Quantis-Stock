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
    private final com.quantis.stock.security.SecurityUtils securityUtils;

    @Transactional(readOnly = true)
    public Page<Produit> findAll(Pageable pageable) {
        if (securityUtils.isSuperAdmin()) {
            return produitRepository.findByActifTrue(pageable);
        }
        Long entId = securityUtils.getCurrentEntrepriseId();
        if (entId != null) {
            return produitRepository.findByEntrepriseIdAndActifTrue(entId, pageable);
        }
        return produitRepository.findByActifTrue(pageable);
    }

    @Transactional(readOnly = true)
    public Produit findById(Long id) {
        Produit produit = produitRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Produit", "id", id));
        if (!securityUtils.isSuperAdmin()) {
            Long entId = securityUtils.getCurrentEntrepriseId();
            if (produit.getEntreprise() != null && !produit.getEntreprise().getId().equals(entId)) {
                throw new BusinessException("Accès refusé : ce produit n'appartient pas à votre entreprise");
            }
        }
        return produit;
    }

    @Transactional(readOnly = true)
    public Produit findBySku(String sku) {
        if (!securityUtils.isSuperAdmin()) {
            Long entId = securityUtils.getCurrentEntrepriseId();
            if (entId != null) {
                return produitRepository.findByEntrepriseIdAndSku(entId, sku)
                        .orElseThrow(() -> new ResourceNotFoundException("Produit", "sku", sku));
            }
        }
        return produitRepository.findBySku(sku)
                .orElseThrow(() -> new ResourceNotFoundException("Produit", "sku", sku));
    }

    @Transactional(readOnly = true)
    public Produit findByCodeBarres(String codeBarres) {
        if (!securityUtils.isSuperAdmin()) {
            Long entId = securityUtils.getCurrentEntrepriseId();
            if (entId != null) {
                return produitRepository.findByEntrepriseIdAndCodeBarres(entId, codeBarres)
                        .orElseThrow(() -> new ResourceNotFoundException("Produit", "codeBarres", codeBarres));
            }
        }
        return produitRepository.findByCodeBarres(codeBarres)
                .orElseThrow(() -> new ResourceNotFoundException("Produit", "codeBarres", codeBarres));
    }

    @Transactional(readOnly = true)
    public Page<Produit> search(String query, Pageable pageable) {
        if (securityUtils.isSuperAdmin()) {
            return produitRepository.search(query, pageable);
        }
        Long entId = securityUtils.getCurrentEntrepriseId();
        if (entId != null) {
            return produitRepository.searchByEntreprise(entId, query, pageable);
        }
        return produitRepository.search(query, pageable);
    }

    @Transactional(readOnly = true)
    public Page<Produit> findByCategorie(Long categorieId, Pageable pageable) {
        Long entId = securityUtils.getCurrentEntrepriseId();
        if (entId != null && !securityUtils.isSuperAdmin()) {
            return produitRepository.findByEntrepriseIdAndCategorieId(entId, categorieId, pageable);
        }
        return produitRepository.findByCategorieId(categorieId, pageable);
    }

    @Transactional
    public Produit create(ProduitRequest request) {
        Entreprise entreprise = securityUtils.getCurrentEntreprise().orElse(null);
        Long entId = entreprise != null ? entreprise.getId() : null;

        boolean skuExists = entId != null
                ? produitRepository.existsByEntrepriseIdAndSku(entId, request.getSku())
                : produitRepository.existsBySku(request.getSku());
        if (skuExists) {
            throw new BusinessException("Un produit avec le SKU '" + request.getSku() + "' existe déjà dans votre catalogue");
        }

        if (request.getCodeBarres() != null) {
            boolean barcodeExists = entId != null
                    ? produitRepository.existsByEntrepriseIdAndCodeBarres(entId, request.getCodeBarres())
                    : produitRepository.existsByCodeBarres(request.getCodeBarres());
            if (barcodeExists) {
                throw new BusinessException("Un produit avec ce code-barres existe déjà");
            }
        }

        Produit produit = Produit.builder()
                .entreprise(entreprise)
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

        Long entId = securityUtils.getCurrentEntrepriseId();
        boolean skuExists = entId != null
                ? produitRepository.existsByEntrepriseIdAndSku(entId, request.getSku())
                : produitRepository.existsBySku(request.getSku());

        // Vérifier unicité SKU si changé
        if (!produit.getSku().equals(request.getSku()) && skuExists) {
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

    @Transactional(readOnly = true)
    public java.util.List<UniteMesure> findAllUnits() {
        return uniteMesureRepository.findAll();
    }

    @Transactional
    public int importCsv(java.io.InputStream inputStream) throws Exception {
        int count = 0;
        try (java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.InputStreamReader(inputStream, java.nio.charset.StandardCharsets.UTF_8))) {
            String line;
            boolean isHeader = true;
            String separator = ",";
            
            while ((line = reader.readLine()) != null) {
                if (line.trim().isEmpty()) continue;
                if (isHeader) {
                    if (line.contains(";")) {
                        separator = ";";
                    }
                    isHeader = false;
                    continue;
                }
                
                String[] tokens = line.split(separator, -1);
                if (tokens.length < 2) continue;
                
                String sku = tokens[0].trim();
                String nom = tokens[1].trim();
                
                if (sku.isEmpty() || nom.isEmpty()) continue;
                
                Long entId = securityUtils.getCurrentEntrepriseId();
                boolean exists = entId != null
                        ? produitRepository.existsByEntrepriseIdAndSku(entId, sku)
                        : produitRepository.existsBySku(sku);
                if (exists) {
                    continue;
                }
                
                String description = tokens.length > 2 ? tokens[2].trim() : "";
                
                java.math.BigDecimal prixAchat = java.math.BigDecimal.ZERO;
                if (tokens.length > 3 && !tokens[3].trim().isEmpty()) {
                    try { prixAchat = new java.math.BigDecimal(tokens[3].trim()); } catch (Exception e) {}
                }
                
                java.math.BigDecimal prixVente = java.math.BigDecimal.ZERO;
                if (tokens.length > 4 && !tokens[4].trim().isEmpty()) {
                    try { prixVente = new java.math.BigDecimal(tokens[4].trim()); } catch (Exception e) {}
                }
                
                Integer seuilAlerte = 10;
                if (tokens.length > 5 && !tokens[5].trim().isEmpty()) {
                    try { seuilAlerte = Integer.parseInt(tokens[5].trim()); } catch (Exception e) {}
                }
                
                java.math.BigDecimal tauxTva = new java.math.BigDecimal("18");
                if (tokens.length > 6 && !tokens[6].trim().isEmpty()) {
                    try { tauxTva = new java.math.BigDecimal(tokens[6].trim()); } catch (Exception e) {}
                }
                
                String codeBarres = tokens.length > 7 ? tokens[7].trim() : null;
                if (codeBarres != null && codeBarres.isEmpty()) codeBarres = null;
                
                String categorieNom = tokens.length > 8 ? tokens[8].trim() : "";
                String uniteNom = tokens.length > 9 ? tokens[9].trim() : "";
                
                Produit produit = Produit.builder()
                        .entreprise(securityUtils.getCurrentEntreprise().orElse(null))
                        .sku(sku)
                        .codeBarres(codeBarres)
                        .nom(nom)
                        .description(description.isEmpty() ? null : description)
                        .prixAchat(prixAchat)
                        .prixVente(prixVente)
                        .seuilAlerte(seuilAlerte)
                        .tauxTva(tauxTva)
                        .actif(true)
                        .build();
                
                if (!categorieNom.isEmpty()) {
                    final String catName = categorieNom;
                    Categorie categorie = categorieRepository.findByNomIgnoreCase(catName)
                            .orElseGet(() -> categorieRepository.save(Categorie.builder().nom(catName).description("Créée par import").build()));
                    produit.setCategorie(categorie);
                }
                
                if (!uniteNom.isEmpty()) {
                    final String unitName = uniteNom;
                    UniteMesure unite = uniteMesureRepository.findByNomIgnoreCase(unitName)
                            .orElseGet(() -> {
                                String abrev = unitName.substring(0, Math.min(3, unitName.length())).toLowerCase();
                                return uniteMesureRepository.save(UniteMesure.builder().nom(unitName).abreviation(abrev).build());
                            });
                    produit.setUnite(unite);
                }
                
                produitRepository.save(produit);
                count++;
            }
        }
        return count;
    }
}

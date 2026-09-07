package com.quantis.stock.service;

import com.quantis.stock.dto.CategorieRequest;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.Categorie;
import com.quantis.stock.repository.CategorieRepository;
import com.quantis.stock.repository.ProduitRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.quantis.stock.security.SecurityUtils;
import java.util.Collections;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class CategorieService {

    private final CategorieRepository categorieRepository;
    private final ProduitRepository produitRepository;
    private final SecurityUtils securityUtils;

    public List<Categorie> findAll() {
        if (securityUtils.isSuperAdmin()) {
            return categorieRepository.findAll();
        }
        Long entId = securityUtils.getCurrentEntrepriseId();
        return entId != null ? categorieRepository.findByEntrepriseId(entId) : Collections.emptyList();
    }

    public List<Categorie> findRoots() {
        if (securityUtils.isSuperAdmin()) {
            return categorieRepository.findByParentIsNull();
        }
        Long entId = securityUtils.getCurrentEntrepriseId();
        return entId != null ? categorieRepository.findByEntrepriseIdAndParentIsNull(entId) : Collections.emptyList();
    }

    public Categorie findById(Long id) {
        Categorie categorie = categorieRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Catégorie", "id", id));
        if (!securityUtils.isSuperAdmin()) {
            Long entId = securityUtils.getCurrentEntrepriseId();
            if (categorie.getEntreprise() != null && !categorie.getEntreprise().getId().equals(entId)) {
                throw new BusinessException("Accès refusé : cette catégorie n'appartient pas à votre entreprise");
            }
        }
        return categorie;
    }

    @Transactional
    public Categorie create(CategorieRequest request) {
        Long entId = securityUtils.getCurrentEntrepriseId();
        boolean exists = entId != null
                ? categorieRepository.existsByEntrepriseIdAndNom(entId, request.getNom())
                : categorieRepository.existsByNom(request.getNom());
        if (exists) {
            throw new BusinessException("Une catégorie avec ce nom existe déjà");
        }

        Categorie categorie = Categorie.builder()
                .nom(request.getNom())
                .description(request.getDescription())
                .entreprise(securityUtils.getCurrentEntreprise().orElse(null))
                .build();

        if (request.getParentId() != null) {
            Categorie parent = findById(request.getParentId());
            categorie.setParent(parent);
        }

        categorie = categorieRepository.save(categorie);
        log.info("Catégorie créée: {} pour entreprise {}", categorie.getNom(), entId);
        return categorie;
    }

    @Transactional
    public Categorie update(Long id, CategorieRequest request) {
        Categorie categorie = findById(id);
        categorie.setNom(request.getNom());
        categorie.setDescription(request.getDescription());

        if (request.getParentId() != null) {
            if (request.getParentId().equals(id)) {
                throw new BusinessException("Une catégorie ne peut pas être son propre parent");
            }
            categorie.setParent(findById(request.getParentId()));
        } else {
            categorie.setParent(null);
        }

        return categorieRepository.save(categorie);
    }

    @Transactional
    public void delete(Long id) {
        Categorie categorie = findById(id);
        if (!categorie.getSousCategories().isEmpty()) {
            throw new BusinessException("Impossible de supprimer une catégorie avec des sous-catégories");
        }
        if (produitRepository.existsByCategorieId(id)) {
            throw new BusinessException("Impossible de supprimer une catégorie associée à des produits");
        }
        categorieRepository.delete(categorie);
        log.info("Catégorie supprimée: {}", categorie.getNom());
    }
}

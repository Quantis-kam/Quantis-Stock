package com.quantis.stock.repository;

import com.quantis.stock.model.Produit;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.EntityGraph;

@Repository
public interface ProduitRepository extends JpaRepository<Produit, Long> {

    @Override
    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    Optional<Produit> findById(Long id);

    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    Optional<Produit> findBySku(String sku);

    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    Optional<Produit> findByCodeBarres(String codeBarres);

    boolean existsBySku(String sku);

    boolean existsByCodeBarres(String codeBarres);

    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    Page<Produit> findByActifTrue(Pageable pageable);

    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    java.util.List<Produit> findByActifTrue();

    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    Page<Produit> findByCategorieId(Long categorieId, Pageable pageable);

    boolean existsByCategorieId(Long id);

    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    Page<Produit> findByEntrepriseIdAndActifTrue(Long entrepriseId, Pageable pageable);

    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    java.util.List<Produit> findByEntrepriseIdAndActifTrue(Long entrepriseId);

    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    Optional<Produit> findByEntrepriseIdAndSku(Long entrepriseId, String sku);

    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    Optional<Produit> findByEntrepriseIdAndCodeBarres(Long entrepriseId, String codeBarres);

    boolean existsByEntrepriseIdAndSku(Long entrepriseId, String sku);

    boolean existsByEntrepriseIdAndCodeBarres(Long entrepriseId, String codeBarres);

    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    Page<Produit> findByEntrepriseIdAndCategorieId(Long entrepriseId, Long categorieId, Pageable pageable);

    long countByEntrepriseId(Long entrepriseId);

    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    @Query("SELECT p FROM Produit p WHERE p.entreprise.id = :entrepriseId AND p.actif = true AND " +
           "(LOWER(p.nom) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(p.sku) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(p.codeBarres) LIKE LOWER(CONCAT('%', :q, '%')))")
    Page<Produit> searchByEntreprise(@Param("entrepriseId") Long entrepriseId, @Param("q") String query, Pageable pageable);

    @EntityGraph(attributePaths = {"categorie", "unite", "variantes"})
    @Query("SELECT p FROM Produit p WHERE p.actif = true AND " +
           "(LOWER(p.nom) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(p.sku) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(p.codeBarres) LIKE LOWER(CONCAT('%', :q, '%')))")
    Page<Produit> search(@Param("q") String query, Pageable pageable);
}

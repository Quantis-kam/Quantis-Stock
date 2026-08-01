package com.quantis.stock.repository;

import com.quantis.stock.model.Produit;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ProduitRepository extends JpaRepository<Produit, Long> {

    Optional<Produit> findBySku(String sku);

    Optional<Produit> findByCodeBarres(String codeBarres);

    boolean existsBySku(String sku);

    boolean existsByCodeBarres(String codeBarres);

    Page<Produit> findByActifTrue(Pageable pageable);

    Page<Produit> findByCategorieId(Long categorieId, Pageable pageable);

    @Query("SELECT p FROM Produit p WHERE p.actif = true AND " +
           "(LOWER(p.nom) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(p.sku) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(p.codeBarres) LIKE LOWER(CONCAT('%', :q, '%')))")
    Page<Produit> search(@Param("q") String query, Pageable pageable);
}

package com.quantis.stock.repository;

import com.quantis.stock.model.StockCourant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.EntityGraph;

@Repository
public interface StockCourantRepository extends JpaRepository<StockCourant, Long> {

    @Override
    @EntityGraph(attributePaths = {"produit", "variante", "depot"})
    Optional<StockCourant> findById(Long id);

    @EntityGraph(attributePaths = {"produit", "variante", "depot"})
    Optional<StockCourant> findByProduitIdAndVarianteIdAndDepotId(
            Long produitId, Long varianteId, Long depotId);

    @EntityGraph(attributePaths = {"produit", "variante", "depot"})
    Optional<StockCourant> findByProduitIdAndVarianteIsNullAndDepotId(
            Long produitId, Long depotId);

    @EntityGraph(attributePaths = {"produit", "variante", "depot"})
    List<StockCourant> findByProduitId(Long produitId);

    @EntityGraph(attributePaths = {"produit", "variante", "depot"})
    List<StockCourant> findByDepotId(Long depotId);

    @EntityGraph(attributePaths = {"produit", "variante", "depot"})
    @Query("SELECT s FROM StockCourant s WHERE s.quantite <= s.produit.seuilAlerte AND s.produit.actif = true")
    List<StockCourant> findAlertesBasses();

    @EntityGraph(attributePaths = {"produit", "variante", "depot"})
    @Query("SELECT s FROM StockCourant s WHERE s.quantite <= 0 AND s.produit.actif = true")
    List<StockCourant> findRuptures();

    @EntityGraph(attributePaths = {"produit", "variante", "depot"})
    @Query("SELECT s FROM StockCourant s WHERE s.depot.id = :depotId AND s.quantite <= s.produit.seuilAlerte AND s.produit.actif = true")
    List<StockCourant> findAlertesBassesByDepot(@Param("depotId") Long depotId);

    @Query("SELECT COALESCE(SUM(s.quantite), 0) FROM StockCourant s WHERE s.produit.id = :produitId")
    java.math.BigDecimal getQuantiteTotaleParProduit(@Param("produitId") Long produitId);
}

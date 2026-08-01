package com.quantis.stock.repository;

import com.quantis.stock.model.StockCourant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface StockCourantRepository extends JpaRepository<StockCourant, Long> {

    Optional<StockCourant> findByProduitIdAndVarianteIdAndDepotId(
            Long produitId, Long varianteId, Long depotId);

    Optional<StockCourant> findByProduitIdAndVarianteIsNullAndDepotId(
            Long produitId, Long depotId);

    List<StockCourant> findByProduitId(Long produitId);

    List<StockCourant> findByDepotId(Long depotId);

    @Query("SELECT s FROM StockCourant s WHERE s.quantite <= s.produit.seuilAlerte AND s.produit.actif = true")
    List<StockCourant> findAlertesBasses();

    @Query("SELECT s FROM StockCourant s WHERE s.quantite <= 0 AND s.produit.actif = true")
    List<StockCourant> findRuptures();

    @Query("SELECT s FROM StockCourant s WHERE s.depot.id = :depotId AND s.quantite <= s.produit.seuilAlerte AND s.produit.actif = true")
    List<StockCourant> findAlertesBassesByDepot(@Param("depotId") Long depotId);
}

package com.quantis.stock.repository;

import com.quantis.stock.model.MouvementStock;
import com.quantis.stock.model.enums.TypeMouvement;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;

import org.springframework.data.jpa.repository.EntityGraph;

@Repository
public interface MouvementStockRepository extends JpaRepository<MouvementStock, Long> {

    @Override
    @EntityGraph(attributePaths = {"produit", "variante", "depotSource", "depotDest", "utilisateur"})
    Optional<MouvementStock> findById(Long id);

    @EntityGraph(attributePaths = {"produit", "variante", "depotSource", "depotDest", "utilisateur"})
    Optional<MouvementStock> findByUuidSync(String uuidSync);

    boolean existsByUuidSync(String uuidSync);

    @EntityGraph(attributePaths = {"produit", "variante", "depotSource", "depotDest", "utilisateur"})
    Page<MouvementStock> findByProduitId(Long produitId, Pageable pageable);

    @EntityGraph(attributePaths = {"produit", "variante", "depotSource", "depotDest", "utilisateur"})
    Page<MouvementStock> findByType(TypeMouvement type, Pageable pageable);

    @EntityGraph(attributePaths = {"produit", "variante", "depotSource", "depotDest", "utilisateur"})
    Page<MouvementStock> findByCreatedAtBetween(Instant start, Instant end, Pageable pageable);

    @EntityGraph(attributePaths = {"produit", "variante", "depotSource", "depotDest", "utilisateur"})
    Page<MouvementStock> findAllByOrderByCreatedAtDesc(Pageable pageable);

    @EntityGraph(attributePaths = {"produit", "variante", "depotSource", "depotDest", "utilisateur"})
    @org.springframework.data.jpa.repository.Query("SELECT m FROM MouvementStock m WHERE " +
           "(:depotId IS NULL OR m.depotSource.id = :depotId OR m.depotDest.id = :depotId) AND " +
           "(:type IS NULL OR m.type = :type) AND " +
           "(:produitId IS NULL OR m.produit.id = :produitId) AND " +
           "(cast(:start as timestamp) IS NULL OR m.createdAt >= :start) AND " +
           "(cast(:end as timestamp) IS NULL OR m.createdAt <= :end) " +
           "ORDER BY m.createdAt DESC")
    Page<MouvementStock> filterMouvements(
            @org.springframework.data.repository.query.Param("depotId") Long depotId,
            @org.springframework.data.repository.query.Param("type") TypeMouvement type,
            @org.springframework.data.repository.query.Param("produitId") Long produitId,
            @org.springframework.data.repository.query.Param("start") Instant start,
            @org.springframework.data.repository.query.Param("end") Instant end,
            Pageable pageable);

    @org.springframework.data.jpa.repository.Query("SELECT COALESCE(SUM(m.quantite), 0) FROM MouvementStock m WHERE m.produit.id = :produitId AND m.type = 'SORTIE' AND m.createdAt >= :start")
    BigDecimal sumSortiesSince(@org.springframework.data.repository.query.Param("produitId") Long produitId, @org.springframework.data.repository.query.Param("start") Instant start);
}

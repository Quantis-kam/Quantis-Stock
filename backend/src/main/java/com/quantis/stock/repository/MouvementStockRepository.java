package com.quantis.stock.repository;

import com.quantis.stock.model.MouvementStock;
import com.quantis.stock.model.enums.TypeMouvement;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Optional;

@Repository
public interface MouvementStockRepository extends JpaRepository<MouvementStock, Long> {

    Optional<MouvementStock> findByUuidSync(String uuidSync);

    boolean existsByUuidSync(String uuidSync);

    Page<MouvementStock> findByProduitId(Long produitId, Pageable pageable);

    Page<MouvementStock> findByType(TypeMouvement type, Pageable pageable);

    Page<MouvementStock> findByCreatedAtBetween(Instant start, Instant end, Pageable pageable);

    Page<MouvementStock> findAllByOrderByCreatedAtDesc(Pageable pageable);
}

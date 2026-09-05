package com.quantis.stock.repository;

import com.quantis.stock.model.Paiement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@Repository
public interface PaiementRepository extends JpaRepository<Paiement, Long> {

    List<Paiement> findByDocumentId(Long documentId);

    Optional<Paiement> findByUuidSync(String uuidSync);

    boolean existsByUuidSync(String uuidSync);

    /**
     * Somme des paiements pour tous les documents d'un client.
     */
    @Query("SELECT COALESCE(SUM(p.montant), 0) FROM Paiement p WHERE p.document.client.id = :clientId")
    BigDecimal sumByClientId(@Param("clientId") Long clientId);
}

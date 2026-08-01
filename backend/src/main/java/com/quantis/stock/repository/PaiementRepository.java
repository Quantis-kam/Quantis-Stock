package com.quantis.stock.repository;

import com.quantis.stock.model.Paiement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PaiementRepository extends JpaRepository<Paiement, Long> {

    List<Paiement> findByDocumentId(Long documentId);

    Optional<Paiement> findByUuidSync(String uuidSync);

    boolean existsByUuidSync(String uuidSync);
}

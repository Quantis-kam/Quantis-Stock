package com.quantis.stock.repository;

import com.quantis.stock.model.Document;
import com.quantis.stock.model.enums.StatutDocument;
import com.quantis.stock.model.enums.TypeDocument;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface DocumentRepository extends JpaRepository<Document, Long> {

    Optional<Document> findByNumero(String numero);

    Optional<Document> findByUuidSync(String uuidSync);

    boolean existsByUuidSync(String uuidSync);

    Page<Document> findByType(TypeDocument type, Pageable pageable);

    Page<Document> findByClientId(Long clientId, Pageable pageable);

    Page<Document> findByStatut(StatutDocument statut, Pageable pageable);

    Page<Document> findByTypeAndStatut(TypeDocument type, StatutDocument statut, Pageable pageable);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(d.numero, LENGTH(:prefix) + 1) AS integer)), 0) " +
           "FROM Document d WHERE d.numero LIKE CONCAT(:prefix, '%')")
    int findMaxNumero(@Param("prefix") String prefix);
}

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

import java.math.BigDecimal;
import java.util.Optional;

@Repository
public interface DocumentRepository extends JpaRepository<Document, Long> {

    Optional<Document> findByNumero(String numero);

    Optional<Document> findByUuidSync(String uuidSync);

    boolean existsByUuidSync(String uuidSync);

    Page<Document> findByType(TypeDocument type, Pageable pageable);

    Page<Document> findByEntrepriseId(Long entrepriseId, Pageable pageable);

    Page<Document> findByEntrepriseIdAndType(Long entrepriseId, TypeDocument type, Pageable pageable);

    Page<Document> findByClientId(Long clientId, Pageable pageable);

    Page<Document> findByEntrepriseIdAndClientId(Long entrepriseId, Long clientId, Pageable pageable);

    Page<Document> findByStatut(StatutDocument statut, Pageable pageable);

    Page<Document> findByEntrepriseIdAndStatut(Long entrepriseId, StatutDocument statut, Pageable pageable);

    Page<Document> findByTypeAndStatut(TypeDocument type, StatutDocument statut, Pageable pageable);

    Page<Document> findByEntrepriseIdAndTypeAndStatut(Long entrepriseId, TypeDocument type, StatutDocument statut, Pageable pageable);

    long countByEntrepriseId(Long entrepriseId);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(d.numero, LENGTH(:prefix) + 1) AS integer)), 0) " +
           "FROM Document d WHERE d.numero LIKE CONCAT(:prefix, '%')")
    int findMaxNumero(@Param("prefix") String prefix);

    /**
     * Somme des TTC pour un client et un type de document validé.
     */
    @Query("SELECT COALESCE(SUM(d.totalTtc), 0) FROM Document d " +
           "WHERE d.client.id = :clientId AND d.type = :type AND d.statut = 'VALIDE'")
    BigDecimal sumTotalTtcByClientAndType(@Param("clientId") Long clientId, @Param("type") String type);

    java.util.List<Document> findByDateDocumentBetweenAndStatut(java.time.LocalDate debut, java.time.LocalDate fin, StatutDocument statut);

    java.util.List<Document> findByEntrepriseIdAndDateDocumentBetweenAndStatut(Long entrepriseId, java.time.LocalDate debut, java.time.LocalDate fin, StatutDocument statut);

    @Query("SELECT COALESCE(SUM(d.totalTtc), 0) FROM Document d " +
           "WHERE d.entreprise.id = :entrepriseId AND d.type = com.quantis.stock.model.enums.TypeDocument.FACTURE AND d.statut = com.quantis.stock.model.enums.StatutDocument.VALIDE")
    BigDecimal sumCaByEntrepriseId(@Param("entrepriseId") Long entrepriseId);

    @Query("SELECT COUNT(d) FROM Document d " +
           "WHERE d.entreprise.id = :entrepriseId AND d.type = com.quantis.stock.model.enums.TypeDocument.FACTURE")
    long countVentesByEntrepriseId(@Param("entrepriseId") Long entrepriseId);

    @Query("SELECT COALESCE(SUM(d.totalTtc), 0) FROM Document d " +
           "WHERE d.type = com.quantis.stock.model.enums.TypeDocument.FACTURE AND d.statut = com.quantis.stock.model.enums.StatutDocument.VALIDE")
    BigDecimal sumGlobalCa();

    @Query("SELECT COUNT(d) FROM Document d " +
           "WHERE d.type = com.quantis.stock.model.enums.TypeDocument.FACTURE")
    long countGlobalVentes();

    java.util.List<Document> findTop5ByEntrepriseIdOrderByCreatedAtDesc(Long entrepriseId);
}

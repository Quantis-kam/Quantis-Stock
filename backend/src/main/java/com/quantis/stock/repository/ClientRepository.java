package com.quantis.stock.repository;

import com.quantis.stock.model.Client;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.math.BigDecimal;
import org.springframework.stereotype.Repository;

@Repository
public interface ClientRepository extends JpaRepository<Client, Long> {

    Page<Client> findByActifTrue(Pageable pageable);

    Page<Client> findByEntrepriseIdAndActifTrue(Long entrepriseId, Pageable pageable);

    java.util.List<Client> findByNomContainingIgnoreCase(String nom);

    java.util.List<Client> findByEntrepriseIdAndNomContainingIgnoreCase(Long entrepriseId, String nom);

    long countByEntrepriseId(Long entrepriseId);

    @Query("SELECT c FROM Client c WHERE c.entreprise.id = :entrepriseId AND c.actif = true AND " +
           "(LOWER(c.nom) LIKE LOWER(CONCAT('%', :q, '%')) OR c.telephone LIKE CONCAT('%', :q, '%'))")
    Page<Client> searchByEntreprise(@Param("entrepriseId") Long entrepriseId, @Param("q") String query, Pageable pageable);

    @Query("SELECT c FROM Client c WHERE c.actif = true AND " +
           "(LOWER(c.nom) LIKE LOWER(CONCAT('%', :q, '%')) OR c.telephone LIKE CONCAT('%', :q, '%'))")
    Page<Client> search(@Param("q") String query, Pageable pageable);

    @Query("SELECT COALESCE(SUM(c.soldeCredit), 0) FROM Client c WHERE c.entreprise.id = :entrepriseId AND c.actif = true")
    BigDecimal sumSoldeCreditByEntreprise(@Param("entrepriseId") Long entrepriseId);

    @Query("SELECT COALESCE(SUM(c.soldeCredit), 0) FROM Client c WHERE c.actif = true")
    BigDecimal sumSoldeCredit();

    @Query("SELECT c FROM Client c WHERE c.entreprise.id = :entrepriseId AND c.actif = true AND c.soldeCredit > 0 ORDER BY c.soldeCredit DESC")
    java.util.List<Client> findDebiteursByEntreprise(@Param("entrepriseId") Long entrepriseId);

    @Query("SELECT c FROM Client c WHERE c.actif = true AND c.soldeCredit > 0 ORDER BY c.soldeCredit DESC")
    java.util.List<Client> findDebiteurs();
}

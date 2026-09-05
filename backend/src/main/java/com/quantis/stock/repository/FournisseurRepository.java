package com.quantis.stock.repository;

import com.quantis.stock.model.Fournisseur;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.math.BigDecimal;
import org.springframework.stereotype.Repository;

@Repository
public interface FournisseurRepository extends JpaRepository<Fournisseur, Long> {

    Page<Fournisseur> findByActifTrue(Pageable pageable);

    Page<Fournisseur> findByEntrepriseIdAndActifTrue(Long entrepriseId, Pageable pageable);

    long countByEntrepriseId(Long entrepriseId);

    @Query("SELECT f FROM Fournisseur f WHERE f.entreprise.id = :entrepriseId AND f.actif = true AND " +
           "(LOWER(f.nom) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(f.telephone) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(f.email) LIKE LOWER(CONCAT('%', :q, '%')))")
    Page<Fournisseur> searchByEntreprise(@Param("entrepriseId") Long entrepriseId, @Param("q") String query, Pageable pageable);

    @Query("SELECT f FROM Fournisseur f WHERE f.actif = true AND " +
           "(LOWER(f.nom) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(f.telephone) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(f.email) LIKE LOWER(CONCAT('%', :q, '%')))")
    Page<Fournisseur> search(@Param("q") String query, Pageable pageable);

    @Query("SELECT COALESCE(SUM(f.soldeDette), 0) FROM Fournisseur f WHERE f.entreprise.id = :entrepriseId AND f.actif = true")
    BigDecimal sumSoldeDetteByEntreprise(@Param("entrepriseId") Long entrepriseId);

    @Query("SELECT COALESCE(SUM(f.soldeDette), 0) FROM Fournisseur f WHERE f.actif = true")
    BigDecimal sumSoldeDette();

    @Query("SELECT f FROM Fournisseur f WHERE f.entreprise.id = :entrepriseId AND f.actif = true AND f.soldeDette > 0 ORDER BY f.soldeDette DESC")
    java.util.List<Fournisseur> findCrediteursByEntreprise(@Param("entrepriseId") Long entrepriseId);

    @Query("SELECT f FROM Fournisseur f WHERE f.actif = true AND f.soldeDette > 0 ORDER BY f.soldeDette DESC")
    java.util.List<Fournisseur> findCrediteurs();
}

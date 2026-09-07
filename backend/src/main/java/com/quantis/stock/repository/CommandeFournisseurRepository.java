package com.quantis.stock.repository;

import com.quantis.stock.model.CommandeFournisseur;
import com.quantis.stock.model.enums.StatutCommande;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface CommandeFournisseurRepository extends JpaRepository<CommandeFournisseur, Long> {

    Optional<CommandeFournisseur> findByNumero(String numero);

    Page<CommandeFournisseur> findByStatut(StatutCommande statut, Pageable pageable);

    Page<CommandeFournisseur> findByFournisseurId(Long fournisseurId, Pageable pageable);

    Page<CommandeFournisseur> findAllByOrderByCreatedAtDesc(Pageable pageable);

    Page<CommandeFournisseur> findByDepotEntrepriseIdOrderByCreatedAtDesc(Long entrepriseId, Pageable pageable);

    Page<CommandeFournisseur> findByDepotEntrepriseIdAndStatut(Long entrepriseId, StatutCommande statut, Pageable pageable);

    Page<CommandeFournisseur> findByDepotEntrepriseIdAndFournisseurId(Long entrepriseId, Long fournisseurId, Pageable pageable);

    java.util.List<CommandeFournisseur> findByDepotEntrepriseIdAndDateCommandeBetween(Long entrepriseId, java.time.LocalDate debut, java.time.LocalDate fin);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(c.numero, LENGTH(:prefix) + 1) AS integer)), 0) " +
           "FROM CommandeFournisseur c WHERE c.numero LIKE CONCAT(:prefix, '%')")
    int findMaxNumero(@Param("prefix") String prefix);

    java.util.List<CommandeFournisseur> findByDateCommandeBetween(java.time.LocalDate debut, java.time.LocalDate fin);

    @Query("SELECT COALESCE(SUM(c.totalHt), 0) FROM CommandeFournisseur c " +
           "WHERE c.depot.entreprise.id = :entrepriseId AND c.statut != com.quantis.stock.model.enums.StatutCommande.ANNULEE")
    java.math.BigDecimal sumAchatsByEntrepriseId(@Param("entrepriseId") Long entrepriseId);

    @Query("SELECT COUNT(c) FROM CommandeFournisseur c " +
           "WHERE c.depot.entreprise.id = :entrepriseId AND c.statut != com.quantis.stock.model.enums.StatutCommande.ANNULEE")
    long countAchatsByEntrepriseId(@Param("entrepriseId") Long entrepriseId);

    @Query("SELECT COALESCE(SUM(c.totalHt), 0) FROM CommandeFournisseur c WHERE c.statut != com.quantis.stock.model.enums.StatutCommande.ANNULEE")
    java.math.BigDecimal sumGlobalAchats();

    @Query("SELECT COUNT(c) FROM CommandeFournisseur c WHERE c.statut != com.quantis.stock.model.enums.StatutCommande.ANNULEE")
    long countGlobalAchats();

    java.util.List<CommandeFournisseur> findTop5ByDepotEntrepriseIdOrderByCreatedAtDesc(Long entrepriseId);
}

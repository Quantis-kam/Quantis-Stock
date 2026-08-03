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

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(c.numero, LENGTH(:prefix) + 1) AS integer)), 0) " +
           "FROM CommandeFournisseur c WHERE c.numero LIKE CONCAT(:prefix, '%')")
    int findMaxNumero(@Param("prefix") String prefix);
}

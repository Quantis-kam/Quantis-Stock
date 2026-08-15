package com.quantis.stock.repository;

import com.quantis.stock.model.Fournisseur;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface FournisseurRepository extends JpaRepository<Fournisseur, Long> {

    Page<Fournisseur> findByActifTrue(Pageable pageable);

    @Query("SELECT f FROM Fournisseur f WHERE f.actif = true AND " +
           "(LOWER(f.nom) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(f.telephone) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(f.email) LIKE LOWER(CONCAT('%', :q, '%')))")
    Page<Fournisseur> search(@Param("q") String query, Pageable pageable);
}

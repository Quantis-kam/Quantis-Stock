package com.quantis.stock.repository;

import com.quantis.stock.model.Fournisseur;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface FournisseurRepository extends JpaRepository<Fournisseur, Long> {

    Page<Fournisseur> findByActifTrue(Pageable pageable);
}

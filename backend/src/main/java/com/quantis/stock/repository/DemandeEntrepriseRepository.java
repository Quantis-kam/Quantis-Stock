package com.quantis.stock.repository;

import com.quantis.stock.model.DemandeEntreprise;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface DemandeEntrepriseRepository extends JpaRepository<DemandeEntreprise, Long> {
    List<DemandeEntreprise> findAllByOrderByCreatedAtDesc();
    long countByStatut(String statut);
}


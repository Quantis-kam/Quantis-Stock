package com.quantis.stock.repository;

import com.quantis.stock.model.Depot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DepotRepository extends JpaRepository<Depot, Long> {

    List<Depot> findByEstActifTrue();

    List<Depot> findByEntrepriseId(Long entrepriseId);

    List<Depot> findByEntrepriseIdAndEstActifTrue(Long entrepriseId);

    boolean existsByNom(String nom);
}

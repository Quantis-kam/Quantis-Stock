package com.quantis.stock.repository;

import com.quantis.stock.model.ArretStock;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ArretStockRepository extends JpaRepository<ArretStock, Long> {
    List<ArretStock> findByEntrepriseIdOrderByIdDesc(Long entrepriseId);
    List<ArretStock> findByDepotIdOrderByIdDesc(Long depotId);
}

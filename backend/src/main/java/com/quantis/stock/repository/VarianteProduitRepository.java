package com.quantis.stock.repository;

import com.quantis.stock.model.VarianteProduit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface VarianteProduitRepository extends JpaRepository<VarianteProduit, Long> {

    List<VarianteProduit> findByProduitId(Long produitId);

    Optional<VarianteProduit> findBySkuVariante(String skuVariante);

    boolean existsBySkuVariante(String skuVariante);
}

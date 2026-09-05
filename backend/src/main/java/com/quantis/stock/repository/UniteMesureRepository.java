package com.quantis.stock.repository;

import com.quantis.stock.model.UniteMesure;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface UniteMesureRepository extends JpaRepository<UniteMesure, Long> {

    boolean existsByAbreviation(String abreviation);

    java.util.Optional<UniteMesure> findByNomIgnoreCase(String nom);
    java.util.Optional<UniteMesure> findByAbreviationIgnoreCase(String abreviation);
}

package com.quantis.stock.repository;

import com.quantis.stock.model.MouvementCaisse;
import com.quantis.stock.model.enums.TypeCaisse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;

@Repository
public interface MouvementCaisseRepository extends JpaRepository<MouvementCaisse, Long> {

    Page<MouvementCaisse> findByDateMouvementBetweenOrderByDateMouvementDesc(
            LocalDate debut, LocalDate fin, Pageable pageable);

    Page<MouvementCaisse> findByTypeAndDateMouvementBetween(
            TypeCaisse type, LocalDate debut, LocalDate fin, Pageable pageable);

    @Query("SELECT COALESCE(SUM(m.montant), 0) FROM MouvementCaisse m " +
           "WHERE m.type = :type AND m.dateMouvement BETWEEN :debut AND :fin")
    BigDecimal sumByTypeAndPeriode(@Param("type") TypeCaisse type,
                                   @Param("debut") LocalDate debut,
                                   @Param("fin") LocalDate fin);

    @Query("SELECT COALESCE(SUM(m.montant), 0) FROM MouvementCaisse m WHERE m.type = :type")
    BigDecimal sumByType(@Param("type") TypeCaisse type);

    java.util.List<MouvementCaisse> findByDateMouvementBetweenOrderByDateMouvementAsc(LocalDate debut, LocalDate fin);

    @Query("SELECT COALESCE(SUM(m.montant), 0) FROM MouvementCaisse m " +
           "WHERE m.entreprise.id = :entrepriseId AND m.type = com.quantis.stock.model.enums.TypeCaisse.ENTREE")
    BigDecimal sumEntreesByEntrepriseId(@Param("entrepriseId") Long entrepriseId);

    @Query("SELECT COALESCE(SUM(m.montant), 0) FROM MouvementCaisse m " +
           "WHERE m.entreprise.id = :entrepriseId AND m.type = com.quantis.stock.model.enums.TypeCaisse.SORTIE")
    BigDecimal sumSortiesByEntrepriseId(@Param("entrepriseId") Long entrepriseId);
}

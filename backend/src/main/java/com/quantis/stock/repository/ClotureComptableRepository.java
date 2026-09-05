package com.quantis.stock.repository;

import com.quantis.stock.model.ClotureComptable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ClotureComptableRepository extends JpaRepository<ClotureComptable, Long> {

    @EntityGraph(attributePaths = {"cloturePar"})
    List<ClotureComptable> findAllByOrderByDateClotureDesc();

    @EntityGraph(attributePaths = {"cloturePar"})
    List<ClotureComptable> findByEntrepriseIdOrderByDateClotureDesc(Long entrepriseId);

    @EntityGraph(attributePaths = {"cloturePar"})
    Optional<ClotureComptable> findByPeriode(String periode);

    @EntityGraph(attributePaths = {"cloturePar"})
    Optional<ClotureComptable> findByEntrepriseIdAndPeriode(Long entrepriseId, String periode);

    boolean existsByPeriode(String periode);

    boolean existsByEntrepriseIdAndPeriode(Long entrepriseId, String periode);
}

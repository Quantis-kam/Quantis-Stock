package com.quantis.stock.repository;

import com.quantis.stock.model.SessionCaisse;
import com.quantis.stock.model.enums.StatutSessionCaisse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SessionCaisseRepository extends JpaRepository<SessionCaisse, Long> {

    Optional<SessionCaisse> findByCaissierIdAndStatut(Long caissierId, StatutSessionCaisse statut);

    Page<SessionCaisse> findByCaissierId(Long caissierId, Pageable pageable);

    Page<SessionCaisse> findByDepotId(Long depotId, Pageable pageable);

    Page<SessionCaisse> findByEntrepriseId(Long entrepriseId, Pageable pageable);

    java.util.List<SessionCaisse> findByEntrepriseIdAndStatut(Long entrepriseId, StatutSessionCaisse statut);
}

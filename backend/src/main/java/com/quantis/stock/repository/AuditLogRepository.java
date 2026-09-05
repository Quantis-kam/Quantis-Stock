package com.quantis.stock.repository;

import com.quantis.stock.model.AuditLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import org.springframework.data.jpa.repository.EntityGraph;

@Repository
public interface AuditLogRepository extends JpaRepository<AuditLog, Long> {

    @EntityGraph(attributePaths = {"utilisateur"})
    Page<AuditLog> findByEntiteAndEntiteId(String entite, Long entiteId, Pageable pageable);

    @EntityGraph(attributePaths = {"utilisateur"})
    Page<AuditLog> findByUtilisateurId(Long utilisateurId, Pageable pageable);

    @EntityGraph(attributePaths = {"utilisateur"})
    Page<AuditLog> findAllByOrderByCreatedAtDesc(Pageable pageable);

    @EntityGraph(attributePaths = {"utilisateur", "utilisateur.depot"})
    Page<AuditLog> findByUtilisateurDepotIdOrderByCreatedAtDesc(Long depotId, Pageable pageable);
}

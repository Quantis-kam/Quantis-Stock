package com.quantis.stock.repository;

import com.quantis.stock.model.AuditLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AuditLogRepository extends JpaRepository<AuditLog, Long> {

    Page<AuditLog> findByEntiteAndEntiteId(String entite, Long entiteId, Pageable pageable);

    Page<AuditLog> findByUtilisateurId(Long utilisateurId, Pageable pageable);

    Page<AuditLog> findAllByOrderByCreatedAtDesc(Pageable pageable);
}

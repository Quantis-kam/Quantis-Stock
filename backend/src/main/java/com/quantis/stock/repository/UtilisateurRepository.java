package com.quantis.stock.repository;

import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.model.enums.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;

@Repository
public interface UtilisateurRepository extends JpaRepository<Utilisateur, Long> {

    @Override
    @EntityGraph(attributePaths = {"depot"})
    Optional<Utilisateur> findById(Long id);

    @Override
    @EntityGraph(attributePaths = {"depot"})
    Page<Utilisateur> findAll(Pageable pageable);

    @EntityGraph(attributePaths = {"depot"})
    Optional<Utilisateur> findByEmail(String email);

    boolean existsByEmail(String email);

    @EntityGraph(attributePaths = {"depot"})
    List<Utilisateur> findByActifTrue();

    @EntityGraph(attributePaths = {"depot"})
    List<Utilisateur> findByRole(Role role);

    @EntityGraph(attributePaths = {"depot", "entreprise"})
    List<Utilisateur> findByDepotId(Long depotId);

    @EntityGraph(attributePaths = {"depot", "entreprise"})
    Page<Utilisateur> findByDepotId(Long depotId, Pageable pageable);

    @EntityGraph(attributePaths = {"depot", "entreprise"})
    Page<Utilisateur> findByDepotIdAndRoleNot(Long depotId, Role role, Pageable pageable);

    @EntityGraph(attributePaths = {"depot", "entreprise"})
    Page<Utilisateur> findByEntrepriseId(Long entrepriseId, Pageable pageable);

    @EntityGraph(attributePaths = {"depot", "entreprise"})
    Page<Utilisateur> findByEntrepriseIdAndRoleNot(Long entrepriseId, Role role, Pageable pageable);

    @EntityGraph(attributePaths = {"depot", "entreprise"})
    List<Utilisateur> findByEntrepriseId(Long entrepriseId);

    long countByEntrepriseId(Long entrepriseId);

    Optional<Utilisateur> findFirstByEntrepriseIdAndRole(Long entrepriseId, Role role);
}

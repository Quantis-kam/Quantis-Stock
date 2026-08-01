package com.quantis.stock.repository;

import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.model.enums.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UtilisateurRepository extends JpaRepository<Utilisateur, Long> {

    Optional<Utilisateur> findByEmail(String email);

    boolean existsByEmail(String email);

    List<Utilisateur> findByActifTrue();

    List<Utilisateur> findByRole(Role role);

    List<Utilisateur> findByDepotId(Long depotId);
}

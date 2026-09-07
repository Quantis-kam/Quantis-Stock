package com.quantis.stock.repository;

import com.quantis.stock.model.Categorie;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

import org.springframework.data.jpa.repository.EntityGraph;
import java.util.Optional;

@Repository
public interface CategorieRepository extends JpaRepository<Categorie, Long> {

    @Override
    @EntityGraph(attributePaths = {"parent", "sousCategories"})
    List<Categorie> findAll();

    @Override
    @EntityGraph(attributePaths = {"parent", "sousCategories"})
    Optional<Categorie> findById(Long id);

    @EntityGraph(attributePaths = {"parent", "sousCategories"})
    List<Categorie> findByParentIsNull();

    @EntityGraph(attributePaths = {"parent", "sousCategories"})
    List<Categorie> findByParentId(Long parentId);

    @EntityGraph(attributePaths = {"parent", "sousCategories"})
    List<Categorie> findByEntrepriseIdOrEntrepriseIsNull(Long entrepriseId);

    @EntityGraph(attributePaths = {"parent", "sousCategories"})
    List<Categorie> findByEntrepriseId(Long entrepriseId);

    @EntityGraph(attributePaths = {"parent", "sousCategories"})
    List<Categorie> findByEntrepriseIdAndParentIsNull(Long entrepriseId);

    boolean existsByNom(String nom);

    boolean existsByEntrepriseIdAndNom(Long entrepriseId, String nom);

    Optional<Categorie> findByNom(String nom);

    Optional<Categorie> findByNomIgnoreCase(String nom);

    Optional<Categorie> findByEntrepriseIdAndNom(Long entrepriseId, String nom);
}

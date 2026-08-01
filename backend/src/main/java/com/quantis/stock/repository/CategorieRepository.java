package com.quantis.stock.repository;

import com.quantis.stock.model.Categorie;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CategorieRepository extends JpaRepository<Categorie, Long> {

    List<Categorie> findByParentIsNull();

    List<Categorie> findByParentId(Long parentId);

    boolean existsByNom(String nom);
}

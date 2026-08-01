package com.quantis.stock.repository;

import com.quantis.stock.model.Client;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface ClientRepository extends JpaRepository<Client, Long> {

    Page<Client> findByActifTrue(Pageable pageable);

    @Query("SELECT c FROM Client c WHERE c.actif = true AND " +
           "(LOWER(c.nom) LIKE LOWER(CONCAT('%', :q, '%')) OR c.telephone LIKE CONCAT('%', :q, '%'))")
    Page<Client> search(@Param("q") String query, Pageable pageable);
}

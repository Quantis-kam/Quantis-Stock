package com.quantis.stock.model;

import jakarta.persistence.*;
import lombok.*;

/**
 * Unité de mesure (Kilogramme, Litre, Pièce, etc.).
 */
@Entity
@Table(name = "unite_mesure")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UniteMesure {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50)
    private String nom;

    @Column(nullable = false, length = 10)
    private String abreviation;
}

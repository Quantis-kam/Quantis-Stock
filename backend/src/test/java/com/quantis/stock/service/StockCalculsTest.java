package com.quantis.stock.service;

import com.quantis.stock.model.CommandeFournisseur;
import com.quantis.stock.model.LigneCommandeFournisseur;
import com.quantis.stock.model.enums.StatutCommande;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests unitaires sur les calculs de stock et commandes.
 */
class StockCalculsTest {

    @Nested
    @DisplayName("Commande Fournisseur — Totaux")
    class CommandeTotauxTests {

        @Test
        @DisplayName("Total HT avec 2 lignes")
        void testTotalHt() {
            CommandeFournisseur cmd = new CommandeFournisseur();

            LigneCommandeFournisseur l1 = LigneCommandeFournisseur.builder()
                    .quantiteCommandee(new BigDecimal("10"))
                    .prixUnitaire(new BigDecimal("500"))
                    .build();

            LigneCommandeFournisseur l2 = LigneCommandeFournisseur.builder()
                    .quantiteCommandee(new BigDecimal("5"))
                    .prixUnitaire(new BigDecimal("2000"))
                    .build();

            cmd.getLignes().add(l1);
            cmd.getLignes().add(l2);
            cmd.recalculerTotal();

            // 10×500 + 5×2000 = 5000 + 10000 = 15000
            assertEquals(0, new BigDecimal("15000").compareTo(cmd.getTotalHt()));
        }
    }

    @Nested
    @DisplayName("Réception — Quantités")
    class ReceptionTests {

        @Test
        @DisplayName("Quantité restante après réception partielle")
        void testQuantiteRestante() {
            LigneCommandeFournisseur ligne = LigneCommandeFournisseur.builder()
                    .quantiteCommandee(new BigDecimal("100"))
                    .quantiteRecue(new BigDecimal("40"))
                    .prixUnitaire(new BigDecimal("500"))
                    .build();

            assertEquals(0, new BigDecimal("60").compareTo(ligne.getQuantiteRestante()));
            assertFalse(ligne.getQuantiteRecue().compareTo(ligne.getQuantiteCommandee()) >= 0);
        }

        @Test
        @DisplayName("Ligne complètement reçue")
        void testLigneComplete() {
            LigneCommandeFournisseur ligne = LigneCommandeFournisseur.builder()
                    .quantiteCommandee(new BigDecimal("50"))
                    .quantiteRecue(new BigDecimal("50"))
                    .prixUnitaire(new BigDecimal("1000"))
                    .build();

            assertEquals(0, BigDecimal.ZERO.compareTo(ligne.getQuantiteRestante()));
            assertTrue(ligne.getQuantiteRecue().compareTo(ligne.getQuantiteCommandee()) >= 0);
        }

        @Test
        @DisplayName("Commande entièrement reçue")
        void testCommandeEntierementRecue() {
            CommandeFournisseur cmd = new CommandeFournisseur();
            cmd.setStatut(StatutCommande.EN_COURS);

            cmd.getLignes().add(LigneCommandeFournisseur.builder()
                    .quantiteCommandee(new BigDecimal("10"))
                    .quantiteRecue(new BigDecimal("10"))
                    .prixUnitaire(BigDecimal.ONE)
                    .build());

            cmd.getLignes().add(LigneCommandeFournisseur.builder()
                    .quantiteCommandee(new BigDecimal("20"))
                    .quantiteRecue(new BigDecimal("20"))
                    .prixUnitaire(BigDecimal.ONE)
                    .build());

            assertTrue(cmd.isEntierementRecue());
        }

        @Test
        @DisplayName("Commande partiellement reçue")
        void testCommandePartiellementRecue() {
            CommandeFournisseur cmd = new CommandeFournisseur();

            cmd.getLignes().add(LigneCommandeFournisseur.builder()
                    .quantiteCommandee(new BigDecimal("10"))
                    .quantiteRecue(new BigDecimal("10"))
                    .prixUnitaire(BigDecimal.ONE)
                    .build());

            cmd.getLignes().add(LigneCommandeFournisseur.builder()
                    .quantiteCommandee(new BigDecimal("20"))
                    .quantiteRecue(new BigDecimal("5"))
                    .prixUnitaire(BigDecimal.ONE)
                    .build());

            assertFalse(cmd.isEntierementRecue());
            assertTrue(cmd.isPartiellementRecue());
        }
    }

    @Nested
    @DisplayName("Numérotation")
    class NumerotationTests {

        @Test
        @DisplayName("Format numéro commande")
        void testFormatNumero() {
            String prefix = "CMD-2026-";
            String numero = prefix + String.format("%05d", 42);
            assertEquals("CMD-2026-00042", numero);
        }
    }
}

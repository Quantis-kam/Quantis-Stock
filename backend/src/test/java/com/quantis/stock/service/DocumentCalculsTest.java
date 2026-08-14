package com.quantis.stock.service;

import com.quantis.stock.model.Document;
import com.quantis.stock.model.LigneDocument;
import com.quantis.stock.model.enums.StatutDocument;
import com.quantis.stock.model.enums.TypeDocument;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests unitaires sur les calculs métier des documents (TVA, totaux).
 */
class DocumentCalculsTest {

    @Nested
    @DisplayName("Calcul TVA 18%")
    class TvaTests {

        @Test
        @DisplayName("Ligne simple: 1000 × 5 = 5000 HT, 900 TVA, 5900 TTC")
        void testCalculLigneSimple() {
            LigneDocument ligne = new LigneDocument();
            ligne.setDesignation("Produit Test");
            ligne.setQuantite(new BigDecimal("5"));
            ligne.setPrixUnitaire(new BigDecimal("1000"));
            ligne.setTauxTva(new BigDecimal("18"));
            ligne.calculerMontants();

            assertEquals(new BigDecimal("5000.00"), ligne.getMontantHt());
            assertEquals(new BigDecimal("900.00"), ligne.getMontantTva());
            assertEquals(new BigDecimal("5900.00"), ligne.getMontantTtc());
        }

        @Test
        @DisplayName("Quantité décimale: 2.5 × 400 = 1000 HT")
        void testQuantiteDecimale() {
            LigneDocument ligne = new LigneDocument();
            ligne.setQuantite(new BigDecimal("2.5"));
            ligne.setPrixUnitaire(new BigDecimal("400"));
            ligne.setTauxTva(new BigDecimal("18"));
            ligne.calculerMontants();

            assertEquals(0, new BigDecimal("1000.00").compareTo(ligne.getMontantHt()));
            assertEquals(0, new BigDecimal("180.00").compareTo(ligne.getMontantTva()));
        }

        @Test
        @DisplayName("TVA 0% — exonéré")
        void testTvaZero() {
            LigneDocument ligne = new LigneDocument();
            ligne.setQuantite(new BigDecimal("10"));
            ligne.setPrixUnitaire(new BigDecimal("500"));
            ligne.setTauxTva(BigDecimal.ZERO);
            ligne.calculerMontants();

            assertEquals(0, new BigDecimal("5000.00").compareTo(ligne.getMontantHt()));
            assertEquals(0, BigDecimal.ZERO.compareTo(ligne.getMontantTva()));
            assertEquals(0, new BigDecimal("5000.00").compareTo(ligne.getMontantTtc()));
        }
    }

    @Nested
    @DisplayName("Totaux Document")
    class TotauxDocumentTests {

        @Test
        @DisplayName("Document avec 2 lignes — totaux corrects")
        void testTotauxDocument() {
            Document doc = new Document();
            doc.setType(TypeDocument.FACTURE);
            doc.setStatut(StatutDocument.BROUILLON);

            LigneDocument l1 = new LigneDocument();
            l1.setDesignation("Produit A");
            l1.setQuantite(new BigDecimal("3"));
            l1.setPrixUnitaire(new BigDecimal("1000"));
            l1.setTauxTva(new BigDecimal("18"));
            l1.calculerMontants();
            l1.setDocument(doc);

            LigneDocument l2 = new LigneDocument();
            l2.setDesignation("Produit B");
            l2.setQuantite(new BigDecimal("2"));
            l2.setPrixUnitaire(new BigDecimal("2500"));
            l2.setTauxTva(new BigDecimal("18"));
            l2.calculerMontants();
            l2.setDocument(doc);

            doc.getLignes().add(l1);
            doc.getLignes().add(l2);
            doc.recalculerTotaux();

            // L1: 3000 HT + 540 TVA = 3540 TTC
            // L2: 5000 HT + 900 TVA = 5900 TTC
            // Total: 8000 HT + 1440 TVA = 9440 TTC
            assertEquals(0, new BigDecimal("8000.00").compareTo(doc.getTotalHt()));
            assertEquals(0, new BigDecimal("1440.00").compareTo(doc.getTotalTva()));
            assertEquals(0, new BigDecimal("9440.00").compareTo(doc.getTotalTtc()));
        }

        @Test
        @DisplayName("Document vide — totaux à zéro")
        void testDocumentVide() {
            Document doc = new Document();
            doc.recalculerTotaux();

            assertEquals(0, BigDecimal.ZERO.compareTo(doc.getTotalHt()));
            assertEquals(0, BigDecimal.ZERO.compareTo(doc.getTotalTva()));
            assertEquals(0, BigDecimal.ZERO.compareTo(doc.getTotalTtc()));
        }
    }
}

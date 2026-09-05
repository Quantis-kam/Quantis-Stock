package com.quantis.stock.service;

import com.quantis.stock.model.Client;
import com.quantis.stock.model.Document;
import com.quantis.stock.model.MouvementCaisse;
import com.quantis.stock.model.StockCourant;
import com.quantis.stock.repository.ClientRepository;
import com.quantis.stock.repository.DocumentRepository;
import com.quantis.stock.repository.MouvementCaisseRepository;
import com.quantis.stock.repository.StockCourantRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ExportService {

    private final DocumentRepository documentRepository;
    private final MouvementCaisseRepository mouvementCaisseRepository;
    private final ClientRepository clientRepository;
    private final StockCourantRepository stockCourantRepository;

    private static final String UTF8_BOM = "\uFEFF";
    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    /**
     * Export du Journal des Ventes & Factures
     */
    public byte[] exportVentesCsv(LocalDate debut, LocalDate fin) {
        StringBuilder sb = new StringBuilder();
        sb.append(UTF8_BOM);
        sb.append("Date;Numéro;Type;Client;Statut;Total HT;Total TVA;Total TTC;Montant Payé;Solde Restant;Notes\n");

        List<Document> docs = documentRepository.findAll();
        for (Document d : docs) {
            if (debut != null && d.getDateDocument().isBefore(debut)) continue;
            if (fin != null && d.getDateDocument().isAfter(fin)) continue;

            String clientNom = d.getClient() != null ? d.getClient().getNom().replace(";", " ") : "Client Divers";
            String notes = d.getNotes() != null ? d.getNotes().replace(";", " ").replace("\n", " ") : "";

            sb.append(d.getDateDocument().format(DATE_FMT)).append(";")
                    .append(d.getNumero()).append(";")
                    .append(d.getType()).append(";")
                    .append(clientNom).append(";")
                    .append(d.getStatut()).append(";")
                    .append(d.getTotalHt() != null ? d.getTotalHt().toString() : "0").append(";")
                    .append(d.getTotalTva() != null ? d.getTotalTva().toString() : "0").append(";")
                    .append(d.getTotalTtc() != null ? d.getTotalTtc().toString() : "0").append(";")
                    .append(d.getMontantPaye() != null ? d.getMontantPaye().toString() : "0").append(";")
                    .append(d.getSoldeRestant() != null ? d.getSoldeRestant().toString() : "0").append(";")
                    .append(notes).append("\n");
        }

        return sb.toString().getBytes(StandardCharsets.UTF_8);
    }

    /**
     * Export du Journal de Caisse & Règlements
     */
    public byte[] exportCaisseCsv(LocalDate debut, LocalDate fin) {
        StringBuilder sb = new StringBuilder();
        sb.append(UTF8_BOM);
        sb.append("Date;Type Mouvement;Libellé;Montant (FCFA);Catégorie;Référence;Document lié;Utilisateur\n");

        List<MouvementCaisse> mvts = mouvementCaisseRepository.findAll();
        for (MouvementCaisse m : mvts) {
            LocalDate mDate = m.getDateMouvement() != null ? m.getDateMouvement() : LocalDate.now();
            if (debut != null && mDate.isBefore(debut)) continue;
            if (fin != null && mDate.isAfter(fin)) continue;

            String user = m.getUtilisateur() != null ? m.getUtilisateur().getNom() : "—";
            String doc = m.getDocument() != null ? m.getDocument().getNumero() : "—";
            String libelle = m.getLibelle() != null ? m.getLibelle().replace(";", " ") : "";
            String cat = m.getCategorie() != null ? m.getCategorie() : "—";
            String ref = m.getReference() != null ? m.getReference() : "—";

            sb.append(mDate.format(DATE_FMT)).append(";")
                    .append(m.getType()).append(";")
                    .append(libelle).append(";")
                    .append(m.getMontant() != null ? m.getMontant().toString() : "0").append(";")
                    .append(cat).append(";")
                    .append(ref).append(";")
                    .append(doc).append(";")
                    .append(user).append("\n");
        }

        return sb.toString().getBytes(StandardCharsets.UTF_8);
    }

    /**
     * Export du Grand Livre des Tiers Débiteurs
     */
    public byte[] exportDebiteursCsv() {
        StringBuilder sb = new StringBuilder();
        sb.append(UTF8_BOM);
        sb.append("Client;Téléphone;Email;Adresse;Solde Dû (FCFA);Statut\n");

        List<Client> clients = clientRepository.findAll();
        for (Client c : clients) {
            BigDecimal solde = c.getSoldeCredit() != null ? c.getSoldeCredit() : BigDecimal.ZERO;
            if (solde.compareTo(BigDecimal.ZERO) <= 0) continue; // Seulement les débiteurs

            sb.append(c.getNom().replace(";", " ")).append(";")
                    .append(c.getTelephone() != null ? c.getTelephone() : "—").append(";")
                    .append(c.getEmail() != null ? c.getEmail() : "—").append(";")
                    .append(c.getAdresse() != null ? c.getAdresse().replace(";", " ") : "—").append(";")
                    .append(solde.toString()).append(";")
                    .append(Boolean.TRUE.equals(c.getActif()) ? "ACTIF" : "INACTIF").append("\n");
        }

        return sb.toString().getBytes(StandardCharsets.UTF_8);
    }

    /**
     * Export de la Valorisation de l'État de Stock
     */
    public byte[] exportStockCsv() {
        StringBuilder sb = new StringBuilder();
        sb.append(UTF8_BOM);
        sb.append("Code SKU;Désignation Article;Catégorie;Dépôt;Quantité en Stock;Prix Achat Unitaire;Valeur Totale (FCFA);Seuil Alerte\n");

        List<StockCourant> stocks = stockCourantRepository.findAll();
        for (StockCourant sc : stocks) {
            String sku = sc.getProduit() != null ? sc.getProduit().getSku() : "—";
            String nom = sc.getProduit() != null ? sc.getProduit().getNom().replace(";", " ") : "—";
            String cat = sc.getProduit() != null && sc.getProduit().getCategorie() != null ? sc.getProduit().getCategorie().getNom() : "Général";
            String depot = sc.getDepot() != null ? sc.getDepot().getNom() : "Dépôt Principal";
            BigDecimal qte = sc.getQuantite() != null ? sc.getQuantite() : BigDecimal.ZERO;
            BigDecimal prixAchat = sc.getProduit() != null && sc.getProduit().getPrixAchat() != null ? sc.getProduit().getPrixAchat() : BigDecimal.ZERO;
            BigDecimal valeurTotale = qte.multiply(prixAchat);
            int seuil = sc.getProduit() != null && sc.getProduit().getSeuilAlerte() != null ? sc.getProduit().getSeuilAlerte() : 5;

            sb.append(sku).append(";")
                    .append(nom).append(";")
                    .append(cat).append(";")
                    .append(depot).append(";")
                    .append(qte.toString()).append(";")
                    .append(prixAchat.toString()).append(";")
                    .append(valeurTotale.toString()).append(";")
                    .append(seuil).append("\n");
        }

        return sb.toString().getBytes(StandardCharsets.UTF_8);
    }
}

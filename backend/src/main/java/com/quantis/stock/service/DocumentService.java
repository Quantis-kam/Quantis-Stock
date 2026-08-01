package com.quantis.stock.service;

import com.quantis.stock.dto.DocumentRequest;
import com.quantis.stock.dto.PaiementRequest;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.*;
import com.quantis.stock.model.enums.StatutDocument;
import com.quantis.stock.model.enums.TypeDocument;
import com.quantis.stock.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.Year;
import java.util.List;

/**
 * Service de gestion documentaire — Devis, BL, Factures, Avoirs + Paiements.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DocumentService {

    private final DocumentRepository documentRepository;
    private final PaiementRepository paiementRepository;
    private final ClientRepository clientRepository;
    private final DepotRepository depotRepository;
    private final ProduitRepository produitRepository;
    private final VarianteProduitRepository varianteProduitRepository;
    private final UtilisateurRepository utilisateurRepository;

    // =================== DOCUMENTS ===================

    @Transactional
    public Document creerDocument(DocumentRequest request, String userEmail) {
        Client client = clientRepository.findById(request.getClientId())
                .orElseThrow(() -> new ResourceNotFoundException("Client", "id", request.getClientId()));

        Utilisateur utilisateur = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        Depot depot = null;
        if (request.getDepotId() != null) {
            depot = depotRepository.findById(request.getDepotId())
                    .orElseThrow(() -> new ResourceNotFoundException("Dépôt", "id", request.getDepotId()));
        }

        // Générer le numéro
        String numero = genererNumero(request.getType());

        Document document = Document.builder()
                .type(request.getType())
                .numero(numero)
                .client(client)
                .depot(depot)
                .dateDocument(request.getDateDocument() != null ? request.getDateDocument() : LocalDate.now())
                .dateEcheance(request.getDateEcheance())
                .notes(request.getNotes())
                .utilisateur(utilisateur)
                .build();

        // Document parent (conversion)
        if (request.getDocumentParentId() != null) {
            Document parent = documentRepository.findById(request.getDocumentParentId())
                    .orElseThrow(() -> new ResourceNotFoundException("Document parent", "id", request.getDocumentParentId()));
            document.setDocumentParent(parent);
        }

        // Lignes
        for (DocumentRequest.LigneRequest lr : request.getLignes()) {
            Produit produit = produitRepository.findById(lr.getProduitId())
                    .orElseThrow(() -> new ResourceNotFoundException("Produit", "id", lr.getProduitId()));

            VarianteProduit variante = null;
            if (lr.getVarianteId() != null) {
                variante = varianteProduitRepository.findById(lr.getVarianteId())
                        .orElseThrow(() -> new ResourceNotFoundException("Variante", "id", lr.getVarianteId()));
            }

            LigneDocument ligne = LigneDocument.builder()
                    .document(document)
                    .produit(produit)
                    .variante(variante)
                    .designation(lr.getDesignation() != null ? lr.getDesignation() : produit.getNom())
                    .quantite(lr.getQuantite())
                    .prixUnitaire(lr.getPrixUnitaire())
                    .tauxTva(lr.getTauxTva() != null ? lr.getTauxTva() : produit.getTauxTva())
                    .build();

            ligne.calculerMontants();
            document.getLignes().add(ligne);
        }

        document.recalculerTotaux();
        document = documentRepository.save(document);

        log.info("Document créé: {} {} — {} FCFA TTC", document.getType(), document.getNumero(), document.getTotalTtc());
        return document;
    }

    @Transactional
    public Document validerDocument(Long id) {
        Document document = findById(id);

        if (document.getStatut() != StatutDocument.BROUILLON) {
            throw new BusinessException("Seul un brouillon peut être validé");
        }

        document.setStatut(StatutDocument.VALIDE);
        document = documentRepository.save(document);
        log.info("Document validé: {} {}", document.getType(), document.getNumero());
        return document;
    }

    @Transactional
    public Document annulerDocument(Long id) {
        Document document = findById(id);

        if (document.getStatut() == StatutDocument.ANNULE) {
            throw new BusinessException("Document déjà annulé");
        }

        document.setStatut(StatutDocument.ANNULE);
        document = documentRepository.save(document);
        log.info("Document annulé: {} {}", document.getType(), document.getNumero());
        return document;
    }

    @Transactional(readOnly = true)
    public Document findById(Long id) {
        return documentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Document", "id", id));
    }

    @Transactional(readOnly = true)
    public Document findByNumero(String numero) {
        return documentRepository.findByNumero(numero)
                .orElseThrow(() -> new ResourceNotFoundException("Document", "numero", numero));
    }

    @Transactional(readOnly = true)
    public Page<Document> findByType(TypeDocument type, Pageable pageable) {
        return documentRepository.findByType(type, pageable);
    }

    @Transactional(readOnly = true)
    public Page<Document> findByClient(Long clientId, Pageable pageable) {
        return documentRepository.findByClientId(clientId, pageable);
    }

    // =================== PAIEMENTS ===================

    @Transactional
    public Paiement enregistrerPaiement(PaiementRequest request, String userEmail) {
        // Idempotence
        if (request.getUuidSync() != null && paiementRepository.existsByUuidSync(request.getUuidSync())) {
            return paiementRepository.findByUuidSync(request.getUuidSync()).orElseThrow();
        }

        Document document = findById(request.getDocumentId());

        if (document.getStatut() != StatutDocument.VALIDE) {
            throw new BusinessException("Les paiements ne sont acceptés que sur les documents validés");
        }

        BigDecimal soldeRestant = document.getSoldeRestant();
        if (request.getMontant().compareTo(soldeRestant) > 0) {
            throw new BusinessException(String.format(
                    "Montant (%s FCFA) supérieur au solde restant (%s FCFA)", request.getMontant(), soldeRestant));
        }

        Utilisateur utilisateur = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        Paiement paiement = Paiement.builder()
                .document(document)
                .montant(request.getMontant())
                .moyen(request.getMoyen())
                .datePaiement(request.getDatePaiement() != null ? request.getDatePaiement() : LocalDate.now())
                .reference(request.getReference())
                .utilisateur(utilisateur)
                .build();

        if (request.getUuidSync() != null) {
            paiement.setUuidSync(request.getUuidSync());
        }

        paiement = paiementRepository.save(paiement);
        log.info("Paiement enregistré: {} FCFA ({}) pour {}", 
                request.getMontant(), request.getMoyen(), document.getNumero());

        return paiement;
    }

    @Transactional(readOnly = true)
    public List<Paiement> getPaiementsParDocument(Long documentId) {
        return paiementRepository.findByDocumentId(documentId);
    }

    // =================== NUMÉROTATION ===================

    private String genererNumero(TypeDocument type) {
        String prefix = switch (type) {
            case DEVIS -> "DEV-";
            case BON_LIVRAISON -> "BL-";
            case FACTURE -> "FAC-";
            case AVOIR -> "AV-";
        };
        String annee = String.valueOf(Year.now().getValue()) + "-";
        String fullPrefix = prefix + annee;
        int maxNum = documentRepository.findMaxNumero(fullPrefix);
        return fullPrefix + String.format("%05d", maxNum + 1);
    }
}

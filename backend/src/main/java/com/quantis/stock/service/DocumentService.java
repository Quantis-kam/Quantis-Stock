package com.quantis.stock.service;

import com.quantis.stock.dto.DocumentRequest;
import com.quantis.stock.dto.MouvementRequest;
import com.quantis.stock.dto.PaiementRequest;
import com.quantis.stock.dto.PosSaleRequest;
import com.quantis.stock.dto.PosSaleResponse;
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
    private final StockService stockService;
    private final ComptabiliteService comptabiliteService;
    private final AuditService auditService;
    private final EntrepriseRepository entrepriseRepository;
    private final com.quantis.stock.security.SecurityUtils securityUtils;

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

        Entreprise entreprise = utilisateur.getEntreprise() != null
                ? utilisateur.getEntreprise()
                : (depot != null ? depot.getEntreprise() : securityUtils.getCurrentEntreprise().orElse(null));

        Document document = Document.builder()
                .entreprise(entreprise)
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
        auditService.logAction("CREATE", "Document", document.getId(), "Création " + document.getType() + " " + document.getNumero());
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
        auditService.logAction("VALIDATE", "Document", document.getId(), "Validation " + document.getType() + " " + document.getNumero());

        Client client = document.getClient();
        if (client != null) {
            if (document.getType() == TypeDocument.FACTURE) {
                client.setSoldeCredit(client.getSoldeCredit().add(document.getTotalTtc()));
                clientRepository.save(client);
            } else if (document.getType() == TypeDocument.AVOIR) {
                client.setSoldeCredit(client.getSoldeCredit().subtract(document.getTotalTtc()));
                clientRepository.save(client);
            }
        }

        return document;
    }

    @Transactional
    public Document annulerDocument(Long id) {
        Document document = findById(id);

        if (document.getStatut() == StatutDocument.ANNULE) {
            throw new BusinessException("Document déjà annulé");
        }

        StatutDocument ancienStatut = document.getStatut();
        document.setStatut(StatutDocument.ANNULE);
        document = documentRepository.save(document);
        log.info("Document annulé: {} {}", document.getType(), document.getNumero());
        auditService.logAction("CANCEL", "Document", document.getId(), "Annulation " + document.getType() + " " + document.getNumero());

        if (ancienStatut == StatutDocument.VALIDE) {
            Client client = document.getClient();
            if (client != null) {
                if (document.getType() == TypeDocument.FACTURE) {
                    client.setSoldeCredit(client.getSoldeCredit().subtract(document.getTotalTtc()));
                    clientRepository.save(client);
                } else if (document.getType() == TypeDocument.AVOIR) {
                    client.setSoldeCredit(client.getSoldeCredit().add(document.getTotalTtc()));
                    clientRepository.save(client);
                }
            }
        }

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
        if (securityUtils.isSuperAdmin()) {
            return documentRepository.findByType(type, pageable);
        }
        Long entId = securityUtils.getCurrentEntrepriseId();
        if (entId != null) {
            return documentRepository.findByEntrepriseIdAndType(entId, type, pageable);
        }
        return documentRepository.findByType(type, pageable);
    }

    @Transactional(readOnly = true)
    public Page<Document> findByClient(Long clientId, Pageable pageable) {
        if (securityUtils.isSuperAdmin()) {
            return documentRepository.findByClientId(clientId, pageable);
        }
        Long entId = securityUtils.getCurrentEntrepriseId();
        if (entId != null) {
            return documentRepository.findByEntrepriseIdAndClientId(entId, clientId, pageable);
        }
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
        auditService.logAction("PAYMENT", "Paiement", paiement.getId(), "Enregistrement paiement de " + request.getMontant() + " FCFA pour " + document.getNumero());

        Client client = document.getClient();
        if (client != null) {
            client.setSoldeCredit(client.getSoldeCredit().subtract(request.getMontant()));
            clientRepository.save(client);
        }

        // Enregistrer automatiquement l'écriture de caisse
        try {
            com.quantis.stock.model.MouvementCaisse mouvementCaisse = com.quantis.stock.model.MouvementCaisse.builder()
                    .type(com.quantis.stock.model.enums.TypeCaisse.ENTREE)
                    .montant(request.getMontant())
                    .libelle("Paiement " + document.getNumero() + " (" + request.getMoyen() + ")")
                    .dateMouvement(request.getDatePaiement() != null ? request.getDatePaiement() : LocalDate.now())
                    .categorie("VENTE")
                    .reference(document.getNumero())
                    .document(document)
                    .utilisateur(utilisateur)
                    .build();
            comptabiliteService.enregistrerMouvement(mouvementCaisse, userEmail);
        } catch (Exception e) {
            log.warn("Impossible d'imputer le mouvement de caisse pour le paiement {}: {}", paiement.getId(), e.getMessage());
        }

        return paiement;
    }

    @Transactional(readOnly = true)
    public List<Paiement> getPaiementsParDocument(Long documentId) {
        return paiementRepository.findByDocumentId(documentId);
    }

    // =================== CONVERSION ===================

    /**
     * Convertir un document validé vers le type suivant du cycle :
     * DEVIS → BON_LIVRAISON → FACTURE → AVOIR.
     */
    @Transactional
    public Document convertirDocument(Long sourceId, TypeDocument targetType, String userEmail) {
        Document source = findById(sourceId);

        if (source.getStatut() != StatutDocument.VALIDE) {
            throw new BusinessException("Seul un document validé peut être converti");
        }

        // Vérifier la séquence de conversion
        validateConversion(source.getType(), targetType);

        Utilisateur utilisateur = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        String numero = genererNumero(targetType);

        Document cible = Document.builder()
                .entreprise(source.getEntreprise() != null ? source.getEntreprise() : utilisateur.getEntreprise())
                .type(targetType)
                .numero(numero)
                .client(source.getClient())
                .depot(source.getDepot())
                .dateDocument(LocalDate.now())
                .dateEcheance(source.getDateEcheance())
                .notes("Converti depuis " + source.getNumero())
                .utilisateur(utilisateur)
                .documentParent(source)
                .build();

        // Copier les lignes
        for (LigneDocument sourceLigne : source.getLignes()) {
            LigneDocument nouvelleLigne = LigneDocument.builder()
                    .document(cible)
                    .produit(sourceLigne.getProduit())
                    .variante(sourceLigne.getVariante())
                    .designation(sourceLigne.getDesignation())
                    .quantite(sourceLigne.getQuantite())
                    .prixUnitaire(sourceLigne.getPrixUnitaire())
                    .tauxTva(sourceLigne.getTauxTva())
                    .build();
            nouvelleLigne.calculerMontants();
            cible.getLignes().add(nouvelleLigne);
        }

        cible.recalculerTotaux();
        cible = documentRepository.save(cible);

        log.info("Document converti: {} {} → {} {}", source.getType(), source.getNumero(),
                targetType, cible.getNumero());
        auditService.logAction("CONVERT", "Document", cible.getId(),
                "Conversion " + source.getNumero() + " → " + cible.getNumero() + " (" + targetType + ")");

        return cible;
    }

    private void validateConversion(TypeDocument sourceType, TypeDocument targetType) {
        boolean valid = switch (sourceType) {
            case DEVIS -> targetType == TypeDocument.COMMANDE_CLIENT || targetType == TypeDocument.BON_LIVRAISON || targetType == TypeDocument.FACTURE;
            case COMMANDE_CLIENT -> targetType == TypeDocument.BON_LIVRAISON || targetType == TypeDocument.FACTURE;
            case BON_LIVRAISON -> targetType == TypeDocument.FACTURE;
            case FACTURE -> targetType == TypeDocument.AVOIR;
            case AVOIR -> false;
        };
        if (!valid) {
            throw new BusinessException(
                    "Conversion invalide: " + sourceType + " → " + targetType);
        }
    }

    // =================== VENTE COMPTOIR (POS) ===================

    @Transactional
    public PosSaleResponse realiserVentePos(PosSaleRequest request, String userEmail) {
        Utilisateur utilisateur = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        Entreprise entrepriseCourante = utilisateur.getEntreprise() != null
                ? utilisateur.getEntreprise()
                : securityUtils.getCurrentEntreprise().orElse(null);

        // Résolution du client (fourni ou Client Comptoir / Divers)
        Client client = null;
        if (request.getClientId() != null) {
            client = clientRepository.findById(request.getClientId())
                    .orElseThrow(() -> new ResourceNotFoundException("Client", "id", request.getClientId()));
        } else {
            Long entId = entrepriseCourante != null ? entrepriseCourante.getId() : null;
            java.util.List<Client> matches = entId != null
                    ? clientRepository.findByEntrepriseIdAndNomContainingIgnoreCase(entId, "Client Divers")
                    : clientRepository.findByNomContainingIgnoreCase("Client Divers");

            client = matches.stream().findFirst()
                    .orElseGet(() -> clientRepository.save(Client.builder()
                            .nom("Client Divers / Comptoir")
                            .telephone("00000000")
                            .entreprise(entrepriseCourante)
                            .build()));
        }

        // Résolution du dépôt actif
        Depot depot = null;
        if (request.getDepotId() != null) {
            depot = depotRepository.findById(request.getDepotId())
                    .orElseThrow(() -> new ResourceNotFoundException("Dépôt", "id", request.getDepotId()));
        } else if (utilisateur.getDepot() != null) {
            depot = utilisateur.getDepot();
        } else {
            depot = depotRepository.findAll().stream().findFirst()
                    .orElseThrow(() -> new BusinessException("Aucun dépôt disponible pour la vente"));
        }

        String numero = genererNumero(TypeDocument.FACTURE);

        // Créer la facture directement VALIDÉE
        Document document = Document.builder()
                .entreprise(entrepriseCourante != null ? entrepriseCourante : (depot != null ? depot.getEntreprise() : null))
                .type(TypeDocument.FACTURE)
                .numero(numero)
                .statut(StatutDocument.VALIDE)
                .client(client)
                .depot(depot)
                .dateDocument(LocalDate.now())
                .notes(request.getNotes() != null && !request.getNotes().isBlank() 
                        ? request.getNotes() 
                        : "Vente directe au comptoir (POS)")
                .utilisateur(utilisateur)
                .build();

        // Lignes et déstockage immédiat
        for (PosSaleRequest.LignePosRequest lr : request.getLignes()) {
            Produit produit = produitRepository.findById(lr.getProduitId())
                    .orElseThrow(() -> new ResourceNotFoundException("Produit", "id", lr.getProduitId()));

            VarianteProduit variante = null;
            if (lr.getVarianteId() != null) {
                variante = varianteProduitRepository.findById(lr.getVarianteId())
                        .orElseThrow(() -> new ResourceNotFoundException("Variante", "id", lr.getVarianteId()));
            }

            BigDecimal prix = lr.getPrixUnitaire() != null ? lr.getPrixUnitaire() : produit.getPrixVente();
            BigDecimal tva = lr.getTauxTva() != null ? lr.getTauxTva() : produit.getTauxTva();

            LigneDocument ligne = LigneDocument.builder()
                    .document(document)
                    .produit(produit)
                    .variante(variante)
                    .designation(lr.getDesignation() != null ? lr.getDesignation() : produit.getNom())
                    .quantite(lr.getQuantite())
                    .prixUnitaire(prix)
                    .tauxTva(tva)
                    .build();

            ligne.calculerMontants();
            document.getLignes().add(ligne);

            // Mouvement de stock de sortie atomique
            try {
                MouvementRequest mvtReq = MouvementRequest.builder()
                        .produitId(produit.getId())
                        .varianteId(variante != null ? variante.getId() : null)
                        .depotSourceId(depot.getId())
                        .type(com.quantis.stock.model.enums.TypeMouvement.SORTIE)
                        .motif(com.quantis.stock.model.enums.MotifMouvement.VENTE)
                        .quantite(lr.getQuantite())
                        .reference(numero)
                        .commentaire("Vente comptoir " + numero)
                        .forcerSortie(true) // Assure la fluidité en caisse
                        .build();
                stockService.enregistrerMouvement(mvtReq, userEmail);
            } catch (Exception e) {
                log.warn("Déstockage avertissement pour {} sur facture {}: {}", produit.getNom(), numero, e.getMessage());
            }
        }

        document.recalculerTotaux();
        document = documentRepository.save(document);

        // Paiement immédiat
        Paiement paiement = null;
        BigDecimal montantPaye = request.getMontantPaye() != null ? request.getMontantPaye() : BigDecimal.ZERO;

        if (montantPaye.compareTo(BigDecimal.ZERO) > 0) {
            paiement = Paiement.builder()
                    .document(document)
                    .montant(montantPaye)
                    .moyen(request.getMoyenPaiement())
                    .datePaiement(LocalDate.now())
                    .reference(numero)
                    .utilisateur(utilisateur)
                    .build();
            paiement = paiementRepository.save(paiement);

            // Enregistrer l'écriture dans la session de caisse
            try {
                com.quantis.stock.model.MouvementCaisse mouvementCaisse = com.quantis.stock.model.MouvementCaisse.builder()
                        .type(com.quantis.stock.model.enums.TypeCaisse.ENTREE)
                        .montant(montantPaye)
                        .libelle("Encaissement " + numero + " (" + request.getMoyenPaiement() + ")")
                        .dateMouvement(LocalDate.now())
                        .categorie("VENTE")
                        .reference(numero)
                        .document(document)
                        .utilisateur(utilisateur)
                        .build();
                comptabiliteService.enregistrerMouvement(mouvementCaisse, userEmail);
            } catch (Exception e) {
                log.warn("Impossible d'enregistrer le mouvement de caisse pour POS {}: {}", numero, e.getMessage());
            }
        }

        // Gestion du solde restant (vente à crédit)
        BigDecimal soldeRestant = document.getTotalTtc().subtract(montantPaye);
        if (soldeRestant.compareTo(BigDecimal.ZERO) > 0 && client != null) {
            client.setSoldeCredit(client.getSoldeCredit().add(soldeRestant));
            clientRepository.save(client);
        }

        // Calcul du montant reçu et rendu
        BigDecimal montantRecu = request.getMontantRecu() != null ? request.getMontantRecu() : montantPaye;
        BigDecimal monnaieRendue = montantRecu.compareTo(montantPaye) > 0
                ? montantRecu.subtract(montantPaye)
                : BigDecimal.ZERO;

        Entreprise ent = utilisateur.getEntreprise();

        log.info("Vente POS enregistrée: {} — Total {} FCFA — Reçu {} — Rendu {}",
                numero, document.getTotalTtc(), montantRecu, monnaieRendue);
        auditService.logAction("POS_SALE", "Document", document.getId(),
                "Vente POS " + numero + " de " + document.getTotalTtc() + " FCFA via " + request.getMoyenPaiement());

        return PosSaleResponse.builder()
                .document(document)
                .paiement(paiement)
                .montantTotal(document.getTotalTtc())
                .montantPaye(montantPaye)
                .montantRecu(montantRecu)
                .monnaieRendue(monnaieRendue)
                .soldeRestant(soldeRestant.compareTo(BigDecimal.ZERO) > 0 ? soldeRestant : BigDecimal.ZERO)
                .caissierNom(utilisateur.getPrenom() + " " + utilisateur.getNom())
                .clientNom(client != null ? client.getNom() : "Client Divers")
                .entrepriseNom(ent != null ? ent.getNom() : "Quantis SARL")
                .entrepriseNif(ent != null ? ent.getNif() : null)
                .entrepriseRccm(ent != null ? ent.getRccm() : null)
                .entrepriseTelephone(ent != null ? ent.getTelephone() : null)
                .entrepriseEmail(ent != null ? ent.getEmail() : null)
                .entrepriseAdresse(ent != null ? ent.getAdresse() : null)
                .entrepriseLogoUrl(ent != null ? ent.getLogoUrl() : null)
                .entrepriseMonnaie(ent != null ? ent.getMonnaie() : "FCFA")
                .build();
    }

    // =================== NUMÉROTATION ===================

    private String genererNumero(TypeDocument type) {
        String basePrefix = switch (type) {
            case DEVIS -> "DEV-";
            case COMMANDE_CLIENT -> "CMD-";
            case BON_LIVRAISON -> "BL-";
            case FACTURE -> "FAC-";
            case AVOIR -> "AV-";
        };

        // Si l'entreprise a défini un format spécifique pour les factures
        if (type == TypeDocument.FACTURE) {
            var optEnt = entrepriseRepository.findAll().stream().findFirst();
            if (optEnt.isPresent() && optEnt.get().getFormatFacture() != null && !optEnt.get().getFormatFacture().isBlank()) {
                String fmt = optEnt.get().getFormatFacture();
                String year = String.valueOf(Year.now().getValue());
                if (fmt.contains("{YYYY}")) {
                    String prefixBeforeNum = fmt.substring(0, fmt.indexOf("{NNNNN}")).replace("{YYYY}", year);
                    int maxNum = documentRepository.findMaxNumero(prefixBeforeNum);
                    return prefixBeforeNum + String.format("%05d", maxNum + 1);
                }
            }
        }

        String annee = String.valueOf(Year.now().getValue()) + "-";
        String fullPrefix = basePrefix + annee;
        int maxNum = documentRepository.findMaxNumero(fullPrefix);
        return fullPrefix + String.format("%05d", maxNum + 1);
    }
}

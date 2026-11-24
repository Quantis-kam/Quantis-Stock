package com.quantis.stock.service;

import com.quantis.stock.dto.DocumentRequest;
import com.quantis.stock.dto.MouvementRequest;
import com.quantis.stock.dto.PaiementRequest;
import com.quantis.stock.dto.PosSaleRequest;
import com.quantis.stock.dto.PosSaleResponse;
import com.quantis.stock.dto.ReglementClientRequest;
import com.quantis.stock.dto.SolderCommandeRequest;
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

        boolean tvaActive = entreprise == null || entreprise.isTvaActiveEffective();

        // Lignes
        for (DocumentRequest.LigneRequest lr : request.getLignes()) {
            Produit produit = produitRepository.findById(lr.getProduitId())
                    .orElseThrow(() -> new ResourceNotFoundException("Produit", "id", lr.getProduitId()));

            VarianteProduit variante = null;
            if (lr.getVarianteId() != null) {
                variante = varianteProduitRepository.findById(lr.getVarianteId())
                        .orElseThrow(() -> new ResourceNotFoundException("Variante", "id", lr.getVarianteId()));
            }

            BigDecimal tauxTvaLigne = lr.getTauxTva() != null
                    ? lr.getTauxTva()
                    : (!tvaActive
                        ? BigDecimal.ZERO
                        : (produit.getTauxTva() != null ? produit.getTauxTva() : BigDecimal.ZERO));

            LigneDocument ligne = LigneDocument.builder()
                    .document(document)
                    .produit(produit)
                    .variante(variante)
                    .designation(lr.getDesignation() != null ? lr.getDesignation() : produit.getNom())
                    .quantite(lr.getQuantite())
                    .prixUnitaire(lr.getPrixUnitaire())
                    .tauxTva(tauxTvaLigne)
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
        Document doc = documentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Document", "id", id));
        if (!securityUtils.isSuperAdmin()) {
            Long entId = securityUtils.getCurrentEntrepriseId();
            if (doc.getEntreprise() != null && !doc.getEntreprise().getId().equals(entId)) {
                throw new BusinessException("Accès refusé : ce document n'appartient pas à votre entreprise");
            }
        }
        return doc;
    }

    @Transactional(readOnly = true)
    public Document findByNumero(String numero) {
        Document doc = documentRepository.findByNumero(numero)
                .orElseThrow(() -> new ResourceNotFoundException("Document", "numero", numero));
        if (!securityUtils.isSuperAdmin()) {
            Long entId = securityUtils.getCurrentEntrepriseId();
            if (doc.getEntreprise() != null && !doc.getEntreprise().getId().equals(entId)) {
                throw new BusinessException("Accès refusé : ce document n'appartient pas à votre entreprise");
            }
        }
        return doc;
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
                    .libelle("Paiement " + document.getNumero() + " (" + request.getMoyen().getLibelle() + ")")
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

        // Résolution du client (nouveau client à la volée, client existant fourni, ou Client Comptoir / Divers)
        Client client = null;
        if (request.getNouveauClientNom() != null && !request.getNouveauClientNom().isBlank()) {
            String nomPropre = request.getNouveauClientNom().trim();
            String telPropre = request.getNouveauClientTelephone() != null ? request.getNouveauClientTelephone().trim() : null;
            String adrPropre = request.getNouveauClientAdresse() != null ? request.getNouveauClientAdresse().trim() : null;
            client = clientRepository.save(Client.builder()
                    .nom(nomPropre)
                    .telephone(telPropre != null && !telPropre.isEmpty() ? telPropre : null)
                    .adresse(adrPropre != null && !adrPropre.isEmpty() ? adrPropre : null)
                    .soldeCredit(BigDecimal.ZERO)
                    .actif(true)
                    .entreprise(entrepriseCourante)
                    .build());
            auditService.logAction("CREATE", "Client", client.getId(),
                    "Création rapide client POS (crédit) : " + client.getNom());
        } else if (request.getClientId() != null) {
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
            Long entId = entrepriseCourante != null ? entrepriseCourante.getId() : null;
            depot = (entId != null ? depotRepository.findByEntrepriseIdAndEstActifTrue(entId) : depotRepository.findByEstActifTrue())
                    .stream().findFirst()
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

        boolean tvaActivePos = entrepriseCourante == null || entrepriseCourante.isTvaActiveEffective();

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
            BigDecimal tva = lr.getTauxTva() != null
                    ? lr.getTauxTva()
                    : (!tvaActivePos
                        ? BigDecimal.ZERO
                        : (produit.getTauxTva() != null ? produit.getTauxTva() : BigDecimal.ZERO));

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
        BigDecimal montantPaye = request.getMoyenPaiement() == com.quantis.stock.model.enums.MoyenPaiement.CREDIT
                ? BigDecimal.ZERO
                : (request.getMontantPaye() != null ? request.getMontantPaye() : BigDecimal.ZERO);

        // Interdire tout crédit anonyme (total ou partiel) sur "Client Divers / Comptoir"
        BigDecimal soldeRestantAvantValidation = document.getTotalTtc().subtract(montantPaye);
        if (soldeRestantAvantValidation.compareTo(BigDecimal.ZERO) > 0 && isClientAnonyme(client)) {
            throw new BusinessException(
                    "Un client nominatif (nom et téléphone) est obligatoire pour toute vente à crédit ou paiement partiel.");
        }

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
                        .libelle("Encaissement " + numero + " (" + request.getMoyenPaiement().getLibelle() + ")")
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

    // =================== RÈGLEMENT DES CRÉANCES CLIENT ===================

    /**
     * Enregistre un règlement de crédit pour un client :
     * - soit sur une facture précise (documentId),
     * - soit en imputation FIFO automatique sur toutes ses factures impayées + reliquat de dette directe.
     */
    @Transactional
    public java.util.Map<String, Object> reglerCreanceClient(Long clientId, ReglementClientRequest request, String userEmail) {
        if (request.getMoyen() == com.quantis.stock.model.enums.MoyenPaiement.CREDIT) {
            throw new BusinessException("Veuillez choisir un moyen d'encaissement réel (Espèces, Wave, Orange Money, etc.).");
        }

        Client client = clientRepository.findById(clientId)
                .orElseThrow(() -> new ResourceNotFoundException("Client", "id", clientId));
        if (!securityUtils.isSuperAdmin()) {
            Long entId = securityUtils.getCurrentEntrepriseId();
            if (client.getEntreprise() != null && !client.getEntreprise().getId().equals(entId)) {
                throw new BusinessException("Accès refusé : ce client n'appartient pas à votre entreprise");
            }
        }

        Utilisateur utilisateur = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        BigDecimal ancienSolde = client.getSoldeCredit() != null ? client.getSoldeCredit() : BigDecimal.ZERO;
        BigDecimal montant = request.getMontant();
        LocalDate datePaiement = request.getDatePaiement() != null ? request.getDatePaiement() : LocalDate.now();
        java.util.List<String> facturesReglees = new java.util.ArrayList<>();

        if (request.getDocumentId() != null) {
            PaiementRequest pReq = new PaiementRequest();
            pReq.setDocumentId(request.getDocumentId());
            pReq.setMontant(montant);
            pReq.setMoyen(request.getMoyen());
            pReq.setDatePaiement(datePaiement);
            pReq.setReference(request.getReference());
            Paiement p = enregistrerPaiement(pReq, userEmail);
            facturesReglees.add(p.getDocument().getNumero());
        } else {
            BigDecimal resteAImputer = montant;

            // 1. Imputer par ordre chronologique (FIFO) sur les factures validées non soldées
            List<Document> factures = documentRepository
                    .findByClientIdAndTypeAndStatutOrderByDateDocumentAscIdAsc(
                            clientId, TypeDocument.FACTURE, StatutDocument.VALIDE);

            for (Document f : factures) {
                if (resteAImputer.compareTo(BigDecimal.ZERO) <= 0) break;
                BigDecimal soldeFacture = f.getSoldeRestant();
                if (soldeFacture.compareTo(BigDecimal.ZERO) <= 0) continue;

                BigDecimal aPayer = resteAImputer.min(soldeFacture);
                PaiementRequest pReq = new PaiementRequest();
                pReq.setDocumentId(f.getId());
                pReq.setMontant(aPayer);
                pReq.setMoyen(request.getMoyen());
                pReq.setDatePaiement(datePaiement);
                pReq.setReference(request.getReference() != null && !request.getReference().isBlank()
                        ? request.getReference()
                        : "REG-" + f.getNumero());
                enregistrerPaiement(pReq, userEmail);
                facturesReglees.add(f.getNumero());
                resteAImputer = resteAImputer.subtract(aPayer);
            }

            // 2. Reliquat éventuel sur créance initiale (hors facture)
            if (resteAImputer.compareTo(BigDecimal.ZERO) > 0) {
                Client freshClient = clientRepository.findById(clientId).orElse(client);
                BigDecimal soldeCourant = freshClient.getSoldeCredit() != null ? freshClient.getSoldeCredit() : BigDecimal.ZERO;
                if (resteAImputer.compareTo(soldeCourant) > 0) {
                    throw new BusinessException(String.format(
                            "Le montant (%s FCFA) dépasse le solde restant dû par %s (%s FCFA).",
                            montant, freshClient.getNom(), ancienSolde));
                }
                freshClient.setSoldeCredit(soldeCourant.subtract(resteAImputer));
                clientRepository.save(freshClient);

                // Comptabiliser cette entrée en caisse
                try {
                    com.quantis.stock.model.MouvementCaisse mvt = com.quantis.stock.model.MouvementCaisse.builder()
                            .type(com.quantis.stock.model.enums.TypeCaisse.ENTREE)
                            .montant(resteAImputer)
                            .libelle("Règlement créance " + freshClient.getNom() + " (" + request.getMoyen().getLibelle() + ")")
                            .dateMouvement(datePaiement)
                            .categorie("REGLEMENT_CREDIT")
                            .reference(request.getReference() != null && !request.getReference().isBlank()
                                    ? request.getReference()
                                    : "CREANCE-" + freshClient.getId())
                            .utilisateur(utilisateur)
                            .build();
                    comptabiliteService.enregistrerMouvement(mvt, userEmail);
                } catch (Exception e) {
                    log.warn("Impossible d'imputer le mouvement de caisse pour règlement créance client {}: {}", clientId, e.getMessage());
                }

                auditService.logAction("CREDIT_SETTLEMENT", "Client", freshClient.getId(),
                        "Règlement créance directe de " + resteAImputer + " FCFA par " + freshClient.getNom());
            }
        }

        Client updatedClient = clientRepository.findById(clientId).orElse(client);
        BigDecimal nouveauSolde = updatedClient.getSoldeCredit() != null
                ? updatedClient.getSoldeCredit().max(BigDecimal.ZERO)
                : BigDecimal.ZERO;
        if (updatedClient.getSoldeCredit() != null && updatedClient.getSoldeCredit().compareTo(BigDecimal.ZERO) < 0) {
            updatedClient.setSoldeCredit(BigDecimal.ZERO);
            clientRepository.save(updatedClient);
        }

        java.util.Map<String, Object> result = new java.util.LinkedHashMap<>();
        result.put("clientId", updatedClient.getId());
        result.put("clientNom", updatedClient.getNom());
        result.put("montantEncaisse", montant);
        result.put("moyen", request.getMoyen().name());
        result.put("moyenLibelle", request.getMoyen().getLibelle());
        result.put("ancienSolde", ancienSolde);
        result.put("nouveauSolde", nouveauSolde);
        result.put("facturesReglees", facturesReglees);
        return result;
    }

    // =================== VALIDER & SOLDER UNE COMMANDE CLIENT ===================

    /**
     * Valide une commande client, déstocke les articles, génère la facture validée liée,
     * enregistre le règlement en caisse et retourne un reçu complet prêt à imprimer / partager.
     */
    @Transactional
    public PosSaleResponse solderCommandeClient(Long commandeId, SolderCommandeRequest request, String userEmail) {
        Document commande = findById(commandeId);
        if (commande.getType() != TypeDocument.COMMANDE_CLIENT) {
            throw new BusinessException("Cette action s'applique uniquement à une commande client.");
        }
        if (commande.getStatut() == StatutDocument.ANNULE) {
            throw new BusinessException("Impossible de solder une commande annulée.");
        }

        Utilisateur utilisateur = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        Entreprise ent = commande.getEntreprise() != null
                ? commande.getEntreprise()
                : utilisateur.getEntreprise();

        // Résolution optionnelle d'un client nominatif (existant ou créé à la volée) pour éviter tout rejet sur crédit
        Client resolvedClient = commande.getClient();
        if (request.getNouveauClientNom() != null && !request.getNouveauClientNom().isBlank()) {
            String nomPropre = request.getNouveauClientNom().trim();
            String telPropre = request.getNouveauClientTelephone() != null ? request.getNouveauClientTelephone().trim() : null;
            String adrPropre = request.getNouveauClientAdresse() != null ? request.getNouveauClientAdresse().trim() : null;
            resolvedClient = clientRepository.save(Client.builder()
                    .nom(nomPropre)
                    .telephone(telPropre != null && !telPropre.isEmpty() ? telPropre : null)
                    .adresse(adrPropre != null && !adrPropre.isEmpty() ? adrPropre : null)
                    .soldeCredit(BigDecimal.ZERO)
                    .actif(true)
                    .entreprise(ent)
                    .build());
            commande.setClient(resolvedClient);
            auditService.logAction("CREATE", "Client", resolvedClient.getId(),
                    "Création rapide client (règlement commande " + commande.getNumero() + ") : " + resolvedClient.getNom());
        } else if (request.getClientId() != null) {
            Client picked = clientRepository.findById(request.getClientId())
                    .orElseThrow(() -> new ResourceNotFoundException("Client", "id", request.getClientId()));
            if (!securityUtils.isSuperAdmin() && ent != null && picked.getEntreprise() != null
                    && !picked.getEntreprise().getId().equals(ent.getId())) {
                throw new BusinessException("Accès refusé : ce client n'appartient pas à votre entreprise.");
            }
            resolvedClient = picked;
            commande.setClient(resolvedClient);
        }

        // Si une facture enfant existe déjà pour cette commande, éviter tout doublon
        var existingFactureOpt = documentRepository
                .findFirstByDocumentParentIdAndTypeOrderByIdDesc(commande.getId(), TypeDocument.FACTURE);
        if (existingFactureOpt.isPresent()) {
            Document existing = existingFactureOpt.get();
            if (existing.getSoldeRestant().compareTo(BigDecimal.ZERO) <= 0) {
                throw new BusinessException("Cette commande est déjà facturée et soldée (" + existing.getNumero() + ").");
            }
            if (resolvedClient != null && isClientAnonyme(existing.getClient()) && !isClientAnonyme(resolvedClient)) {
                existing.setClient(resolvedClient);
                documentRepository.save(existing);
                documentRepository.save(commande);
            }
            if (existing.getStatut() == StatutDocument.BROUILLON) {
                existing = validerDocument(existing.getId());
            }
            BigDecimal solde = existing.getSoldeRestant();
            BigDecimal montantPaye = request.getMoyenPaiement() == com.quantis.stock.model.enums.MoyenPaiement.CREDIT
                    ? BigDecimal.ZERO
                    : (request.getMontantPaye() != null ? request.getMontantPaye().min(solde) : solde);
            BigDecimal resteApres = solde.subtract(montantPaye).max(BigDecimal.ZERO);
            if (resteApres.compareTo(BigDecimal.ZERO) > 0 && isClientAnonyme(existing.getClient())) {
                throw new BusinessException("Un client nominatif (nom et téléphone) est obligatoire si la commande n'est pas soldée intégralement.");
            }
            Paiement paiement = null;
            if (montantPaye.compareTo(BigDecimal.ZERO) > 0) {
                PaiementRequest pReq = new PaiementRequest();
                pReq.setDocumentId(existing.getId());
                pReq.setMontant(montantPaye);
                pReq.setMoyen(request.getMoyenPaiement());
                pReq.setDatePaiement(LocalDate.now());
                pReq.setReference(request.getReference() != null && !request.getReference().isBlank()
                        ? request.getReference()
                        : existing.getNumero());
                paiement = enregistrerPaiement(pReq, userEmail);
            }
            BigDecimal reste = existing.getTotalTtc().subtract(existing.getMontantPaye()).subtract(montantPaye).max(BigDecimal.ZERO);
            BigDecimal montantRecu = request.getMontantRecu() != null ? request.getMontantRecu() : montantPaye;
            BigDecimal monnaieRendue = montantRecu.compareTo(montantPaye) > 0 ? montantRecu.subtract(montantPaye) : BigDecimal.ZERO;

            return PosSaleResponse.builder()
                    .document(existing)
                    .paiement(paiement)
                    .montantTotal(existing.getTotalTtc())
                    .montantPaye(montantPaye)
                    .montantRecu(montantRecu)
                    .monnaieRendue(monnaieRendue)
                    .soldeRestant(reste)
                    .caissierNom(utilisateur.getPrenom() + " " + utilisateur.getNom())
                    .clientNom(existing.getClient() != null ? existing.getClient().getNom() : "Client")
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

        // 1. Valider la commande si elle était encore en brouillon
        if (commande.getStatut() == StatutDocument.BROUILLON) {
            commande.setStatut(StatutDocument.VALIDE);
        }

        // 2. Déterminer le dépôt de sortie
        Depot depot = commande.getDepot() != null ? commande.getDepot() : utilisateur.getDepot();
        if (depot == null) {
            Long entId = ent != null ? ent.getId() : null;
            depot = (entId != null ? depotRepository.findByEntrepriseIdAndEstActifTrue(entId) : depotRepository.findByEstActifTrue())
                    .stream().findFirst().orElse(null);
        }

        // 3. Créer la Facture directement VALIDÉE depuis la commande
        String numeroFacture = genererNumero(TypeDocument.FACTURE);
        Document facture = Document.builder()
                .entreprise(ent)
                .type(TypeDocument.FACTURE)
                .numero(numeroFacture)
                .statut(StatutDocument.VALIDE)
                .client(resolvedClient)
                .depot(depot)
                .dateDocument(LocalDate.now())
                .dateEcheance(commande.getDateEcheance())
                .notes(request.getNotes() != null && !request.getNotes().isBlank()
                        ? request.getNotes()
                        : "Facture issue de la commande " + commande.getNumero())
                .utilisateur(utilisateur)
                .documentParent(commande)
                .build();

        for (LigneDocument src : commande.getLignes()) {
            LigneDocument ligne = LigneDocument.builder()
                    .document(facture)
                    .produit(src.getProduit())
                    .variante(src.getVariante())
                    .designation(src.getDesignation())
                    .quantite(src.getQuantite())
                    .prixUnitaire(src.getPrixUnitaire())
                    .tauxTva(src.getTauxTva() != null ? src.getTauxTva() : BigDecimal.ZERO)
                    .build();
            ligne.calculerMontants();
            facture.getLignes().add(ligne);

            // Déstockage automatique des articles commandés
            if (depot != null && src.getProduit() != null) {
                try {
                    MouvementRequest mvtReq = MouvementRequest.builder()
                            .produitId(src.getProduit().getId())
                            .varianteId(src.getVariante() != null ? src.getVariante().getId() : null)
                            .depotSourceId(depot.getId())
                            .type(com.quantis.stock.model.enums.TypeMouvement.SORTIE)
                            .motif(com.quantis.stock.model.enums.MotifMouvement.VENTE)
                            .quantite(src.getQuantite())
                            .reference(numeroFacture)
                            .commentaire("Livraison commande " + commande.getNumero() + " / " + numeroFacture)
                            .forcerSortie(true)
                            .build();
                    stockService.enregistrerMouvement(mvtReq, userEmail);
                } catch (Exception e) {
                    log.warn("Déstockage avertissement commande {}: {}", commande.getNumero(), e.getMessage());
                }
            }
        }

        facture.recalculerTotaux();

        // 4. Montant payé et contrôle crédit nominatif
        BigDecimal montantPaye = request.getMoyenPaiement() == com.quantis.stock.model.enums.MoyenPaiement.CREDIT
                ? BigDecimal.ZERO
                : (request.getMontantPaye() != null ? request.getMontantPaye() : facture.getTotalTtc());
        if (montantPaye.compareTo(facture.getTotalTtc()) > 0) {
            montantPaye = facture.getTotalTtc();
        }

        BigDecimal soldeRestant = facture.getTotalTtc().subtract(montantPaye);
        if (soldeRestant.compareTo(BigDecimal.ZERO) > 0 && isClientAnonyme(commande.getClient())) {
            throw new BusinessException("Un client nominatif est obligatoire si la commande n'est pas soldée intégralement.");
        }

        facture = documentRepository.save(facture);

        // 5. Enregistrer le paiement + mouvement de caisse
        Paiement paiement = null;
        if (montantPaye.compareTo(BigDecimal.ZERO) > 0) {
            paiement = Paiement.builder()
                    .document(facture)
                    .montant(montantPaye)
                    .moyen(request.getMoyenPaiement())
                    .datePaiement(LocalDate.now())
                    .reference(request.getReference() != null && !request.getReference().isBlank()
                            ? request.getReference()
                            : numeroFacture)
                    .utilisateur(utilisateur)
                    .build();
            paiement = paiementRepository.save(paiement);

            try {
                com.quantis.stock.model.MouvementCaisse mouvementCaisse = com.quantis.stock.model.MouvementCaisse.builder()
                        .type(com.quantis.stock.model.enums.TypeCaisse.ENTREE)
                        .montant(montantPaye)
                        .libelle("Commande " + commande.getNumero() + " → " + numeroFacture + " (" + request.getMoyenPaiement().getLibelle() + ")")
                        .dateMouvement(LocalDate.now())
                        .categorie("VENTE")
                        .reference(numeroFacture)
                        .document(facture)
                        .utilisateur(utilisateur)
                        .build();
                comptabiliteService.enregistrerMouvement(mouvementCaisse, userEmail);
            } catch (Exception e) {
                log.warn("Impossible d'enregistrer le mouvement de caisse pour commande {}: {}", commande.getNumero(), e.getMessage());
            }
        }

        // 6. Mettre à jour la créance client uniquement s'il reste un solde impayé
        if (soldeRestant.compareTo(BigDecimal.ZERO) > 0 && commande.getClient() != null) {
            Client c = commande.getClient();
            BigDecimal currentCredit = c.getSoldeCredit() != null ? c.getSoldeCredit() : BigDecimal.ZERO;
            c.setSoldeCredit(currentCredit.add(soldeRestant));
            clientRepository.save(c);
        }

        // 7. Marquer clairement la commande d'origine comme soldée/facturée
        String tag = soldeRestant.compareTo(BigDecimal.ZERO) <= 0
                ? "Soldée → " + numeroFacture
                : "Facturée → " + numeroFacture;
        String existingNotes = commande.getNotes() != null ? commande.getNotes().trim() : "";
        commande.setNotes(existingNotes.isEmpty() ? tag : existingNotes + " • " + tag);
        documentRepository.save(commande);

        BigDecimal montantRecu = request.getMontantRecu() != null ? request.getMontantRecu() : montantPaye;
        BigDecimal monnaieRendue = montantRecu.compareTo(montantPaye) > 0
                ? montantRecu.subtract(montantPaye)
                : BigDecimal.ZERO;

        auditService.logAction("SETTLE_ORDER", "Document", facture.getId(),
                "Commande " + commande.getNumero() + " validée et " + tag + " (" + montantPaye + " FCFA via " + request.getMoyenPaiement().getLibelle() + ")");

        return PosSaleResponse.builder()
                .document(facture)
                .paiement(paiement)
                .montantTotal(facture.getTotalTtc())
                .montantPaye(montantPaye)
                .montantRecu(montantRecu)
                .monnaieRendue(monnaieRendue)
                .soldeRestant(soldeRestant.max(BigDecimal.ZERO))
                .caissierNom(utilisateur.getPrenom() + " " + utilisateur.getNom())
                .clientNom(commande.getClient() != null ? commande.getClient().getNom() : "Client")
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

    private boolean isClientAnonyme(Client client) {
        if (client == null || client.getNom() == null || client.getNom().isBlank()) {
            return true;
        }
        String lower = client.getNom().toLowerCase();
        return lower.contains("client divers") || lower.contains("comptoir") || lower.equals("anonyme");
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
            var optEnt = securityUtils.getCurrentEntreprise();
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

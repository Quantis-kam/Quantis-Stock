package com.quantis.stock.service;

import com.quantis.stock.dto.CommandeRequest;
import com.quantis.stock.dto.MouvementRequest;
import com.quantis.stock.dto.ReceptionRequest;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.*;
import com.quantis.stock.model.enums.MotifMouvement;
import com.quantis.stock.model.enums.StatutCommande;
import com.quantis.stock.model.enums.TypeMouvement;
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

/**
 * Service Achats — Commandes fournisseur + Réception avec lien automatique stock.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AchatService {

    private final CommandeFournisseurRepository commandeRepository;
    private final FournisseurRepository fournisseurRepository;
    private final DepotRepository depotRepository;
    private final ProduitRepository produitRepository;
    private final VarianteProduitRepository varianteProduitRepository;
    private final UtilisateurRepository utilisateurRepository;
    private final StockService stockService;
    private final AuditService auditService;

    // =================== COMMANDES ===================

    @Transactional
    public CommandeFournisseur creerCommande(CommandeRequest request, String userEmail) {
        Fournisseur fournisseur = fournisseurRepository.findById(request.getFournisseurId())
                .orElseThrow(() -> new ResourceNotFoundException("Fournisseur", "id", request.getFournisseurId()));

        Depot depot = depotRepository.findById(request.getDepotId())
                .orElseThrow(() -> new ResourceNotFoundException("Dépôt", "id", request.getDepotId()));

        Utilisateur utilisateur = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        String numero = genererNumero();

        CommandeFournisseur commande = CommandeFournisseur.builder()
                .numero(numero)
                .fournisseur(fournisseur)
                .depot(depot)
                .dateCommande(request.getDateCommande() != null ? request.getDateCommande() : LocalDate.now())
                .dateLivraisonPrevue(request.getDateLivraisonPrevue())
                .notes(request.getNotes())
                .utilisateur(utilisateur)
                .build();

        for (CommandeRequest.LigneCommandeRequest lr : request.getLignes()) {
            Produit produit = produitRepository.findById(lr.getProduitId())
                    .orElseThrow(() -> new ResourceNotFoundException("Produit", "id", lr.getProduitId()));

            VarianteProduit variante = null;
            if (lr.getVarianteId() != null) {
                variante = varianteProduitRepository.findById(lr.getVarianteId())
                        .orElseThrow(() -> new ResourceNotFoundException("Variante", "id", lr.getVarianteId()));
            }

            LigneCommandeFournisseur ligne = LigneCommandeFournisseur.builder()
                    .commande(commande)
                    .produit(produit)
                    .variante(variante)
                    .quantiteCommandee(lr.getQuantite())
                    .prixUnitaire(lr.getPrixUnitaire())
                    .build();

            commande.getLignes().add(ligne);
        }

        commande.recalculerTotal();
        commande = commandeRepository.save(commande);
        log.info("Commande créée: {} — {} FCFA", numero, commande.getTotalHt());
        auditService.logAction("CREATE", "Achat", commande.getId(), "Création commande fournisseur " + commande.getNumero());
        return commande;
    }

    @Transactional
    public CommandeFournisseur validerCommande(Long id) {
        CommandeFournisseur commande = findById(id);
        if (commande.getStatut() != StatutCommande.BROUILLON) {
            throw new BusinessException("Seul un brouillon peut être validé");
        }
        commande.setStatut(StatutCommande.EN_COURS);
        log.info("Commande validée: {}", commande.getNumero());
        CommandeFournisseur saved = commandeRepository.save(commande);
        auditService.logAction("VALIDATE", "Achat", saved.getId(), "Validation commande fournisseur " + saved.getNumero());
        return saved;
    }

    @Transactional
    public CommandeFournisseur annulerCommande(Long id) {
        CommandeFournisseur commande = findById(id);
        if (commande.getStatut() == StatutCommande.RECUE || commande.getStatut() == StatutCommande.ANNULEE) {
            throw new BusinessException("Impossible d'annuler une commande " + commande.getStatut());
        }
        commande.setStatut(StatutCommande.ANNULEE);
        log.info("Commande annulée: {}", commande.getNumero());
        CommandeFournisseur saved = commandeRepository.save(commande);
        auditService.logAction("CANCEL", "Achat", saved.getId(), "Annulation commande fournisseur " + saved.getNumero());
        return saved;
    }

    // =================== RÉCEPTION ===================

    /**
     * Réceptionner une commande (partielle ou totale).
     * Chaque ligne reçue crée automatiquement une ENTREE de stock.
     */
    @Transactional
    public CommandeFournisseur receptionner(Long commandeId, ReceptionRequest request, String userEmail) {
        CommandeFournisseur commande = findById(commandeId);

        if (commande.getStatut() != StatutCommande.EN_COURS && commande.getStatut() != StatutCommande.RECUE_PARTIELLE) {
            throw new BusinessException("Seule une commande EN_COURS ou RECUE_PARTIELLE peut être réceptionnée");
        }

        BigDecimal totalReceptionVal = BigDecimal.ZERO;

        for (ReceptionRequest.LigneReception lr : request.getLignes()) {
            LigneCommandeFournisseur ligne = commande.getLignes().stream()
                    .filter(l -> l.getId().equals(lr.getLigneCommandeId()))
                    .findFirst()
                    .orElseThrow(() -> new ResourceNotFoundException("Ligne commande", "id", lr.getLigneCommandeId()));

            BigDecimal nouvelleQteRecue = ligne.getQuantiteRecue().add(lr.getQuantiteRecue());
            if (nouvelleQteRecue.compareTo(ligne.getQuantiteCommandee()) > 0) {
                throw new BusinessException(String.format(
                        "Quantité reçue (%s) dépasse la quantité commandée (%s) pour %s",
                        nouvelleQteRecue, ligne.getQuantiteCommandee(), ligne.getProduit().getNom()));
            }

            ligne.setQuantiteRecue(nouvelleQteRecue);

            BigDecimal ligneVal = ligne.getPrixUnitaire().multiply(lr.getQuantiteRecue());
            totalReceptionVal = totalReceptionVal.add(ligneVal);

            // Créer automatiquement un mouvement ENTREE de stock
            MouvementRequest mvtRequest = new MouvementRequest();
            mvtRequest.setType(TypeMouvement.ENTREE);
            mvtRequest.setMotif(MotifMouvement.ACHAT);
            mvtRequest.setProduitId(ligne.getProduit().getId());
            if (ligne.getVariante() != null) {
                mvtRequest.setVarianteId(ligne.getVariante().getId());
            }
            mvtRequest.setDepotDestId(commande.getDepot().getId());
            mvtRequest.setQuantite(lr.getQuantiteRecue());
            mvtRequest.setReference("REC-" + commande.getNumero());
            mvtRequest.setCommentaire("Réception commande " + commande.getNumero());

            stockService.enregistrerMouvement(mvtRequest, userEmail);
        }

        // Mettre à jour le solde du fournisseur
        Fournisseur fournisseur = commande.getFournisseur();
        if (fournisseur != null) {
            fournisseur.setSoldeDette(fournisseur.getSoldeDette().add(totalReceptionVal));
            fournisseurRepository.save(fournisseur);
        }

        // Mettre à jour le statut
        if (commande.isEntierementRecue()) {
            commande.setStatut(StatutCommande.RECUE);
            log.info("Commande entièrement reçue: {}", commande.getNumero());
        } else if (commande.isPartiellementRecue()) {
            commande.setStatut(StatutCommande.RECUE_PARTIELLE);
            log.info("Commande partiellement reçue: {}", commande.getNumero());
        }

        CommandeFournisseur saved = commandeRepository.save(commande);
        auditService.logAction("RECEIVE", "Achat", saved.getId(), "Réception commande fournisseur " + saved.getNumero() + " (" + saved.getStatut() + ")");
        return saved;
    }

    // =================== LECTURE ===================

    @Transactional(readOnly = true)
    public CommandeFournisseur findById(Long id) {
        return commandeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Commande", "id", id));
    }

    @Transactional(readOnly = true)
    public Page<CommandeFournisseur> findAll(Pageable pageable) {
        return commandeRepository.findAllByOrderByCreatedAtDesc(pageable);
    }

    @Transactional(readOnly = true)
    public Page<CommandeFournisseur> findByStatut(StatutCommande statut, Pageable pageable) {
        return commandeRepository.findByStatut(statut, pageable);
    }

    @Transactional(readOnly = true)
    public Page<CommandeFournisseur> findByFournisseur(Long fournisseurId, Pageable pageable) {
        return commandeRepository.findByFournisseurId(fournisseurId, pageable);
    }

    // =================== NUMÉROTATION ===================

    private String genererNumero() {
        String prefix = "CMD-" + Year.now().getValue() + "-";
        int max = commandeRepository.findMaxNumero(prefix);
        return prefix + String.format("%05d", max + 1);
    }
}

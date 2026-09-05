package com.quantis.stock.service;

import com.quantis.stock.dto.ClotureRequestDto;
import com.quantis.stock.dto.ClotureSyntheseDto;
import com.quantis.stock.dto.EcritureGrandLivreDto;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.*;
import com.quantis.stock.model.enums.StatutDocument;
import com.quantis.stock.model.enums.TypeCaisse;
import com.quantis.stock.model.enums.TypeDocument;
import com.quantis.stock.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

/**
 * Service Comptabilité — Journal de Caisse, Grand Livre Général & Clôtures Périodiques.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ComptabiliteService {

    private final MouvementCaisseRepository caisseRepository;
    private final UtilisateurRepository utilisateurRepository;
    private final SessionCaisseRepository sessionCaisseRepository;
    private final ClotureComptableRepository clotureRepository;
    private final DocumentRepository documentRepository;
    private final CommandeFournisseurRepository commandeFournisseurRepository;
    private final StockCourantRepository stockCourantRepository;
    private final ClientRepository clientRepository;
    private final FournisseurRepository fournisseurRepository;

    // =================== JOURNAL DE CAISSE ===================

    @Transactional
    public MouvementCaisse enregistrerMouvement(MouvementCaisse mouvement, String userEmail) {
        var utilisateur = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));
        mouvement.setUtilisateur(utilisateur);
        if (mouvement.getDateMouvement() == null) {
            mouvement.setDateMouvement(LocalDate.now());
        }

        // Lier automatiquement à la session de caisse active du caissier
        var sessionActive = sessionCaisseRepository.findByCaissierIdAndStatut(
                utilisateur.getId(), com.quantis.stock.model.enums.StatutSessionCaisse.OUVERTE);
        if (sessionActive.isPresent()) {
            var session = sessionActive.get();
            mouvement.setSessionCaisse(session);
            if (mouvement.getType() == TypeCaisse.ENTREE) {
                session.setTotalEntrees(session.getTotalEntrees().add(mouvement.getMontant()));
            } else if (mouvement.getType() == TypeCaisse.SORTIE) {
                session.setTotalSorties(session.getTotalSorties().add(mouvement.getMontant()));
            }
            session.recalculerSoldeTheorique();
            sessionCaisseRepository.save(session);
        }

        mouvement = caisseRepository.save(mouvement);
        log.info("Mouvement caisse {}: {} FCFA — {}", mouvement.getType(), mouvement.getMontant(), mouvement.getLibelle());
        return mouvement;
    }

    @Transactional(readOnly = true)
    public Page<MouvementCaisse> getJournal(LocalDate debut, LocalDate fin, Pageable pageable) {
        return caisseRepository.findByDateMouvementBetweenOrderByDateMouvementDesc(debut, fin, pageable);
    }

    // =================== GRAND LIVRE GÉNÉRAL ===================

    @Transactional(readOnly = true)
    public List<EcritureGrandLivreDto> getGrandLivre(LocalDate debut, LocalDate fin) {
        List<EcritureGrandLivreDto> ecritures = new ArrayList<>();

        // 1. Factures de Vente Validées (Ventes de marchandises / Produits d'exploitation)
        List<Document> factures = documentRepository.findByDateDocumentBetweenAndStatut(
                debut, fin, StatutDocument.VALIDE);
        for (Document f : factures) {
            if (f.getType() == TypeDocument.FACTURE || f.getType() == TypeDocument.BON_LIVRAISON) {
                String clientNom = f.getClient() != null ? f.getClient().getNom() : "Client Comptoir";
                ecritures.add(EcritureGrandLivreDto.builder()
                        .date(f.getDateDocument() != null ? f.getDateDocument() : LocalDate.now())
                        .typeFlux("VENTE")
                        .referencePiece(f.getNumero())
                        .tiersOuCategorie(clientNom)
                        .libelle("Vente facturée " + f.getNumero() + " (" + clientNom + ")")
                        .debit(f.getTotalTtc()) // Débit client / Chiffre d'affaires
                        .credit(BigDecimal.ZERO)
                        .build());
            }
        }

        // 2. Commandes d'Achat Fournisseurs (Charges / Achats de marchandises)
        List<CommandeFournisseur> achats = commandeFournisseurRepository.findByDateCommandeBetween(debut, fin);
        for (CommandeFournisseur a : achats) {
            if (a.getStatut() != com.quantis.stock.model.enums.StatutCommande.ANNULEE
                    && a.getStatut() != com.quantis.stock.model.enums.StatutCommande.BROUILLON) {
                String fourNom = a.getFournisseur() != null ? a.getFournisseur().getNom() : "Fournisseur";
                ecritures.add(EcritureGrandLivreDto.builder()
                        .date(a.getDateCommande() != null ? a.getDateCommande() : LocalDate.now())
                        .typeFlux("ACHAT")
                        .referencePiece(a.getNumero())
                        .tiersOuCategorie(fourNom)
                        .libelle("Achat stock " + a.getNumero() + " (" + fourNom + ")")
                        .debit(BigDecimal.ZERO)
                        .credit(a.getTotalHt() != null ? a.getTotalHt() : BigDecimal.ZERO) // Crédit fournisseur
                        .build());
            }
        }

        // 3. Mouvements de Caisse (Encaissements & Décaissements effectifs)
        List<MouvementCaisse> mouvements = caisseRepository.findByDateMouvementBetweenOrderByDateMouvementAsc(debut, fin);
        for (MouvementCaisse m : mouvements) {
            boolean isEntree = m.getType() == TypeCaisse.ENTREE;
            ecritures.add(EcritureGrandLivreDto.builder()
                    .date(m.getDateMouvement())
                    .typeFlux(isEntree ? "ENCAISSEMENT_CAISSE" : "DEPENSE_CAISSE")
                    .referencePiece(m.getReference() != null && !m.getReference().isBlank() ? m.getReference() : "MC-" + m.getId())
                    .tiersOuCategorie(m.getCategorie() != null ? m.getCategorie() : (isEntree ? "Recettes" : "Frais Généraux"))
                    .libelle(m.getLibelle())
                    .debit(isEntree ? m.getMontant() : BigDecimal.ZERO)
                    .credit(isEntree ? BigDecimal.ZERO : m.getMontant())
                    .build());
        }

        // Tri chronologique ascendant
        ecritures.sort(Comparator.comparing(EcritureGrandLivreDto::getDate));

        // Calcul du solde progressif
        BigDecimal soldeCumule = BigDecimal.ZERO;
        for (EcritureGrandLivreDto e : ecritures) {
            soldeCumule = soldeCumule.add(e.getDebit()).subtract(e.getCredit());
            e.setSoldeProgressif(soldeCumule);
        }

        return ecritures;
    }

    // =================== CLÔTURES PÉRIODIQUES ===================

    @Transactional(readOnly = true)
    public ClotureSyntheseDto simulerCloture(LocalDate debut, LocalDate fin, String periode) {
        // 1. Chiffre d'affaires & TVA
        List<Document> factures = documentRepository.findByDateDocumentBetweenAndStatut(
                debut, fin, StatutDocument.VALIDE);
        BigDecimal caTtc = BigDecimal.ZERO;
        BigDecimal caHt = BigDecimal.ZERO;
        BigDecimal tvaCollectee = BigDecimal.ZERO;
        int nbVentes = 0;

        for (Document f : factures) {
            if (f.getType() == TypeDocument.FACTURE || f.getType() == TypeDocument.BON_LIVRAISON) {
                caTtc = caTtc.add(f.getTotalTtc() != null ? f.getTotalTtc() : BigDecimal.ZERO);
                caHt = caHt.add(f.getTotalHt() != null ? f.getTotalHt() : BigDecimal.ZERO);
                tvaCollectee = tvaCollectee.add(f.getTotalTva() != null ? f.getTotalTva() : BigDecimal.ZERO);
                nbVentes++;
            }
        }

        // 2. Achats fournisseurs
        List<CommandeFournisseur> achats = commandeFournisseurRepository.findByDateCommandeBetween(debut, fin);
        BigDecimal achatsHt = BigDecimal.ZERO;
        int nbAchats = 0;

        for (CommandeFournisseur a : achats) {
            if (a.getStatut() != com.quantis.stock.model.enums.StatutCommande.ANNULEE) {
                achatsHt = achatsHt.add(a.getTotalHt() != null ? a.getTotalHt() : BigDecimal.ZERO);
                nbAchats++;
            }
        }

        // 3. Mouvements de Caisse
        BigDecimal totalEntrees = caisseRepository.sumByTypeAndPeriode(TypeCaisse.ENTREE, debut, fin);
        BigDecimal totalSorties = caisseRepository.sumByTypeAndPeriode(TypeCaisse.SORTIE, debut, fin);
        if (totalEntrees == null) totalEntrees = BigDecimal.ZERO;
        if (totalSorties == null) totalSorties = BigDecimal.ZERO;
        BigDecimal soldeCaisse = totalEntrees.subtract(totalSorties);

        // 4. Marge brute estimée
        BigDecimal margeBrute = caHt.subtract(achatsHt);

        // 5. Valorisation du Stock final
        List<StockCourant> stocks = stockCourantRepository.findAll();
        BigDecimal valeurStock = BigDecimal.ZERO;
        for (StockCourant sc : stocks) {
            if (sc.getQuantite() != null && sc.getQuantite().compareTo(BigDecimal.ZERO) > 0) {
                BigDecimal prix = sc.getProduit().getPrixAchat() != null
                        ? sc.getProduit().getPrixAchat()
                        : (sc.getProduit().getPrixVente() != null ? sc.getProduit().getPrixVente() : BigDecimal.ZERO);
                valeurStock = valeurStock.add(sc.getQuantite().multiply(prix));
            }
        }

        // 6. Créances & Dettes
        BigDecimal creances = clientRepository.sumSoldeCredit();
        if (creances == null) creances = BigDecimal.ZERO;
        BigDecimal dettes = fournisseurRepository.sumSoldeDette();
        if (dettes == null) dettes = BigDecimal.ZERO;

        boolean dejaCloturee = clotureRepository.existsByPeriode(periode);

        return ClotureSyntheseDto.builder()
                .periode(periode)
                .libelle("Bilan Périodique — " + periode)
                .dateDebut(debut)
                .dateFin(fin)
                .chiffreAffairesTtc(caTtc)
                .chiffreAffairesHt(caHt)
                .totalTvaCollectee(tvaCollectee)
                .totalAchatsHt(achatsHt)
                .totalDepensesCaisse(totalSorties)
                .totalEntreesCaisse(totalEntrees)
                .margeBruteEstimee(margeBrute)
                .valeurStockFinPeriode(valeurStock)
                .totalCreancesClients(creances)
                .totalDettesFournisseurs(dettes)
                .soldeCaisseFinal(soldeCaisse)
                .nombreVentes(nbVentes)
                .nombreAchats(nbAchats)
                .dejaCloturee(dejaCloturee)
                .build();
    }

    @Transactional
    public ClotureComptable validerCloture(ClotureRequestDto req, String userEmail) {
        var utilisateur = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        // Vérifier si déjà clôturé
        clotureRepository.findByPeriode(req.getPeriode()).ifPresent(c -> {
            throw new IllegalArgumentException("La période « " + req.getPeriode() + " » a déjà fait l'objet d'une clôture verrouillée.");
        });

        ClotureSyntheseDto synthese = simulerCloture(req.getDateDebut(), req.getDateFin(), req.getPeriode());

        ClotureComptable cloture = ClotureComptable.builder()
                .periode(req.getPeriode())
                .libelle(req.getLibelle() != null && !req.getLibelle().isBlank() ? req.getLibelle() : "Arrêté Mensuel " + req.getPeriode())
                .dateDebut(req.getDateDebut())
                .dateFin(req.getDateFin())
                .dateCloture(Instant.now())
                .cloturePar(utilisateur)
                .chiffreAffairesTtc(synthese.getChiffreAffairesTtc())
                .chiffreAffairesHt(synthese.getChiffreAffairesHt())
                .totalTvaCollectee(synthese.getTotalTvaCollectee())
                .totalAchatsHt(synthese.getTotalAchatsHt())
                .totalDepensesCaisse(synthese.getTotalDepensesCaisse())
                .totalEntreesCaisse(synthese.getTotalEntreesCaisse())
                .margeBruteEstimee(synthese.getMargeBruteEstimee())
                .valeurStockFinPeriode(synthese.getValeurStockFinPeriode())
                .totalCreancesClients(synthese.getTotalCreancesClients())
                .totalDettesFournisseurs(synthese.getTotalDettesFournisseurs())
                .soldeCaisseFinal(synthese.getSoldeCaisseFinal())
                .statut("VERROUILLE")
                .notes(req.getNotes())
                .build();

        cloture = clotureRepository.save(cloture);
        log.info("Clôture comptable validée et verrouillée pour la période {}: CA TTC = {} FCFA par {}",
                cloture.getPeriode(), cloture.getChiffreAffairesTtc(), userEmail);

        return cloture;
    }

    @Transactional(readOnly = true)
    public List<ClotureComptable> getHistoriqueClotures() {
        return clotureRepository.findAllByOrderByDateClotureDesc();
    }

    // =================== RAPPORTS SIMPLES ===================

    @Transactional(readOnly = true)
    public Map<String, Object> getRapportPeriode(LocalDate debut, LocalDate fin) {
        BigDecimal totalEntrees = caisseRepository.sumByTypeAndPeriode(TypeCaisse.ENTREE, debut, fin);
        BigDecimal totalSorties = caisseRepository.sumByTypeAndPeriode(TypeCaisse.SORTIE, debut, fin);
        if (totalEntrees == null) totalEntrees = BigDecimal.ZERO;
        if (totalSorties == null) totalSorties = BigDecimal.ZERO;
        BigDecimal solde = totalEntrees.subtract(totalSorties);

        return Map.of(
                "debut", debut.toString(),
                "fin", fin.toString(),
                "totalEntrees", totalEntrees,
                "totalSorties", totalSorties,
                "solde", solde
        );
    }
}

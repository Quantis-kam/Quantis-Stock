package com.quantis.stock.service;

import com.quantis.stock.dto.FermerCaisseRequest;
import com.quantis.stock.dto.OuvrirCaisseRequest;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.Depot;
import com.quantis.stock.model.SessionCaisse;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.model.enums.StatutSessionCaisse;
import com.quantis.stock.repository.DepotRepository;
import com.quantis.stock.repository.SessionCaisseRepository;
import com.quantis.stock.repository.UtilisateurRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class SessionCaisseService {

    private final SessionCaisseRepository sessionCaisseRepository;
    private final UtilisateurRepository utilisateurRepository;
    private final DepotRepository depotRepository;
    private final AuditService auditService;
    private final com.quantis.stock.security.SecurityUtils securityUtils;

    @Transactional
    public SessionCaisse ouvrirSession(String userEmail, OuvrirCaisseRequest request) {
        Utilisateur caissier = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        // Vérifier si une session est déjà ouverte pour ce caissier
        Optional<SessionCaisse> sessionExistante = sessionCaisseRepository
                .findByCaissierIdAndStatut(caissier.getId(), StatutSessionCaisse.OUVERTE);

        if (sessionExistante.isPresent()) {
            throw new BusinessException("Une session de caisse est déjà ouverte pour cet utilisateur");
        }

        Depot depot = null;
        if (request.getDepotId() != null) {
            depot = depotRepository.findById(request.getDepotId())
                    .orElseThrow(() -> new ResourceNotFoundException("Dépôt", "id", request.getDepotId()));
        } else if (caissier.getDepot() != null) {
            depot = caissier.getDepot();
        } else {
            Long entId = caissier.getEntreprise() != null ? caissier.getEntreprise().getId() : null;
            depot = (entId != null ? depotRepository.findByEntrepriseIdAndEstActifTrue(entId) : depotRepository.findByEstActifTrue())
                    .stream().findFirst()
                    .orElseThrow(() -> new BusinessException("Aucun dépôt disponible pour votre entreprise"));
        }

        BigDecimal fond = request.getFondCaisseOuverture() != null ? request.getFondCaisseOuverture() : BigDecimal.ZERO;

        SessionCaisse session = SessionCaisse.builder()
                .caissier(caissier)
                .depot(depot)
                .entreprise(caissier.getEntreprise())
                .statut(StatutSessionCaisse.OUVERTE)
                .dateOuverture(Instant.now())
                .fondCaisseOuverture(fond)
                .totalEntrees(BigDecimal.ZERO)
                .totalSorties(BigDecimal.ZERO)
                .soldeTheorique(fond)
                .notes(request.getNotes())
                .build();

        SessionCaisse saved = sessionCaisseRepository.save(session);
        auditService.logAction("OUVERTURE_CAISSE", "SessionCaisse", saved.getId(),
                "Ouverture caisse par " + userEmail + " avec fond de " + fond + " FCFA");

        return saved;
    }

    @Transactional
    public SessionCaisse fermerSession(String userEmail, FermerCaisseRequest request) {
        Utilisateur caissier = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));

        SessionCaisse session = sessionCaisseRepository
                .findByCaissierIdAndStatut(caissier.getId(), StatutSessionCaisse.OUVERTE)
                .orElseThrow(() -> new BusinessException("Aucune session de caisse ouverte trouvée pour cet utilisateur"));

        session.recalculerSoldeTheorique();
        BigDecimal soldeCompte = request.getSoldeCompte() != null ? request.getSoldeCompte() : BigDecimal.ZERO;
        BigDecimal ecart = soldeCompte.subtract(session.getSoldeTheorique());

        session.setSoldeCompte(soldeCompte);
        session.setEcart(ecart);
        session.setDateFermeture(Instant.now());
        session.setStatut(StatutSessionCaisse.FERMEE);
        if (request.getNotes() != null && !request.getNotes().isEmpty()) {
            session.setNotes((session.getNotes() != null ? session.getNotes() + " | " : "") + request.getNotes());
        }

        SessionCaisse closed = sessionCaisseRepository.save(session);
        auditService.logAction("FERMETURE_CAISSE", "SessionCaisse", closed.getId(),
                "Fermeture caisse par " + userEmail + " — Théorique: " + closed.getSoldeTheorique() +
                ", Compté: " + soldeCompte + ", Écart: " + ecart + " FCFA");

        return closed;
    }

    @Transactional(readOnly = true)
    public Optional<SessionCaisse> getSessionActive(String userEmail) {
        Utilisateur caissier = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));
        return sessionCaisseRepository.findByCaissierIdAndStatut(caissier.getId(), StatutSessionCaisse.OUVERTE);
    }

    @Transactional
    public void imputerMouvement(SessionCaisse session, BigDecimal montant, com.quantis.stock.model.enums.TypeCaisse type) {
        if (session == null || montant == null) return;
        if (type == com.quantis.stock.model.enums.TypeCaisse.ENTREE) {
            session.setTotalEntrees(session.getTotalEntrees().add(montant));
        } else if (type == com.quantis.stock.model.enums.TypeCaisse.SORTIE) {
            session.setTotalSorties(session.getTotalSorties().add(montant));
        }
        session.recalculerSoldeTheorique();
        sessionCaisseRepository.save(session);
    }

    @Transactional(readOnly = true)
    public Page<SessionCaisse> findAll(Pageable pageable) {
        if (securityUtils.isSuperAdmin()) {
            return sessionCaisseRepository.findAll(pageable);
        }
        Long entId = securityUtils.getCurrentEntrepriseId();
        return entId != null ? sessionCaisseRepository.findByEntrepriseId(entId, pageable) : Page.empty(pageable);
    }
}

package com.quantis.stock.service;

import com.quantis.stock.dto.DemandeEntrepriseRequest;
import com.quantis.stock.dto.EntrepriseRequest;
import com.quantis.stock.dto.PlatformAdminDto.*;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.DemandeEntreprise;
import com.quantis.stock.model.Depot;
import com.quantis.stock.model.Entreprise;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.model.enums.Role;
import com.quantis.stock.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class PlatformAdminService {

    private final EntrepriseRepository entrepriseRepository;
    private final UtilisateurRepository utilisateurRepository;
    private final DepotRepository depotRepository;
    private final ProduitRepository produitRepository;
    private final DocumentRepository documentRepository;
    private final CommandeFournisseurRepository commandeFournisseurRepository;
    private final MouvementCaisseRepository mouvementCaisseRepository;
    private final ClientRepository clientRepository;
    private final FournisseurRepository fournisseurRepository;
    private final DemandeEntrepriseRepository demandeEntrepriseRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuditService auditService;

    @Transactional(readOnly = true)
    public PlatformStatsDto getStats() {
        List<Entreprise> all = entrepriseRepository.findAll();
        long total = all.size();
        long actives = all.stream().filter(e -> Boolean.TRUE.equals(e.getEstActif())).count();
        long suspendues = total - actives;
        long users = utilisateurRepository.count();
        long docs = documentRepository.count();
        long prods = produitRepository.count();

        // Calculs financiers consolidés plateforme
        java.math.BigDecimal globalCa = documentRepository.sumGlobalCa();
        java.math.BigDecimal globalCaisseEntrees = mouvementCaisseRepository.sumByType(com.quantis.stock.model.enums.TypeCaisse.ENTREE);
        if (globalCa.compareTo(java.math.BigDecimal.ZERO) == 0 && globalCaisseEntrees.compareTo(java.math.BigDecimal.ZERO) > 0) {
            globalCa = globalCaisseEntrees;
        }
        java.math.BigDecimal globalAchats = commandeFournisseurRepository.sumGlobalAchats();
        java.math.BigDecimal globalMarge = globalCa.subtract(globalAchats);
        long globalVentes = documentRepository.countGlobalVentes();
        long globalAchatsCount = commandeFournisseurRepository.countGlobalAchats();

        return PlatformStatsDto.builder()
                .totalEntreprises(total)
                .entreprisesActives(actives)
                .entreprisesSuspendues(suspendues)
                .totalUtilisateurs(users)
                .totalDocuments(docs)
                .totalProduits(prods)
                .chiffreAffairesGlobal(globalCa)
                .totalAchatsGlobal(globalAchats)
                .margeGlobale(globalMarge)
                .totalVentesCount(globalVentes)
                .totalAchatsCount(globalAchatsCount)
                .demandesEnAttente(demandeEntrepriseRepository.countByStatut("EN_ATTENTE"))
                .build();
    }

    @Transactional(readOnly = true)
    public List<EntrepriseListItemDto> getAllEntreprises() {
        return entrepriseRepository.findAll().stream()
                .sorted((a, b) -> b.getId().compareTo(a.getId()))
                .map(this::toListItemDto)
                .collect(Collectors.toList());
    }

    @Transactional
    public EntrepriseListItemDto createEntreprise(EntrepriseCreateRequest request) {
        if (utilisateurRepository.existsByEmail(request.getAdminEmail())) {
            throw new BusinessException("Un utilisateur avec l'email '" + request.getAdminEmail() + "' existe déjà.");
        }

        // 1. Création de l'entreprise avec décompte d'abonnement automatique dès le jour de création (+1 mois)
        // ou date personnalisée par le Super-Admin
        java.time.LocalDate today = java.time.LocalDate.now();
        java.time.LocalDate dateExpiration = (request.getDateExpirationLicence() != null && !request.getDateExpirationLicence().isBlank())
                ? java.time.LocalDate.parse(request.getDateExpirationLicence().trim())
                : today.plusMonths(1);
        double montantAbonnement = (request.getMontantAbonnement() != null && request.getMontantAbonnement() > 0)
                ? request.getMontantAbonnement()
                : Entreprise.DEFAULT_MONTANT_ABONNEMENT;
        String codeUssd = "*144*2*1*65189261*" + Math.round(montantAbonnement) + "#";
        String statutLicence = dateExpiration.isBefore(today) ? "EXPIREE" : "ACTIVE";

        Entreprise entreprise = Entreprise.builder()
                .nom(request.getNom())
                .nif(request.getNif())
                .rccm(request.getRccm())
                .telephone(request.getTelephone())
                .email(request.getEmail())
                .adresse(request.getAdresse())
                .monnaie(request.getMonnaie() != null && !request.getMonnaie().isBlank() ? request.getMonnaie() : "FCFA")
                .formatFacture(request.getFormatFacture() != null && !request.getFormatFacture().isBlank() ? request.getFormatFacture() : "FAC-{YYYY}-{NNNNN}")
                .estActif(true)
                .dateExpirationLicence(dateExpiration)
                .statutLicence(statutLicence)
                .montantAbonnement(montantAbonnement)
                .codeUssdRenouvellement(codeUssd)
                .build();
        entreprise = entrepriseRepository.save(entreprise);

        // 2. Création d'un dépôt principal pour l'entreprise
        Depot depot = Depot.builder()
                .nom("Dépôt Principal")
                .adresse(request.getAdresse() != null ? request.getAdresse() : request.getNom())
                .telephone(request.getTelephone())
                .entreprise(entreprise)
                .estActif(true)
                .build();
        depot = depotRepository.save(depot);

        // 3. Création de l'administrateur de l'entreprise
        Utilisateur admin = Utilisateur.builder()
                .nom(request.getAdminNom())
                .prenom(request.getAdminPrenom())
                .email(request.getAdminEmail())
                .motDePasseHash(passwordEncoder.encode(request.getAdminMotDePasse()))
                .role(Role.ADMIN)
                .depot(depot)
                .entreprise(entreprise)
                .actif(true)
                .build();
        utilisateurRepository.save(admin);

        auditService.logAction("CREATE", "Entreprise", entreprise.getId(),
                "Création plateforme de l'entreprise " + entreprise.getNom() + " avec admin " + admin.getEmail());

        log.info("Nouvelle entreprise créée sur la plateforme: {} (ID: {}, Admin: {})",
                entreprise.getNom(), entreprise.getId(), admin.getEmail());

        return toListItemDto(entreprise);
    }

    @Transactional
    public EntrepriseListItemDto updateEntreprise(Long id, EntrepriseRequest request) {
        Entreprise entreprise = entrepriseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Entreprise", "id", id));

        entreprise.setNom(request.getNom());
        if (request.getNif() != null) entreprise.setNif(request.getNif());
        if (request.getRccm() != null) entreprise.setRccm(request.getRccm());
        if (request.getTelephone() != null) entreprise.setTelephone(request.getTelephone());
        if (request.getEmail() != null) entreprise.setEmail(request.getEmail());
        if (request.getAdresse() != null) entreprise.setAdresse(request.getAdresse());
        if (request.getLogoUrl() != null) entreprise.setLogoUrl(request.getLogoUrl());
        if (request.getMonnaie() != null) entreprise.setMonnaie(request.getMonnaie());
        if (request.getFormatFacture() != null) entreprise.setFormatFacture(request.getFormatFacture());

        entreprise = entrepriseRepository.save(entreprise);
        auditService.logAction("UPDATE", "Entreprise", entreprise.getId(),
                "Modification par Super Admin de l'entreprise " + entreprise.getNom());

        return toListItemDto(entreprise);
    }

    @Transactional
    public EntrepriseListItemDto toggleStatus(Long id) {
        Entreprise entreprise = entrepriseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Entreprise", "id", id));

        boolean newStatus = !Boolean.TRUE.equals(entreprise.getEstActif());
        entreprise.setEstActif(newStatus);
        entreprise = entrepriseRepository.save(entreprise);

        String action = newStatus ? "Réactivation" : "Suspension";
        auditService.logAction("STATUS_CHANGE", "Entreprise", entreprise.getId(),
                action + " de l'accès entreprise " + entreprise.getNom());

        log.info("{} de l'entreprise {} (ID: {}) par Super Admin", action, entreprise.getNom(), entreprise.getId());
        return toListItemDto(entreprise);
    }

    @Transactional(readOnly = true)
    public List<Utilisateur> getEntrepriseUsers(Long entrepriseId) {
        return utilisateurRepository.findByEntrepriseId(entrepriseId);
    }

    @Transactional
    public void resetAdminPassword(Long entrepriseId, String newPassword) {
        Utilisateur admin = utilisateurRepository.findFirstByEntrepriseIdAndRole(entrepriseId, Role.ADMIN)
                .orElseThrow(() -> new ResourceNotFoundException("Administrateur pour entreprise", "entrepriseId", entrepriseId));

        admin.setMotDePasseHash(passwordEncoder.encode(newPassword));
        utilisateurRepository.save(admin);

        auditService.logAction("PASSWORD_RESET", "Utilisateur", admin.getId(),
                "Réinitialisation mot de passe admin pour l'entreprise ID " + entrepriseId);
    }

    @Transactional(readOnly = true)
    public EntrepriseSupervisionDto getEntrepriseSupervision(Long entrepriseId) {
        Entreprise e = entrepriseRepository.findById(entrepriseId)
                .orElseThrow(() -> new ResourceNotFoundException("Entreprise", "id", entrepriseId));

        java.math.BigDecimal ca = documentRepository.sumCaByEntrepriseId(e.getId());
        java.math.BigDecimal caisseEntrees = mouvementCaisseRepository.sumEntreesByEntrepriseId(e.getId());
        java.math.BigDecimal caisseSorties = mouvementCaisseRepository.sumSortiesByEntrepriseId(e.getId());
        java.math.BigDecimal soldeCaisse = caisseEntrees.subtract(caisseSorties);
        if (ca.compareTo(java.math.BigDecimal.ZERO) == 0 && caisseEntrees.compareTo(java.math.BigDecimal.ZERO) > 0) {
            ca = caisseEntrees;
        }
        java.math.BigDecimal achats = commandeFournisseurRepository.sumAchatsByEntrepriseId(e.getId());
        java.math.BigDecimal marge = ca.subtract(achats);
        long ventesCount = documentRepository.countVentesByEntrepriseId(e.getId());
        long achatsCount = commandeFournisseurRepository.countAchatsByEntrepriseId(e.getId());
        long clientsCount = clientRepository.countByEntrepriseId(e.getId());
        long fournisseursCount = fournisseurRepository.countByEntrepriseId(e.getId());
        long prodsCount = produitRepository.countByEntrepriseId(e.getId());
        long usersCount = utilisateurRepository.countByEntrepriseId(e.getId());

        List<DocumentSummaryDto> dernieresVentes = documentRepository.findTop5ByEntrepriseIdOrderByCreatedAtDesc(e.getId()).stream()
                .map(d -> DocumentSummaryDto.builder()
                        .id(d.getId())
                        .numero(d.getNumero())
                        .clientNom(d.getClient() != null ? d.getClient().getNom() : "Client Comptoir")
                        .type(d.getType().name())
                        .statut(d.getStatut().name())
                        .totalTtc(d.getTotalTtc())
                        .date(d.getDateDocument() != null ? d.getDateDocument().toString() : (d.getCreatedAt() != null ? d.getCreatedAt().toString() : ""))
                        .build())
                .collect(Collectors.toList());

        List<AchatSummaryDto> derniersAchats = commandeFournisseurRepository.findTop5ByDepotEntrepriseIdOrderByCreatedAtDesc(e.getId()).stream()
                .map(c -> AchatSummaryDto.builder()
                        .id(c.getId())
                        .numero(c.getNumero())
                        .fournisseurNom(c.getFournisseur() != null ? c.getFournisseur().getNom() : "Fournisseur Direct")
                        .statut(c.getStatut().name())
                        .totalHt(c.getTotalHt())
                        .date(c.getDateCommande() != null ? c.getDateCommande().toString() : (c.getCreatedAt() != null ? c.getCreatedAt().toString() : ""))
                        .build())
                .collect(Collectors.toList());

        java.time.LocalDate expDate = e.getDateExpirationLicence();
        boolean isValide = e.isLicenceValide();
        Long joursRestants = expDate != null ? java.time.temporal.ChronoUnit.DAYS.between(java.time.LocalDate.now(), expDate) : null;
        String statutLicence = e.getStatutLicence();
        if (statutLicence == null) {
            statutLicence = isValide ? "ACTIVE" : "EXPIREE";
        } else if (!isValide && !"SUSPENDUE".equalsIgnoreCase(statutLicence)) {
            statutLicence = "EXPIREE";
        }

        return EntrepriseSupervisionDto.builder()
                .entrepriseId(e.getId())
                .entrepriseNom(e.getNom())
                .monnaie(e.getMonnaie())
                .chiffreAffaires(ca)
                .totalAchats(achats)
                .margeBrute(marge)
                .soldeCaisse(soldeCaisse)
                .ventesCount(ventesCount)
                .achatsCount(achatsCount)
                .clientsCount(clientsCount)
                .fournisseursCount(fournisseursCount)
                .produitsCount(prodsCount)
                .utilisateursCount(usersCount)
                .dernieresVentes(dernieresVentes)
                .derniersAchats(derniersAchats)
                .dateExpirationLicence(expDate)
                .statutLicence(statutLicence)
                .isLicenceValide(isValide)
                .joursRestantsLicence(joursRestants)
                .montantAbonnement(e.getMontantAbonnement())
                .codeUssdRenouvellement(e.getCodeUssdRenouvellement())
                .build();
    }

    @Transactional
    public EntrepriseListItemDto renewLicence(Long id, LicenceRenewalRequest request) {
        Entreprise entreprise = entrepriseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Entreprise", "id", id));

        int nbMois = (request != null && request.getNbMois() != null && request.getNbMois() > 0) ? request.getNbMois() : 1;
        java.time.LocalDate today = java.time.LocalDate.now();
        java.time.LocalDate nouvelleDate;

        if (request != null && request.getNouvelleDateExpiration() != null && !request.getNouvelleDateExpiration().isBlank()) {
            nouvelleDate = java.time.LocalDate.parse(request.getNouvelleDateExpiration().trim());
        } else {
            java.time.LocalDate baseDate = entreprise.getDateExpirationLicence();
            if (baseDate == null || baseDate.isBefore(today)) {
                baseDate = today;
            }
            nouvelleDate = baseDate.plusMonths(nbMois);
        }

        if (request != null && request.getMontantAbonnement() != null && request.getMontantAbonnement() > 0) {
            entreprise.setMontantAbonnement(request.getMontantAbonnement());
            entreprise.setCodeUssdRenouvellement("*144*2*1*65189261*" + Math.round(request.getMontantAbonnement()) + "#");
        }

        boolean expiree = nouvelleDate.isBefore(today);
        entreprise.setDateExpirationLicence(nouvelleDate);
        entreprise.setStatutLicence(expiree ? "EXPIREE" : "ACTIVE");
        if (!expiree) {
            entreprise.setEstActif(true);
        }
        entreprise = entrepriseRepository.save(entreprise);

        long tarifMensuel = Math.round(entreprise.getMontantAbonnement() != null
                ? entreprise.getMontantAbonnement()
                : Entreprise.DEFAULT_MONTANT_ABONNEMENT);
        String ussd = entreprise.getCodeUssdRenouvellement() != null
                ? entreprise.getCodeUssdRenouvellement()
                : Entreprise.DEFAULT_CODE_USSD;
        String ref = (request != null && request.getReferencePaiement() != null && !request.getReferencePaiement().isBlank())
                ? request.getReferencePaiement()
                : "Paiement USSD " + ussd + " (" + tarifMensuel + " FCFA)";

        auditService.logAction("LICENCE_RENEWAL", "Entreprise", entreprise.getId(),
                "Mise à jour licence de l'entreprise " + entreprise.getNom() + " jusqu'au " + nouvelleDate + " (Ref: " + ref + ")");

        log.info("Licence de l'entreprise {} (ID: {}) renouvelée jusqu'au {} par Super Admin",
                entreprise.getNom(), entreprise.getId(), nouvelleDate);

        return toListItemDto(entreprise);
    }

    @Transactional
    public EntrepriseListItemDto expireLicence(Long id) {
        Entreprise entreprise = entrepriseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Entreprise", "id", id));

        entreprise.setDateExpirationLicence(java.time.LocalDate.now().minusDays(1));
        entreprise.setStatutLicence("EXPIREE");
        entreprise = entrepriseRepository.save(entreprise);

        auditService.logAction("LICENCE_EXPIRE", "Entreprise", entreprise.getId(),
                "Marquage manuel licence expirée pour " + entreprise.getNom());

        return toListItemDto(entreprise);
    }

    // =================== DEMANDES PUBLIQUES D'OUVERTURE D'ENTREPRISE ===================

    @Transactional
    public DemandeEntreprise submitDemandeEntreprise(DemandeEntrepriseRequest request) {
        String canal = (request.getCanalContact() != null && !request.getCanalContact().isBlank())
                ? request.getCanalContact().trim().toUpperCase()
                : "WHATSAPP";
        if (!canal.equals("WHATSAPP") && !canal.equals("EMAIL") && !canal.equals("FORMULAIRE")) {
            canal = "FORMULAIRE";
        }

        DemandeEntreprise demande = DemandeEntreprise.builder()
                .nomEntreprise(request.getNomEntreprise().trim())
                .secteurActivite(request.getSecteurActivite() != null ? request.getSecteurActivite().trim() : null)
                .ville(request.getVille() != null ? request.getVille().trim() : null)
                .nomResponsable(request.getNomResponsable().trim())
                .telephone(request.getTelephone().trim())
                .email(request.getEmail().trim().toLowerCase())
                .message(request.getMessage() != null ? request.getMessage().trim() : null)
                .canalContact(canal)
                .statut("EN_ATTENTE")
                .build();
        demande = demandeEntrepriseRepository.save(demande);

        log.info("Nouvelle demande d'ouverture d'entreprise reçue: {} (Responsable: {}, Tél: {}, Canal: {})",
                demande.getNomEntreprise(), demande.getNomResponsable(), demande.getTelephone(), canal);
        return demande;
    }

    @Transactional(readOnly = true)
    public List<DemandeEntreprise> getAllDemandesEntreprises() {
        return demandeEntrepriseRepository.findAllByOrderByCreatedAtDesc();
    }

    @Transactional
    public DemandeEntreprise updateDemandeStatus(Long id, DemandeStatusUpdateRequest request) {
        DemandeEntreprise demande = demandeEntrepriseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("DemandeEntreprise", "id", id));

        if (request != null && request.getStatut() != null && !request.getStatut().isBlank()) {
            String statut = request.getStatut().trim().toUpperCase();
            if (!statut.equals("EN_ATTENTE") && !statut.equals("TRAITEE") && !statut.equals("REJETEE")) {
                throw new BusinessException("Statut de demande invalide : " + statut);
            }
            demande.setStatut(statut);
        }
        if (request != null && request.getEntrepriseCreeeId() != null) {
            demande.setEntrepriseCreeeId(request.getEntrepriseCreeeId());
            if ("EN_ATTENTE".equals(demande.getStatut())) {
                demande.setStatut("TRAITEE");
            }
        }
        if (request != null && request.getNoteAdmin() != null) {
            demande.setNoteAdmin(request.getNoteAdmin().trim());
        }

        demande = demandeEntrepriseRepository.save(demande);
        auditService.logAction("LEAD_STATUS", "DemandeEntreprise", demande.getId(),
                "Demande " + demande.getNomEntreprise() + " marquée " + demande.getStatut());
        return demande;
    }

    private EntrepriseListItemDto toListItemDto(Entreprise e) {
        long userCount = utilisateurRepository.countByEntrepriseId(e.getId());
        long prodCount = produitRepository.countByEntrepriseId(e.getId());
        long docCount = documentRepository.countByEntrepriseId(e.getId());
        String adminEmail = utilisateurRepository.findFirstByEntrepriseIdAndRole(e.getId(), Role.ADMIN)
                .map(Utilisateur::getEmail)
                .orElse("Non configuré");

        // Supervision Financière de l'Entreprise
        java.math.BigDecimal ca = documentRepository.sumCaByEntrepriseId(e.getId());
        java.math.BigDecimal caisseEntrees = mouvementCaisseRepository.sumEntreesByEntrepriseId(e.getId());
        java.math.BigDecimal caisseSorties = mouvementCaisseRepository.sumSortiesByEntrepriseId(e.getId());
        java.math.BigDecimal soldeCaisse = caisseEntrees.subtract(caisseSorties);
        if (ca.compareTo(java.math.BigDecimal.ZERO) == 0 && caisseEntrees.compareTo(java.math.BigDecimal.ZERO) > 0) {
            ca = caisseEntrees;
        }
        java.math.BigDecimal achats = commandeFournisseurRepository.sumAchatsByEntrepriseId(e.getId());
        java.math.BigDecimal marge = ca.subtract(achats);
        long ventesCount = documentRepository.countVentesByEntrepriseId(e.getId());
        long achatsCount = commandeFournisseurRepository.countAchatsByEntrepriseId(e.getId());

        java.time.LocalDate expDate = e.getDateExpirationLicence();
        boolean isValide = e.isLicenceValide();
        Long joursRestants = expDate != null ? java.time.temporal.ChronoUnit.DAYS.between(java.time.LocalDate.now(), expDate) : null;
        String statutLicence = e.getStatutLicence();
        if (statutLicence == null) {
            statutLicence = isValide ? "ACTIVE" : "EXPIREE";
        } else if (!isValide && !"SUSPENDUE".equalsIgnoreCase(statutLicence)) {
            statutLicence = "EXPIREE";
        }

        return EntrepriseListItemDto.builder()
                .id(e.getId())
                .nom(e.getNom())
                .nif(e.getNif())
                .rccm(e.getRccm())
                .telephone(e.getTelephone())
                .email(e.getEmail())
                .adresse(e.getAdresse())
                .monnaie(e.getMonnaie())
                .formatFacture(e.getFormatFacture())
                .logoUrl(e.getLogoUrl())
                .estActif(e.getEstActif())
                .createdAt(e.getCreatedAt())
                .userCount(userCount)
                .productCount(prodCount)
                .documentCount(docCount)
                .adminEmail(adminEmail)
                .chiffreAffaires(ca)
                .totalAchats(achats)
                .margeBrute(marge)
                .ventesCount(ventesCount)
                .achatsCount(achatsCount)
                .soldeCaisse(soldeCaisse)
                .dateExpirationLicence(expDate)
                .statutLicence(statutLicence)
                .isLicenceValide(isValide)
                .joursRestantsLicence(joursRestants)
                .montantAbonnement(e.getMontantAbonnement())
                .codeUssdRenouvellement(e.getCodeUssdRenouvellement())
                .build();
    }
}

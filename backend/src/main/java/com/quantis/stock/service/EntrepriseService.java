package com.quantis.stock.service;

import com.quantis.stock.dto.EntrepriseRequest;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.Entreprise;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.repository.EntrepriseRepository;
import com.quantis.stock.repository.UtilisateurRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class EntrepriseService {

    private final EntrepriseRepository entrepriseRepository;
    private final UtilisateurRepository utilisateurRepository;
    private final AuditService auditService;

    @Transactional(readOnly = true)
    public Entreprise getEntrepriseCourante(String userEmail) {
        if (userEmail != null) {
            Utilisateur user = utilisateurRepository.findByEmail(userEmail).orElse(null);
            if (user != null && user.getEntreprise() != null) {
                return user.getEntreprise();
            }
        }
        return entrepriseRepository.findAll().stream().findFirst()
                .orElseGet(() -> entrepriseRepository.save(Entreprise.builder()
                        .nom("Quantis SARL")
                        .monnaie("FCFA")
                        .formatFacture("FAC-{YYYY}-{NNNNN}")
                        .estActif(true)
                        .build()));
    }

    @Transactional
    public Entreprise updateEntreprise(EntrepriseRequest request, String userEmail) {
        Entreprise entreprise = getEntrepriseCourante(userEmail);

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
        log.info("Profil Entreprise mis à jour: {} (logoUrl: {})", entreprise.getNom(), entreprise.getLogoUrl() != null ? "défini" : "aucun");
        auditService.logAction("UPDATE", "Entreprise", entreprise.getId(), "Mise à jour du profil d'entreprise " + entreprise.getNom());

        return entreprise;
    }

    @Transactional(readOnly = true)
    public Entreprise getById(Long id) {
        return entrepriseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Entreprise", "id", id));
    }
}

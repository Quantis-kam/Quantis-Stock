package com.quantis.stock.service;

import com.quantis.stock.dto.PlatformAdminDto.EntrepriseCreateRequest;
import com.quantis.stock.dto.PlatformAdminDto.EntrepriseListItemDto;
import com.quantis.stock.dto.PlatformAdminDto.LicenceRenewalRequest;
import com.quantis.stock.model.Depot;
import com.quantis.stock.model.Entreprise;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.repository.*;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@DisplayName("Tests Abonnement 10 100 FCFA, décompte dès création et personnalisation date Super-Admin")
class SubscriptionLicenceTest {

    @Mock private EntrepriseRepository entrepriseRepository;
    @Mock private UtilisateurRepository utilisateurRepository;
    @Mock private DepotRepository depotRepository;
    @Mock private ProduitRepository produitRepository;
    @Mock private DocumentRepository documentRepository;
    @Mock private CommandeFournisseurRepository commandeFournisseurRepository;
    @Mock private MouvementCaisseRepository mouvementCaisseRepository;
    @Mock private ClientRepository clientRepository;
    @Mock private FournisseurRepository fournisseurRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private AuditService auditService;

    @InjectMocks
    private PlatformAdminService platformAdminService;

    private void stubMetricsDefaults() {
        when(documentRepository.sumCaByEntrepriseId(anyLong())).thenReturn(BigDecimal.ZERO);
        when(mouvementCaisseRepository.sumEntreesByEntrepriseId(anyLong())).thenReturn(BigDecimal.ZERO);
        when(mouvementCaisseRepository.sumSortiesByEntrepriseId(anyLong())).thenReturn(BigDecimal.ZERO);
        when(commandeFournisseurRepository.sumAchatsByEntrepriseId(anyLong())).thenReturn(BigDecimal.ZERO);
    }

    @Test
    @DisplayName("Création d'entreprise lance automatiquement le décompte d'1 mois dès aujourd'hui à 10 100 FCFA")
    void createEntrepriseStartsOneMonthCountdownAutomaticallyAt10100() {
        stubMetricsDefaults();
        when(utilisateurRepository.existsByEmail("patron@boutique.bf")).thenReturn(false);
        when(passwordEncoder.encode("Pass1234")).thenReturn("hashed");
        when(entrepriseRepository.save(any(Entreprise.class))).thenAnswer(inv -> {
            Entreprise e = inv.getArgument(0);
            if (e.getId() == null) e.setId(42L);
            return e;
        });
        when(depotRepository.save(any(Depot.class))).thenAnswer(inv -> {
            Depot d = inv.getArgument(0);
            d.setId(1L);
            return d;
        });
        when(utilisateurRepository.save(any(Utilisateur.class))).thenAnswer(inv -> inv.getArgument(0));
        when(utilisateurRepository.findFirstByEntrepriseIdAndRole(anyLong(), any())).thenReturn(Optional.empty());

        EntrepriseCreateRequest req = EntrepriseCreateRequest.builder()
                .nom("Boutique Faso")
                .adminNom("Sawadogo")
                .adminPrenom("Moussa")
                .adminEmail("patron@boutique.bf")
                .adminMotDePasse("Pass1234")
                .build();

        EntrepriseListItemDto dto = platformAdminService.createEntreprise(req);

        LocalDate expectedExp = LocalDate.now().plusMonths(1);
        assertThat(dto.getDateExpirationLicence()).isEqualTo(expectedExp);
        assertThat(dto.getStatutLicence()).isEqualTo("ACTIVE");
        assertThat(dto.getIsLicenceValide()).isTrue();
        assertThat(dto.getJoursRestantsLicence()).isGreaterThanOrEqualTo(28L);
        assertThat(dto.getMontantAbonnement()).isEqualTo(10100.0);
        assertThat(dto.getCodeUssdRenouvellement()).isEqualTo("*144*2*1*65189261*10100#");
    }

    @Test
    @DisplayName("Super-Admin peut définir une date d'expiration personnalisée (future ou passée) et prolonger d'1 mois exact")
    void renewLicenceSupportsCustomDateAndExactMonthAnniversary() {
        stubMetricsDefaults();
        LocalDate initialExp = LocalDate.now().plusDays(10);
        Entreprise ent = Entreprise.builder()
                .id(77L)
                .nom("Alimentation Test")
                .estActif(true)
                .dateExpirationLicence(initialExp)
                .statutLicence("ACTIVE")
                .montantAbonnement(10100.0)
                .codeUssdRenouvellement("*144*2*1*65189261*10100#")
                .build();

        when(entrepriseRepository.findById(77L)).thenReturn(Optional.of(ent));
        when(entrepriseRepository.save(any(Entreprise.class))).thenAnswer(inv -> inv.getArgument(0));
        when(utilisateurRepository.findFirstByEntrepriseIdAndRole(anyLong(), any())).thenReturn(Optional.empty());

        // 1. Prolongation +1 mois conserve l'anniversaire exact (sans forcer fin de mois)
        LicenceRenewalRequest plusOneMonth = new LicenceRenewalRequest();
        plusOneMonth.setNbMois(1);
        EntrepriseListItemDto afterPlusOne = platformAdminService.renewLicence(77L, plusOneMonth);
        assertThat(afterPlusOne.getDateExpirationLicence()).isEqualTo(initialExp.plusMonths(1));
        assertThat(afterPlusOne.getStatutLicence()).isEqualTo("ACTIVE");

        // 2. Date personnalisée choisie par le Super-Admin (ex: +45 jours)
        LocalDate customFuture = LocalDate.now().plusDays(45);
        LicenceRenewalRequest customReq = new LicenceRenewalRequest();
        customReq.setNouvelleDateExpiration(customFuture.toString());
        EntrepriseListItemDto afterCustom = platformAdminService.renewLicence(77L, customReq);
        assertThat(afterCustom.getDateExpirationLicence()).isEqualTo(customFuture);
        assertThat(afterCustom.getIsLicenceValide()).isTrue();

        // 3. Date personnalisée passée (correction / expiration manuelle)
        LocalDate customPast = LocalDate.now().minusDays(2);
        LicenceRenewalRequest pastReq = new LicenceRenewalRequest();
        pastReq.setNouvelleDateExpiration(customPast.toString());
        EntrepriseListItemDto afterPast = platformAdminService.renewLicence(77L, pastReq);
        assertThat(afterPast.getDateExpirationLicence()).isEqualTo(customPast);
        assertThat(afterPast.getStatutLicence()).isEqualTo("EXPIREE");
        assertThat(afterPast.getIsLicenceValide()).isFalse();
    }
}


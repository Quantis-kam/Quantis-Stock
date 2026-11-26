package com.quantis.stock.service;

import com.quantis.stock.dto.DemandeEntrepriseRequest;
import com.quantis.stock.dto.PlatformAdminDto.DemandeStatusUpdateRequest;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.model.DemandeEntreprise;
import com.quantis.stock.repository.*;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@DisplayName("Tests Demandes publiques de création d'entreprise")
class DemandeEntrepriseTest {

    @Mock private EntrepriseRepository entrepriseRepository;
    @Mock private UtilisateurRepository utilisateurRepository;
    @Mock private DepotRepository depotRepository;
    @Mock private ProduitRepository produitRepository;
    @Mock private DocumentRepository documentRepository;
    @Mock private CommandeFournisseurRepository commandeFournisseurRepository;
    @Mock private MouvementCaisseRepository mouvementCaisseRepository;
    @Mock private ClientRepository clientRepository;
    @Mock private FournisseurRepository fournisseurRepository;
    @Mock private DemandeEntrepriseRepository demandeEntrepriseRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private AuditService auditService;

    @InjectMocks
    private PlatformAdminService platformAdminService;

    @Test
    @DisplayName("Soumission d'une demande publique normalise les champs et crée un lead EN_ATTENTE")
    void submitDemandeCreatesPendingLead() {
        when(demandeEntrepriseRepository.save(any(DemandeEntreprise.class))).thenAnswer(inv -> {
            DemandeEntreprise d = inv.getArgument(0);
            d.setId(12L);
            return d;
        });

        DemandeEntrepriseRequest req = DemandeEntrepriseRequest.builder()
                .nomEntreprise("  Supermarché Horizon  ")
                .secteurActivite("Alimentation / Supérette")
                .ville("Ouagadougou")
                .nomResponsable("Amadou Compaoré")
                .telephone("+226 70 11 22 33")
                .email("  Horizon@Test.BF ")
                .canalContact("whatsapp")
                .message("Nous avons 2 dépôts.")
                .build();

        DemandeEntreprise saved = platformAdminService.submitDemandeEntreprise(req);

        assertThat(saved.getId()).isEqualTo(12L);
        assertThat(saved.getNomEntreprise()).isEqualTo("Supermarché Horizon");
        assertThat(saved.getEmail()).isEqualTo("horizon@test.bf");
        assertThat(saved.getCanalContact()).isEqualTo("WHATSAPP");
        assertThat(saved.getStatut()).isEqualTo("EN_ATTENTE");
    }

    @Test
    @DisplayName("Mise à jour de statut lie l'entreprise créée et passe automatiquement en TRAITEE")
    void updateDemandeStatusLinksCreatedEnterprise() {
        DemandeEntreprise existing = DemandeEntreprise.builder()
                .id(15L)
                .nomEntreprise("Quincaillerie Zongo")
                .nomResponsable("Paul Zongo")
                .telephone("70123456")
                .email("paul@zongo.bf")
                .statut("EN_ATTENTE")
                .build();

        when(demandeEntrepriseRepository.findById(15L)).thenReturn(Optional.of(existing));
        when(demandeEntrepriseRepository.save(any(DemandeEntreprise.class))).thenAnswer(inv -> inv.getArgument(0));

        DemandeStatusUpdateRequest upd = new DemandeStatusUpdateRequest(null, 99L, "Espace créé et envoyé sur WhatsApp");
        DemandeEntreprise result = platformAdminService.updateDemandeStatus(15L, upd);

        assertThat(result.getStatut()).isEqualTo("TRAITEE");
        assertThat(result.getEntrepriseCreeeId()).isEqualTo(99L);
        assertThat(result.getNoteAdmin()).isEqualTo("Espace créé et envoyé sur WhatsApp");

        DemandeStatusUpdateRequest invalid = new DemandeStatusUpdateRequest("INCONNU", null, null);
        assertThatThrownBy(() -> platformAdminService.updateDemandeStatus(15L, invalid))
                .isInstanceOf(BusinessException.class);
    }
}


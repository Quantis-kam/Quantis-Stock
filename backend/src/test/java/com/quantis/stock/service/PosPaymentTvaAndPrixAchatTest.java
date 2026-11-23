package com.quantis.stock.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.quantis.stock.dto.PosSaleRequest;
import com.quantis.stock.dto.PosSaleResponse;
import com.quantis.stock.dto.SolderCommandeRequest;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.model.*;
import com.quantis.stock.model.enums.MoyenPaiement;
import com.quantis.stock.model.enums.StatutDocument;
import com.quantis.stock.model.enums.TypeDocument;
import com.quantis.stock.repository.*;
import com.quantis.stock.security.SecurityUtils;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("Tests POS Paiements, TVA 0% et Entreprise sans TVA")
class PosPaymentTvaAndPrixAchatTest {

    @Mock private DocumentRepository documentRepository;
    @Mock private PaiementRepository paiementRepository;
    @Mock private ClientRepository clientRepository;
    @Mock private DepotRepository depotRepository;
    @Mock private ProduitRepository produitRepository;
    @Mock private VarianteProduitRepository varianteProduitRepository;
    @Mock private UtilisateurRepository utilisateurRepository;
    @Mock private StockService stockService;
    @Mock private ComptabiliteService comptabiliteService;
    @Mock private AuditService auditService;
    @Mock private EntrepriseRepository entrepriseRepository;
    @Mock private SecurityUtils securityUtils;

    @InjectMocks
    private DocumentService documentService;

    @Test
    @DisplayName("Jackson désérialise tous les modes de règlement du POS sans erreur")
    void allPosPaymentModesDeserializeCleanly() throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        for (String mode : List.of("ESPECES", "WAVE", "ORANGE_MONEY", "MOOV_MONEY", "CARTE_BANCAIRE", "CREDIT", "MOBILE_MONEY", "VIREMENT", "CHEQUE")) {
            String json = """
                {
                  "lignes": [{"produitId": 1, "quantite": 1, "prixUnitaire": 5000, "tauxTva": 0}],
                  "moyenPaiement": "%s",
                  "montantPaye": 5000
                }
                """.formatted(mode);
            PosSaleRequest req = mapper.readValue(json, PosSaleRequest.class);
            assertThat(req.getMoyenPaiement()).isEqualTo(MoyenPaiement.valueOf(mode));
        }
    }

    @Test
    @DisplayName("Vente POS avec Orange Money et entreprise TVA désactivée force 0% TVA")
    void posSaleWithOrangeMoneyAndTvaDisabledForcesZeroTva() {
        Entreprise ent = Entreprise.builder()
                .id(1L).nom("Boutique Test").monnaie("FCFA")
                .tvaActive(false).tauxTvaDefaut(BigDecimal.ZERO).suiviPrixAchat(false)
                .build();
        Depot depot = Depot.builder().id(10L).nom("Principal").entreprise(ent).build();
        Utilisateur user = Utilisateur.builder()
                .id(5L).nom("Diallo").prenom("Ali").email("ali@test.com")
                .entreprise(ent).depot(depot).build();
        Client client = Client.builder().id(20L).nom("Client Divers / Comptoir")
                .soldeCredit(BigDecimal.ZERO).entreprise(ent).build();
        // Produit ayant encore 18% en base, mais entreprise non assujettie TVA
        Produit produit = Produit.builder()
                .id(100L).nom("Article A").sku("ART-A")
                .prixAchat(BigDecimal.ZERO).prixVente(new BigDecimal("10000"))
                .tauxTva(new BigDecimal("18.00")).entreprise(ent).build();

        when(utilisateurRepository.findByEmail("ali@test.com")).thenReturn(Optional.of(user));
        when(clientRepository.findByEntrepriseIdAndNomContainingIgnoreCase(1L, "Client Divers")).thenReturn(List.of(client));
        when(produitRepository.findById(100L)).thenReturn(Optional.of(produit));
        when(securityUtils.getCurrentEntreprise()).thenReturn(Optional.of(ent));
        when(documentRepository.findMaxNumero(anyString())).thenReturn(0);
        when(documentRepository.save(any(Document.class))).thenAnswer(inv -> {
            Document d = inv.getArgument(0);
            d.setId(500L);
            return d;
        });
        when(paiementRepository.save(any(Paiement.class))).thenAnswer(inv -> inv.getArgument(0));

        PosSaleRequest req = PosSaleRequest.builder()
                .moyenPaiement(MoyenPaiement.ORANGE_MONEY)
                .montantPaye(new BigDecimal("10000"))
                .montantRecu(new BigDecimal("10000"))
                .lignes(List.of(PosSaleRequest.LignePosRequest.builder()
                        .produitId(100L)
                        .quantite(BigDecimal.ONE)
                        .prixUnitaire(new BigDecimal("10000"))
                        .tauxTva(null) // Sans taux explicite, l'entreprise hors TVA applique 0%
                        .build()))
                .build();

        PosSaleResponse res = documentService.realiserVentePos(req, "ali@test.com");

        assertThat(res.getDocument().getTotalHt()).isEqualByComparingTo("10000.00");
        assertThat(res.getDocument().getTotalTva()).isEqualByComparingTo("0.00");
        assertThat(res.getDocument().getTotalTtc()).isEqualByComparingTo("10000.00");
        assertThat(res.getSoldeRestant()).isEqualByComparingTo("0");
        assertThat(res.getPaiement()).isNotNull();
        assertThat(res.getPaiement().getMoyen()).isEqualTo(MoyenPaiement.ORANGE_MONEY);
    }

    @Test
    @DisplayName("Vente POS À Crédit enregistre 0 payé et impute la dette client sans créer de paiement")
    void posSaleOnCreditUpdatesClientDebt() {
        Entreprise ent = Entreprise.builder().id(1L).nom("Boutique Test").tvaActive(true).build();
        Depot depot = Depot.builder().id(10L).nom("Principal").entreprise(ent).build();
        Utilisateur user = Utilisateur.builder()
                .id(5L).nom("Diallo").prenom("Ali").email("ali@test.com")
                .entreprise(ent).depot(depot).build();
        Client client = Client.builder().id(22L).nom("Moussa Traoré")
                .soldeCredit(BigDecimal.ZERO).entreprise(ent).build();
        Produit produit = Produit.builder()
                .id(101L).nom("Sac Riz").sku("RIZ-1")
                .prixAchat(null).prixVente(new BigDecimal("15000"))
                .tauxTva(BigDecimal.ZERO).entreprise(ent).build();

        when(utilisateurRepository.findByEmail("ali@test.com")).thenReturn(Optional.of(user));
        when(clientRepository.findById(22L)).thenReturn(Optional.of(client));
        when(produitRepository.findById(101L)).thenReturn(Optional.of(produit));
        when(securityUtils.getCurrentEntreprise()).thenReturn(Optional.of(ent));
        when(documentRepository.findMaxNumero(anyString())).thenReturn(0);
        when(documentRepository.save(any(Document.class))).thenAnswer(inv -> {
            Document d = inv.getArgument(0);
            d.setId(501L);
            return d;
        });

        PosSaleRequest req = PosSaleRequest.builder()
                .clientId(22L)
                .moyenPaiement(MoyenPaiement.CREDIT)
                .montantPaye(BigDecimal.ZERO)
                .lignes(List.of(PosSaleRequest.LignePosRequest.builder()
                        .produitId(101L)
                        .quantite(BigDecimal.ONE)
                        .prixUnitaire(new BigDecimal("15000"))
                        .tauxTva(BigDecimal.ZERO)
                        .build()))
                .build();

        PosSaleResponse res = documentService.realiserVentePos(req, "ali@test.com");

        assertThat(res.getPaiement()).isNull();
        assertThat(res.getMontantTotal()).isEqualByComparingTo("15000.00");
        assertThat(res.getSoldeRestant()).isEqualByComparingTo("15000.00");
        assertThat(client.getSoldeCredit()).isEqualByComparingTo("15000.00");
        verify(paiementRepository, never()).save(any());
    }

    @Test
    @DisplayName("Vente POS À Crédit refusée si le client est anonyme (Client Divers)")
    void posSaleOnCreditRejectsAnonymousClient() {
        Entreprise ent = Entreprise.builder().id(1L).nom("Boutique Test").tvaActive(false).build();
        Depot depot = Depot.builder().id(10L).nom("Principal").entreprise(ent).build();
        Utilisateur user = Utilisateur.builder()
                .id(5L).nom("Diallo").prenom("Ali").email("ali@test.com")
                .entreprise(ent).depot(depot).build();
        Client divers = Client.builder().id(20L).nom("Client Divers / Comptoir")
                .soldeCredit(BigDecimal.ZERO).entreprise(ent).build();
        Produit produit = Produit.builder()
                .id(101L).nom("Sac Riz").sku("RIZ-1")
                .prixVente(new BigDecimal("15000")).tauxTva(BigDecimal.ZERO).entreprise(ent).build();

        when(utilisateurRepository.findByEmail("ali@test.com")).thenReturn(Optional.of(user));
        when(clientRepository.findByEntrepriseIdAndNomContainingIgnoreCase(1L, "Client Divers")).thenReturn(List.of(divers));
        when(produitRepository.findById(101L)).thenReturn(Optional.of(produit));
        when(securityUtils.getCurrentEntreprise()).thenReturn(Optional.of(ent));
        when(documentRepository.findMaxNumero(anyString())).thenReturn(0);
        when(documentRepository.save(any(Document.class))).thenAnswer(inv -> inv.getArgument(0));

        PosSaleRequest req = PosSaleRequest.builder()
                .moyenPaiement(MoyenPaiement.CREDIT)
                .montantPaye(BigDecimal.ZERO)
                .lignes(List.of(PosSaleRequest.LignePosRequest.builder()
                        .produitId(101L)
                        .quantite(BigDecimal.ONE)
                        .prixUnitaire(new BigDecimal("15000"))
                        .tauxTva(BigDecimal.ZERO)
                        .build()))
                .build();

        assertThatThrownBy(() -> documentService.realiserVentePos(req, "ali@test.com"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("client nominatif");
    }

    @Test
    @DisplayName("Vente POS À Crédit crée automatiquement un nouveau client nominatif si renseigné")
    void posSaleOnCreditCreatesNamedClientInline() {
        Entreprise ent = Entreprise.builder().id(1L).nom("Boutique Test").tvaActive(false).build();
        Depot depot = Depot.builder().id(10L).nom("Principal").entreprise(ent).build();
        Utilisateur user = Utilisateur.builder()
                .id(5L).nom("Diallo").prenom("Ali").email("ali@test.com")
                .entreprise(ent).depot(depot).build();
        Produit produit = Produit.builder()
                .id(102L).nom("Bidon Huile").sku("HUI-1")
                .prixVente(new BigDecimal("12000")).tauxTva(BigDecimal.ZERO).entreprise(ent).build();

        when(utilisateurRepository.findByEmail("ali@test.com")).thenReturn(Optional.of(user));
        when(clientRepository.save(any(Client.class))).thenAnswer(inv -> {
            Client c = inv.getArgument(0);
            if (c.getId() == null) c.setId(99L);
            return c;
        });
        when(produitRepository.findById(102L)).thenReturn(Optional.of(produit));
        when(securityUtils.getCurrentEntreprise()).thenReturn(Optional.of(ent));
        when(documentRepository.findMaxNumero(anyString())).thenReturn(0);
        when(documentRepository.save(any(Document.class))).thenAnswer(inv -> {
            Document d = inv.getArgument(0);
            d.setId(502L);
            return d;
        });

        PosSaleRequest req = PosSaleRequest.builder()
                .nouveauClientNom("Issa Ouédraogo")
                .nouveauClientTelephone("70112233")
                .nouveauClientAdresse("Quartier Gounghin")
                .moyenPaiement(MoyenPaiement.CREDIT)
                .montantPaye(BigDecimal.ZERO)
                .lignes(List.of(PosSaleRequest.LignePosRequest.builder()
                        .produitId(102L)
                        .quantite(BigDecimal.ONE)
                        .prixUnitaire(new BigDecimal("12000"))
                        .tauxTva(BigDecimal.ZERO)
                        .build()))
                .build();

        PosSaleResponse res = documentService.realiserVentePos(req, "ali@test.com");

        assertThat(res.getClientNom()).isEqualTo("Issa Ouédraogo");
        assertThat(res.getSoldeRestant()).isEqualByComparingTo("12000.00");
        assertThat(res.getDocument().getClient().getTelephone()).isEqualTo("70112233");
        assertThat(res.getDocument().getClient().getSoldeCredit()).isEqualByComparingTo("12000.00");
    }

    @Test
    @DisplayName("Solder une commande client la valide, génère la facture soldée et crée le paiement")
    void solderCommandeClientCreatesPaidInvoice() {
        Entreprise ent = Entreprise.builder().id(1L).nom("Boutique Test").tvaActive(false).build();
        Depot depot = Depot.builder().id(10L).nom("Principal").entreprise(ent).build();
        Utilisateur user = Utilisateur.builder()
                .id(5L).nom("Diallo").prenom("Ali").email("ali@test.com")
                .entreprise(ent).depot(depot).build();
        Client client = Client.builder().id(30L).nom("Fatimata Sawadogo")
                .soldeCredit(BigDecimal.ZERO).entreprise(ent).build();
        Produit produit = Produit.builder()
                .id(103L).nom("Carton Sucre").sku("SUC-1")
                .prixVente(new BigDecimal("20000")).tauxTva(BigDecimal.ZERO).entreprise(ent).build();

        Document commande = Document.builder()
                .id(700L)
                .entreprise(ent)
                .type(TypeDocument.COMMANDE_CLIENT)
                .numero("CMD-2026-00001")
                .statut(StatutDocument.BROUILLON)
                .client(client)
                .depot(depot)
                .utilisateur(user)
                .build();
        LigneDocument ligneCmd = LigneDocument.builder()
                .document(commande)
                .produit(produit)
                .designation("Carton Sucre")
                .quantite(new BigDecimal("2"))
                .prixUnitaire(new BigDecimal("20000"))
                .tauxTva(BigDecimal.ZERO)
                .build();
        ligneCmd.calculerMontants();
        commande.getLignes().add(ligneCmd);
        commande.recalculerTotaux();

        when(documentRepository.findById(700L)).thenReturn(Optional.of(commande));
        when(securityUtils.isSuperAdmin()).thenReturn(true);
        when(securityUtils.getCurrentEntreprise()).thenReturn(Optional.of(ent));
        when(utilisateurRepository.findByEmail("ali@test.com")).thenReturn(Optional.of(user));
        when(documentRepository.findFirstByDocumentParentIdAndTypeOrderByIdDesc(700L, TypeDocument.FACTURE))
                .thenReturn(Optional.empty());
        when(documentRepository.findMaxNumero(anyString())).thenReturn(4);
        when(documentRepository.save(any(Document.class))).thenAnswer(inv -> {
            Document d = inv.getArgument(0);
            if (d.getId() == null) d.setId(701L);
            return d;
        });
        when(paiementRepository.save(any(Paiement.class))).thenAnswer(inv -> inv.getArgument(0));

        SolderCommandeRequest req = SolderCommandeRequest.builder()
                .moyenPaiement(MoyenPaiement.WAVE)
                .montantPaye(new BigDecimal("40000"))
                .build();

        PosSaleResponse res = documentService.solderCommandeClient(700L, req, "ali@test.com");

        assertThat(commande.getStatut()).isEqualTo(StatutDocument.VALIDE);
        assertThat(commande.getNotes()).contains("Soldée →");
        assertThat(res.getDocument().getType()).isEqualTo(TypeDocument.FACTURE);
        assertThat(res.getMontantTotal()).isEqualByComparingTo("40000.00");
        assertThat(res.getMontantPaye()).isEqualByComparingTo("40000");
        assertThat(res.getSoldeRestant()).isEqualByComparingTo("0");
        assertThat(res.getPaiement().getMoyen()).isEqualTo(MoyenPaiement.WAVE);
        assertThat(client.getSoldeCredit()).isEqualByComparingTo("0");
    }
}


package com.quantis.stock.service;

import com.quantis.stock.model.enums.TypeCaisse;
import com.quantis.stock.model.enums.TypeDocument;
import com.quantis.stock.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

/**
 * Service Dashboard — KPIs et statistiques pour le tableau de bord.
 */
@Service
@RequiredArgsConstructor
public class DashboardService {

    private final ProduitRepository produitRepository;
    private final StockCourantRepository stockCourantRepository;
    private final DocumentRepository documentRepository;
    private final MouvementCaisseRepository caisseRepository;
    private final ClientRepository clientRepository;
    private final FournisseurRepository fournisseurRepository;
    private final MouvementStockRepository mouvementStockRepository;

    @Transactional(readOnly = true)
    public Map<String, Object> getKpis() {
        LocalDate debutMois = LocalDate.now().withDayOfMonth(1);
        LocalDate finMois = LocalDate.now();
        LocalDate debutAnnee = LocalDate.now().withDayOfYear(1);

        Map<String, Object> kpis = new LinkedHashMap<>();

        // Compteurs principaux
        kpis.put("totalProduits", produitRepository.count());
        kpis.put("totalClients", clientRepository.count());
        kpis.put("totalFournisseurs", fournisseurRepository.count());

        // Stock
        long alertes = stockCourantRepository.findAlertesBasses().size();
        long ruptures = stockCourantRepository.findRuptures().size();
        kpis.put("alertesStock", alertes);
        kpis.put("rupturesStock", ruptures);

        // Chiffre d'affaires du mois (entrées caisse)
        BigDecimal caMois = caisseRepository.sumByTypeAndPeriode(TypeCaisse.ENTREE, debutMois, finMois);
        BigDecimal depensesMois = caisseRepository.sumByTypeAndPeriode(TypeCaisse.SORTIE, debutMois, finMois);
        kpis.put("caMois", caMois);
        kpis.put("depensesMois", depensesMois);
        kpis.put("margeMois", caMois.subtract(depensesMois));

        // CA année
        BigDecimal caAnnee = caisseRepository.sumByTypeAndPeriode(TypeCaisse.ENTREE, debutAnnee, finMois);
        kpis.put("caAnnee", caAnnee);

        return kpis;
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> getVentesParMois(int annee) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (int mois = 1; mois <= 12; mois++) {
            LocalDate debut = LocalDate.of(annee, mois, 1);
            LocalDate fin = debut.withDayOfMonth(debut.lengthOfMonth());
            BigDecimal ca = caisseRepository.sumByTypeAndPeriode(TypeCaisse.ENTREE, debut, fin);
            BigDecimal depenses = caisseRepository.sumByTypeAndPeriode(TypeCaisse.SORTIE, debut, fin);
            result.add(Map.of(
                    "mois", mois,
                    "entrees", ca,
                    "sorties", depenses,
                    "marge", ca.subtract(depenses)
            ));
        }
        return result;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getPatrimoine() {
        Map<String, Object> response = new LinkedHashMap<>();

        // 1. Valeur du Stock
        List<com.quantis.stock.model.StockCourant> stocks = stockCourantRepository.findAll();
        BigDecimal valeurStock = BigDecimal.ZERO;
        Map<String, BigDecimal> stockParDepot = new HashMap<>();

        for (var sc : stocks) {
            if (sc.getQuantite() != null && sc.getQuantite().compareTo(BigDecimal.ZERO) > 0) {
                BigDecimal prix = sc.getProduit().getPrixAchat() != null
                        ? sc.getProduit().getPrixAchat()
                        : (sc.getProduit().getPrixVente() != null ? sc.getProduit().getPrixVente() : BigDecimal.ZERO);
                BigDecimal totalLigne = sc.getQuantite().multiply(prix);
                valeurStock = valeurStock.add(totalLigne);

                String depotNom = sc.getDepot() != null ? sc.getDepot().getNom() : "Dépôt Principal";
                stockParDepot.put(depotNom, stockParDepot.getOrDefault(depotNom, BigDecimal.ZERO).add(totalLigne));
            }
        }

        // 2. Trésorerie des Caisses (Total Entrées - Sorties)
        BigDecimal totalEntreesCaisse = caisseRepository.sumByType(TypeCaisse.ENTREE);
        BigDecimal totalSortiesCaisse = caisseRepository.sumByType(TypeCaisse.SORTIE);
        if (totalEntreesCaisse == null) totalEntreesCaisse = BigDecimal.ZERO;
        if (totalSortiesCaisse == null) totalSortiesCaisse = BigDecimal.ZERO;
        BigDecimal soldeCaisses = totalEntreesCaisse.subtract(totalSortiesCaisse);

        // 3. Créances Clients (Débiteurs)
        BigDecimal creancesClients = clientRepository.sumSoldeCredit();
        if (creancesClients == null) creancesClients = BigDecimal.ZERO;
        var debiteurs = clientRepository.findDebiteurs();
        List<Map<String, Object>> topDebiteurs = new ArrayList<>();
        for (var c : debiteurs) {
            topDebiteurs.add(Map.of(
                    "id", c.getId(),
                    "nom", c.getNom(),
                    "telephone", c.getTelephone() != null ? c.getTelephone() : "",
                    "soldeCredit", c.getSoldeCredit()
            ));
            if (topDebiteurs.size() >= 5) break;
        }

        // 4. Dettes Fournisseurs
        BigDecimal dettesFournisseurs = fournisseurRepository.sumSoldeDette();
        if (dettesFournisseurs == null) dettesFournisseurs = BigDecimal.ZERO;
        var crediteurs = fournisseurRepository.findCrediteurs();
        List<Map<String, Object>> topCrediteurs = new ArrayList<>();
        for (var f : crediteurs) {
            topCrediteurs.add(Map.of(
                    "id", f.getId(),
                    "nom", f.getNom(),
                    "telephone", f.getTelephone() != null ? f.getTelephone() : "",
                    "soldeDette", f.getSoldeDette()
            ));
            if (topCrediteurs.size() >= 5) break;
        }

        // 5. Patrimoine Net = Stock + Caisses + Créances - Dettes
        BigDecimal patrimoineNet = valeurStock.add(soldeCaisses).add(creancesClients).subtract(dettesFournisseurs);

        response.put("patrimoineNet", patrimoineNet);
        response.put("valeurStock", valeurStock);
        response.put("stockParDepot", stockParDepot);
        response.put("soldeCaisses", soldeCaisses);
        response.put("totalEntreesCaisse", totalEntreesCaisse);
        response.put("totalSortiesCaisse", totalSortiesCaisse);
        response.put("creancesClients", creancesClients);
        response.put("nbDebiteurs", debiteurs.size());
        response.put("topDebiteurs", topDebiteurs);
        response.put("dettesFournisseurs", dettesFournisseurs);
        response.put("nbCrediteurs", crediteurs.size());
        response.put("topCrediteurs", topCrediteurs);

        return response;
    }
}

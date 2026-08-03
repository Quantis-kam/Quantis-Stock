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
}

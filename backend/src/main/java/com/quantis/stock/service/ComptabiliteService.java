package com.quantis.stock.service;

import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.MouvementCaisse;
import com.quantis.stock.model.enums.TypeCaisse;
import com.quantis.stock.repository.MouvementCaisseRepository;
import com.quantis.stock.repository.UtilisateurRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;

/**
 * Service Comptabilité — journal de caisse et rapports financiers.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ComptabiliteService {

    private final MouvementCaisseRepository caisseRepository;
    private final UtilisateurRepository utilisateurRepository;

    // =================== JOURNAL DE CAISSE ===================

    @Transactional
    public MouvementCaisse enregistrerMouvement(MouvementCaisse mouvement, String userEmail) {
        var utilisateur = utilisateurRepository.findByEmail(userEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", userEmail));
        mouvement.setUtilisateur(utilisateur);
        if (mouvement.getDateMouvement() == null) {
            mouvement.setDateMouvement(LocalDate.now());
        }
        mouvement = caisseRepository.save(mouvement);
        log.info("Mouvement caisse {}: {} FCFA — {}", mouvement.getType(), mouvement.getMontant(), mouvement.getLibelle());
        return mouvement;
    }

    @Transactional(readOnly = true)
    public Page<MouvementCaisse> getJournal(LocalDate debut, LocalDate fin, Pageable pageable) {
        return caisseRepository.findByDateMouvementBetweenOrderByDateMouvementDesc(debut, fin, pageable);
    }

    // =================== RAPPORTS ===================

    @Transactional(readOnly = true)
    public Map<String, Object> getRapportPeriode(LocalDate debut, LocalDate fin) {
        BigDecimal totalEntrees = caisseRepository.sumByTypeAndPeriode(TypeCaisse.ENTREE, debut, fin);
        BigDecimal totalSorties = caisseRepository.sumByTypeAndPeriode(TypeCaisse.SORTIE, debut, fin);
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

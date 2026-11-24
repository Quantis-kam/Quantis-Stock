package com.quantis.stock.config;

import com.quantis.stock.model.Entreprise;
import com.quantis.stock.repository.EntrepriseRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.ZoneOffset;

/**
 * Migration de schéma idempotente au démarrage (tous profils : dev & prod PostgreSQL / H2).
 *
 * Garantit que les contraintes CHECK auto-générées par Hibernate sur les anciennes valeurs
 * d'enum (ex: paiement.moyen) n'empêchent pas l'enregistrement des nouveaux modes de paiement
 * (WAVE, ORANGE_MONEY, MOOV_MONEY, CARTE_BANCAIRE, CREDIT), initialise les préférences
 * TVA / Prix d'achat et met à jour le tarif d'abonnement (10 100 FCFA) + décompte licence.
 */
@Slf4j
@Component
@Order(1)
@RequiredArgsConstructor
public class SchemaMigrationRunner implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;
    private final EntrepriseRepository entrepriseRepository;

    @Override
    public void run(String... args) {
        // 1. Supprimer toute ancienne contrainte CHECK Hibernate sur paiement.moyen
        execIgnore("ALTER TABLE paiement DROP CONSTRAINT IF EXISTS paiement_moyen_check");

        // 2. Élargir paiement.moyen à VARCHAR(30) (PostgreSQL + H2)
        execIgnore("ALTER TABLE paiement ALTER COLUMN moyen TYPE VARCHAR(30)");
        execIgnore("ALTER TABLE paiement ALTER COLUMN moyen VARCHAR(30)");

        // 3. Initialiser les nouvelles préférences entreprise pour les lignes existantes
        execIgnore("UPDATE entreprise SET tva_active = TRUE WHERE tva_active IS NULL");
        execIgnore("UPDATE entreprise SET taux_tva_defaut = 18.00 WHERE taux_tva_defaut IS NULL");
        execIgnore("UPDATE entreprise SET suivi_prix_achat = TRUE WHERE suivi_prix_achat IS NULL");

        // 4. Colonne pin_hash sur utilisateur pour rattacher le code PIN au compte
        execIgnore("ALTER TABLE utilisateur ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(255)");

        // 5. Migrer les entreprises existantes vers le tarif mensuel 10 100 FCFA (*144*2*1*65189261*10100#)
        //    et initialiser date_expiration_licence (+1 mois depuis la création) si elle manquait.
        try {
            LocalDate today = LocalDate.now();
            for (Entreprise ent : entrepriseRepository.findAll()) {
                boolean changed = false;
                if (ent.getMontantAbonnement() == null
                        || Math.abs(ent.getMontantAbonnement() - 20200.0) < 0.01
                        || Math.abs(ent.getMontantAbonnement() - 20000.0) < 0.01) {
                    ent.setMontantAbonnement(Entreprise.DEFAULT_MONTANT_ABONNEMENT);
                    changed = true;
                }
                if (ent.getCodeUssdRenouvellement() == null
                        || ent.getCodeUssdRenouvellement().contains("20200")
                        || ent.getCodeUssdRenouvellement().contains("20000")) {
                    ent.setCodeUssdRenouvellement(Entreprise.DEFAULT_CODE_USSD);
                    changed = true;
                }
                if (ent.getDateExpirationLicence() == null) {
                    LocalDate startDate = ent.getCreatedAt() != null
                            ? ent.getCreatedAt().atZone(ZoneOffset.UTC).toLocalDate()
                            : today;
                    LocalDate exp = startDate.plusMonths(1);
                    ent.setDateExpirationLicence(exp);
                    ent.setStatutLicence(exp.isBefore(today) ? "EXPIREE" : "ACTIVE");
                    changed = true;
                }
                if (changed) {
                    entrepriseRepository.save(ent);
                }
            }
        } catch (Exception e) {
            log.warn("Migration licences entreprises ignorée: {}", e.getMessage());
        }
    }

    private void execIgnore(String sql) {
        try {
            jdbcTemplate.execute(sql);
        } catch (Exception e) {
            log.debug("Migration SQL ignorée ({}): {}", sql, e.getMessage());
        }
    }
}


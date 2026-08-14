package com.quantis.stock.security;

import com.quantis.stock.model.enums.Role;
import com.quantis.stock.model.enums.StatutCommande;
import com.quantis.stock.model.enums.TypeMouvement;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests de sécurité — validation des contraintes.
 */
class SecurityTest {

    @Test
    @DisplayName("Les rôles sont bien définis (5 rôles RBAC)")
    void testRolesDefinis() {
        Role[] roles = Role.values();
        assertEquals(5, roles.length);
        assertNotNull(Role.ADMIN);
        assertNotNull(Role.GERANT);
        assertNotNull(Role.COMPTABLE);
        assertNotNull(Role.MAGASINIER);
        assertNotNull(Role.CAISSIER);
    }

    @Test
    @DisplayName("Les statuts de commande couvrent le cycle complet")
    void testStatutsCommande() {
        StatutCommande[] statuts = StatutCommande.values();
        assertEquals(5, statuts.length);
        assertNotNull(StatutCommande.BROUILLON);
        assertNotNull(StatutCommande.EN_COURS);
        assertNotNull(StatutCommande.RECUE_PARTIELLE);
        assertNotNull(StatutCommande.RECUE);
        assertNotNull(StatutCommande.ANNULEE);
    }

    @Test
    @DisplayName("Les types de mouvement stock sont complets")
    void testTypesMouvement() {
        TypeMouvement[] types = TypeMouvement.values();
        assertTrue(types.length >= 3);
        assertNotNull(TypeMouvement.ENTREE);
        assertNotNull(TypeMouvement.SORTIE);
        assertNotNull(TypeMouvement.TRANSFERT);
    }
}

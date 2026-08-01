# Quantis-Stock — Rôles & Permissions (RBAC)

> **Version :** 1.0 — **Date :** 2026-08-01 — **Pays :** Burkina Faso

---

## 1. Définition des rôles

| Rôle | Portée | Description |
|---|---|---|
| **Admin** | Globale | Super-utilisateur. Configuration, utilisateurs, tous modules. |
| **Gérant** | Dépôt(s) rattaché(s) | Responsable opérationnel. Stock, ventes, rapports, validation. |
| **Magasinier** | Son dépôt | Opérateur stock. Réceptions, sorties, transferts, inventaire. |
| **Caissier** | Son dépôt | Opérateur commercial. Ventes, encaissements, consultation stock. |
| **Comptable** | Globale (lecture) | Accès financier. Rapports, journal caisse, exports comptables. |

---

## 2. Matrice de permissions

### Légende
✅ = Accès complet | CL = Créer+Lire | 📖 = Lecture | V = Valider | E = Encaisser | ❌ = Aucun

### Utilisateurs
| Action | Admin | Gérant | Magasinier | Caissier | Comptable |
|---|---|---|---|---|---|
| CRUD utilisateurs | ✅ | ❌ | ❌ | ❌ | ❌ |
| Voir utilisateurs | ✅ | 📖 dépôt | ❌ | ❌ | ❌ |
| Changer son mot de passe | ✅ | ✅ | ✅ | ✅ | ✅ |

### Catalogue produits
| Action | Admin | Gérant | Magasinier | Caissier | Comptable |
|---|---|---|---|---|---|
| Créer/Modifier produit | ✅ | ✅ | ❌ | ❌ | ❌ |
| Voir produits | ✅ | ✅ | 📖 | 📖 | 📖 |
| Supprimer produit | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gérer catégories/variantes | ✅ | ✅ | ❌ | ❌ | ❌ |
| Import CSV/Excel | ✅ | ✅ | ❌ | ❌ | ❌ |
| Scanner code-barres | ✅ | ✅ | ✅ | ✅ | ❌ |

### Stocks
| Action | Admin | Gérant | Magasinier | Caissier | Comptable |
|---|---|---|---|---|---|
| Voir stock courant | ✅ tous | ✅ dépôt | ✅ dépôt | 📖 dépôt | 📖 tous |
| Entrée de stock | ✅ | V | CL | ❌ | ❌ |
| Sortie de stock | ✅ | V | CL | CL (vente) | ❌ |
| Transfert inter-dépôts | ✅ | ✅ | CL | ❌ | ❌ |
| Inventaire physique | ✅ | ✅ | Saisie | ❌ | ❌ |
| Forcer sortie (stock < 0) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Historique mouvements | ✅ | 📖 dépôt | 📖 dépôt | 📖 sien | 📖 |

### Tiers (Clients & Fournisseurs)
| Action | Admin | Gérant | Magasinier | Caissier | Comptable |
|---|---|---|---|---|---|
| CRUD clients | ✅ | ✅ | ❌ | CL | ❌ |
| CRUD fournisseurs | ✅ | ✅ | ❌ | ❌ | ❌ |
| Voir soldes/créances | ✅ | ✅ | ❌ | 📖 | 📖 |

### Achats
| Action | Admin | Gérant | Magasinier | Caissier | Comptable |
|---|---|---|---|---|---|
| Créer commande fournisseur | ✅ | ✅ | ❌ | ❌ | ❌ |
| Réceptionner commande | ✅ | ✅ | ✅ | ❌ | ❌ |
| Voir commandes | ✅ | ✅ | 📖 | ❌ | 📖 |

### Ventes & Facturation
| Action | Admin | Gérant | Magasinier | Caissier | Comptable |
|---|---|---|---|---|---|
| Créer devis/BL/facture | ✅ | ✅ | ❌ | ✅ | ❌ |
| Convertir devis→BL→facture | ✅ | ✅ | ❌ | ✅ | ❌ |
| Annuler facture (via avoir) | ✅ | ✅ | ❌ | ❌ | ❌ |
| Générer/Envoyer PDF | ✅ | ✅ | ❌ | ✅ | 📖 |

### Paiements & Avoirs
| Action | Admin | Gérant | Magasinier | Caissier | Comptable |
|---|---|---|---|---|---|
| Paiement client | ✅ | ✅ | ❌ | E | ❌ |
| Paiement fournisseur | ✅ | ✅ | ❌ | ❌ | ❌ |
| Créer un avoir | ✅ | ✅ | ❌ | ❌ | ❌ |
| Réceptionner retour (stock) | ✅ | ✅ | ✅ | ❌ | ❌ |

### Comptabilité & Rapports
| Action | Admin | Gérant | Magasinier | Caissier | Comptable |
|---|---|---|---|---|---|
| Journal de caisse | ✅ | ✅ dépôt | ❌ | 📖 sien | ✅ |
| Rapports (CA, marges, TVA) | ✅ | ✅ dépôt | ❌ | ❌ | ✅ |
| KPIs & Dashboard | ✅ | ✅ dépôt | ❌ | ❌ | ✅ |
| Export comptable CSV/Excel | ✅ | ❌ | ❌ | ❌ | ✅ |

### Audit & Système
| Action | Admin | Gérant | Magasinier | Caissier | Comptable |
|---|---|---|---|---|---|
| Logs d'audit | ✅ | 📖 dépôt | ❌ | ❌ | 📖 |
| Configuration système | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gérer dépôts/TVA/numérotation | ✅ | ❌ | ❌ | ❌ | ❌ |

---

## 3. Règles transversales

1. **Portée dépôt** : Gérant, Magasinier, Caissier → données de leur(s) dépôt(s) uniquement.
2. **Soft delete** : Utilisateurs, produits, tiers → désactivation, jamais suppression physique.
3. **Audit** : Toute action tracée (utilisateur, timestamp, détails).
4. **JWT** : Access token 15 min / Refresh token 7 jours. 5 tentatives max avant verrouillage 15 min.

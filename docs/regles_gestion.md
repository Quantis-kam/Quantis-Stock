+# Quantis-Stock — Règles de Gestion

> **Version :** 1.0 — **Date :** 2026-08-01 — **Pays :** Burkina Faso — **Devise :** FCFA — **TVA :** 18%

---

## 1. Gestion des stocks

### 1.1 Stock courant
- Le stock est maintenu **par produit (+ variante éventuelle) × par dépôt**.
- La quantité en stock est un nombre décimal (pour unités fractionnables : kg, litre).
- Le stock ne peut pas devenir négatif (sauf override explicite par un Admin via "forcer sortie").

### 1.2 Seuil d'alerte
- Chaque produit a un **seuil d'alerte** paramétrable (défaut : 10 unités).
- Quand `quantite <= seuil_alerte` → notification visuelle **"Stock bas"** (icône orange).
- Quand `quantite == 0` → notification visuelle **"Rupture de stock"** (icône rouge).
- Les alertes sont visibles sur le dashboard et dans la liste des produits.

### 1.3 Types de mouvements

| Type | Source → Destination | Déclencheur |
|---|---|---|
| **ENTREE** | Externe → Dépôt | Réception fournisseur, retour client, ajustement + |
| **SORTIE** | Dépôt → Externe | Vente (facture), casse, perte, ajustement - |
| **TRANSFERT** | Dépôt A → Dépôt B | Transfert inter-dépôts |
| **AJUSTEMENT** | — | Inventaire physique (écart +/-) |

### 1.4 Motifs de mouvement
`ACHAT` · `VENTE` · `TRANSFERT` · `RETOUR` · `CASSE` · `PERTE` · `INVENTAIRE` · `AUTRE`

### 1.5 Traçabilité
- Chaque mouvement enregistre : **qui** (utilisateur), **quand** (timestamp UTC), **quoi** (produit, variante, quantité), **d'où/vers où** (dépôts), **pourquoi** (motif + commentaire).
- Un mouvement créé ne peut jamais être modifié ni supprimé. Pour corriger : créer un mouvement inverse.

### 1.6 Inventaire physique
1. Le Gérant **ouvre un inventaire** pour un dépôt.
2. Le Magasinier **saisit les comptages** produit par produit.
3. Le système **calcule les écarts** : `écart = quantite_comptée - quantite_théorique`.
4. Le Gérant **valide l'inventaire** → génération automatique de mouvements d'AJUSTEMENT (motif INVENTAIRE).
5. Le stock courant est mis à jour.

---

## 2. Facturation

### 2.1 Numérotation des documents

| Type | Format | Exemple |
|---|---|---|
| Devis | `DEV-{AAAA}-{NNNNN}` | DEV-2026-00001 |
| Bon de livraison | `BL-{AAAA}-{NNNNN}` | BL-2026-00001 |
| Facture | `FAC-{AAAA}-{NNNNN}` | FAC-2026-00001 |
| Avoir | `AV-{AAAA}-{NNNNN}` | AV-2026-00001 |
| Commande fournisseur | `CMD-{AAAA}-{NNNNN}` | CMD-2026-00001 |

- La numérotation est **séquentielle et ininterrompue** par année civile.
- Le compteur repart à 00001 chaque 1er janvier.
- Le préfixe est configurable dans la table `Configuration`.

### 2.2 Cycle de vie des documents

```
DEVIS (brouillon) → DEVIS (validé)
     ↓ conversion
BON DE LIVRAISON (brouillon) → BL (validé) → déclenche SORTIE de stock
     ↓ conversion
FACTURE (brouillon) → FACTURE (validée) → déclenche écriture journal caisse
     ↓ si annulation
AVOIR (lié à la facture)
```

- Un **brouillon** peut être modifié ou supprimé.
- Un document **validé** ne peut plus être modifié ni supprimé. Pour annuler : créer un AVOIR.
- La conversion copie les données du document source et crée un nouveau document avec un `document_parent_id`.

### 2.3 Mentions obligatoires sur les factures (Burkina Faso)
- Raison sociale et adresse du vendeur
- IFU (Identifiant Fiscal Unique) du vendeur
- RCCM du vendeur
- Numéro de facture séquentiel
- Date de la facture
- Nom/Raison sociale et adresse du client
- Désignation, quantité, prix unitaire HT de chaque ligne
- Taux de TVA (18%)
- Total HT, Total TVA, Total TTC
- Mention "TVA : 18%" ou "Exonéré de TVA" selon le cas

---

## 3. TVA (Burkina Faso)

### 3.1 Taux applicables
| Taux | Application |
|---|---|
| **18%** | Taux standard — majorité des produits |
| **0%** | Produits exonérés (produits de première nécessité selon la loi) |

### 3.2 Calcul par ligne
```
montant_ht  = quantite × prix_unitaire
montant_tva = montant_ht × (taux_tva / 100)
montant_ttc = montant_ht + montant_tva
```

### 3.3 Calcul totaux document
```
total_ht  = Σ montant_ht  (toutes les lignes)
total_tva = Σ montant_tva (toutes les lignes)
total_ttc = Σ montant_ttc (toutes les lignes)
```

### 3.4 Arrondi
- Tous les montants en FCFA (pas de centimes en pratique).
- Arrondi : `ROUND(montant, 0)` — arrondi à l'entier le plus proche.
- L'arrondi s'applique **par ligne** puis les totaux sont la somme des lignes arrondies.

---

## 4. Paiements

### 4.1 Moyens de paiement
| Moyen | Description |
|---|---|
| **ESPECES** | Paiement en liquide |
| **MOBILE_MONEY** | Orange Money, Moov Money, etc. |
| **VIREMENT** | Virement bancaire |
| **CHEQUE** | Chèque bancaire |

### 4.2 Règles
- **Paiements partiels** autorisés : une facture peut recevoir plusieurs paiements.
- Statut facture déduit : `total_paiements >= total_ttc` → Payée, sinon → Partiellement payée.
- Un paiement ne peut pas dépasser le solde restant de la facture.
- Chaque paiement génère une écriture **ENTREE** dans le journal de caisse.

### 4.3 Soldes tiers
```
solde_client = Σ factures_validées.total_ttc − Σ paiements_reçus.montant − Σ avoirs.total_ttc
solde_fournisseur = Σ commandes_réceptionnées.total_ttc − Σ paiements_effectués.montant
```

---

## 5. Retours & Avoirs

### 5.1 Processus de retour client
1. Le Gérant crée un document **AVOIR** lié à la facture d'origine.
2. Les lignes de l'avoir spécifient les produits retournés et leurs quantités.
3. Validation de l'avoir → **entrée de stock automatique** (type ENTREE, motif RETOUR).
4. Le montant de l'avoir **réduit le solde du client** (pas de remboursement automatique).
5. Le client peut utiliser son crédit sur sa prochaine facture.

### 5.2 Contraintes
- Un avoir référence obligatoirement une facture validée.
- Les quantités retournées ne peuvent pas dépasser les quantités facturées.
- Le montant de l'avoir ne peut pas dépasser le total TTC de la facture d'origine.

---

## 6. Commandes fournisseur

### 6.1 Cycle de vie
```
BROUILLON → ENVOYEE → PARTIELLE (réception partielle) → LIVREE (réception complète)
                                                       → ANNULEE
```

### 6.2 Réception
- La réception crée automatiquement des mouvements **ENTREE** (motif ACHAT).
- Le système compare `quantite_recue` vs `quantite_commandee` pour chaque ligne.
- Écart signalé visuellement si `quantite_recue ≠ quantite_commandee`.

---

## 7. Synchronisation hors-ligne (aperçu)

### 7.1 Principes
- Chaque action hors-ligne porte un **UUID** unique + **timestamp** pour l'idempotence.
- Les actions sont stockées dans une **file d'attente SQLite locale**.
- À la reconnexion, la file est envoyée à `/api/v1/sync` en lot.

### 7.2 Résolution de conflits
| Donnée | Stratégie |
|---|---|
| **Stock courant** | Le serveur fait foi. Écart signalé à l'utilisateur si ≠ valeur locale. |
| **Documents** | Numéro définitif attribué à la sync (numéro temporaire local remplacé). |
| **Clients/Fournisseurs** | Dernier écrivain gagne (timestamp). |
| **Mouvements** | Tous acceptés (additifs), recalcul du stock courant côté serveur. |

### 7.3 Statuts visuels
| Indicateur | Signification |
|---|---|
| 🟢 **Synchronisé** | Connexion active, tout à jour |
| 🟡 **En attente** | Actions locales non envoyées (X actions en file) |
| 🔴 **Hors-ligne** | Pas de connexion réseau |

---

## 8. Paramètres configurables (table Configuration)

| Clé | Valeur par défaut | Description |
|---|---|---|
| `tva_defaut` | `18` | Taux TVA par défaut (%) |
| `devise` | `FCFA` | Devise du système |
| `prefixe_facture` | `FAC` | Préfixe numérotation factures |
| `prefixe_devis` | `DEV` | Préfixe numérotation devis |
| `prefixe_bl` | `BL` | Préfixe bon de livraison |
| `prefixe_avoir` | `AV` | Préfixe avoir |
| `prefixe_commande` | `CMD` | Préfixe commande fournisseur |
| `seuil_alerte_defaut` | `10` | Seuil d'alerte stock par défaut |
| `tentatives_connexion_max` | `5` | Avant verrouillage |
| `duree_verrouillage_min` | `15` | Minutes de verrouillage |
| `raison_sociale` | — | Nom de l'entreprise |
| `adresse_entreprise` | — | Adresse pour les factures |
| `ifu` | — | Identifiant Fiscal Unique |
| `rccm` | — | Registre du Commerce |
| `telephone_entreprise` | — | Téléphone |
| `email_entreprise` | — | Email |
| `logo_url` | — | Chemin du logo pour les PDF |

# Phase 12 — Évolutions Futures (Backlog)

> Ce document trace les fonctionnalités prévues pour les futures versions de Quantis Stock.
> Priorité : non bloquante. À implémenter selon les besoins terrain.

---

## 1. Multi-devises

**Objectif** : Supporter FCFA, EUR, USD et conversions automatiques.

### Backend
- Ajouter entité `Devise` (code, nom, tauxConversion)
- Champ `devise` sur `Document`, `Paiement`, `MouvementCaisse`
- Service de conversion avec taux du jour
- API: `GET /currencies`, `PUT /currencies/{code}/rate`

### Frontend
- Sélecteur de devise dans les formulaires
- Affichage multi-devises dans les rapports

---

## 2. Multi-langues (i18n)

**Objectif** : Français, Anglais, et langues locales (Wolof, Bambara, etc.)

### Backend
- Messages d'erreur localisés via `MessageSource`
- Header `Accept-Language` supporté

### Frontend
- `flutter_localizations` + fichiers ARB
- Sélecteur de langue dans les paramètres
- Fichiers de traduction : `l10n/app_fr.arb`, `app_en.arb`

---

## 3. Module RH Simple

**Objectif** : Gestion basique paie et présences (si besoin).

### Entités
- `Employe` (nom, poste, salaire, dateEmbauche)
- `Presence` (date, heureArrivee, heureDepart)
- `FichePaie` (mois, salaireBase, primes, deductions, net)

### Endpoints
- `GET/POST /hr/employees`
- `GET/POST /hr/attendance`
- `GET/POST /hr/payroll`

---

## 4. Intégration Mobile Money

**Objectif** : Paiements Orange Money, MTN Money, Wave directement depuis l'app.

### Architecture
```
App Flutter → Backend API → Gateway Mobile Money
                              ├── Orange Money API
                              ├── MTN MoMo API
                              └── Wave API
```

### Backend
- Service `MobileMoneyGateway` (abstraction multi-opérateur)
- Webhook callback pour confirmation de paiement
- Reconciliation automatique avec les paiements Quantis

### Frontend
- Bouton "Payer via Mobile Money" dans DocumentDetailScreen
- QR Code pour paiement client
- Notifications push de confirmation

---

## 5. Module E-commerce / Vitrine en ligne

**Objectif** : Vitrine web connectée au même stock.

### Architecture
- API publique: `GET /shop/products` (catalogue filtré)
- Panier + commande en ligne → Document DEVIS automatique
- Stock partagé en temps réel avec l'app de gestion
- Dashboard vendeur dans l'app Flutter

### Frontend web
- Site statique (Next.js ou Flutter Web)
- Catalogue produits avec photos
- Formulaire de commande simplifié

---

## Priorisation recommandée

| Fonctionnalité | Impact business | Effort | Priorité |
|---|---|---|---|
| Mobile Money | 🔴 Très élevé | Moyen | **P1** |
| Multi-devises | 🟡 Moyen | Faible | **P2** |
| Multi-langues | 🟢 Faible | Faible | **P3** |
| E-commerce | 🔴 Très élevé | Élevé | **P3** |
| Module RH | 🟢 Faible | Moyen | **P4** |

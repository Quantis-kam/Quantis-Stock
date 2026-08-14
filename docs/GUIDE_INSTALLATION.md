# Quantis Stock — Guide d'installation et d'utilisation

## Prérequis

| Composant | Version minimum |
|---|---|
| Java JDK | 21+ |
| PostgreSQL | 15+ |
| Flutter SDK | 3.32+ |
| Android SDK | 33+ (pour mobile) |
| Node.js | 18+ (optionnel, pour les builds) |

---

## 1. Installation Backend

### Base de données PostgreSQL

```bash
# Créer la base de données
sudo -u postgres psql -c "CREATE DATABASE quantis_stock;"
sudo -u postgres psql -c "CREATE USER quantis WITH PASSWORD 'quantis_pass';"
sudo -u postgres psql -c "GRANT ALL ON DATABASE quantis_stock TO quantis;"
```

### Configuration

Copier et adapter le fichier de configuration :

```bash
cd backend/src/main/resources
cp application-dev-pg.yml application-prod.yml
```

Modifier `application-prod.yml` :
```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/quantis_stock
    username: quantis
    password: ${DB_PASSWORD}  # Variable d'environnement

server:
  port: 8080
  ssl:
    enabled: true
    key-store: classpath:keystore.p12
    key-store-password: ${SSL_PASSWORD}
```

### Lancement

```bash
cd backend

# Développement
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev

# Production
./mvnw clean package -DskipTests
java -jar target/stock-api-*.jar --spring.profiles.active=prod
```

### Tests

```bash
./mvnw test
# 14 tests unitaires (TVA, stock, sécurité)
```

---

## 2. Installation Frontend Flutter

### Dépendances

```bash
cd frontend
flutter pub get
```

### Configuration API

Modifier `lib/core/constants/app_constants.dart` :
```dart
static const String baseUrl = 'https://votre-serveur:8080/api/v1';
```

### Lancement développement

```bash
# Desktop Windows
flutter run -d windows

# Desktop Linux
flutter run -d linux

# Android (appareil connecté)
flutter run -d android
```

### Builds production

```bash
# Windows (.exe)
flutter build windows --release

# Linux
flutter build linux --release

# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release
```

Les artefacts sont dans `build/`:
- Windows: `build/windows/x64/runner/Release/`
- Linux: `build/linux/x64/release/bundle/`
- Android: `build/app/outputs/flutter-apk/app-release.apk`

### Tests Flutter

```bash
flutter test
# Widget tests (LoginScreen) + Unit tests (DocumentModel)
```

---

## 3. Comptes par défaut

| Email | Mot de passe | Rôle |
|---|---|---|
| `admin@quantis.tech` | *(défini au premier lancement)* | ADMIN |

> ⚠️ Changez immédiatement le mot de passe admin en production.

---

## 4. Architecture des modules

```
Quantis Stock
├── Dashboard       — KPIs, graphiques mensuels
├── Produits        — Catalogue avec recherche, marges
├── Stock           — Mouvements (E/S/T), alertes ruptures
├── Clients         — CRUD, créances FCFA
├── Fournisseurs    — CRUD, dettes
├── Achats          — Commandes → Réception (→ entrée stock auto)
├── Documents       — Devis → BL → Facture → Avoir + paiements
├── Comptabilité    — Journal de caisse, rapport période
└── Sync            — Mode hors-ligne, file d'attente locale
```

---

## 5. Sécurité

- **JWT** : Tokens signés (access 15min + refresh 7j)
- **RBAC** : 5 rôles (Admin, Gérant, Comptable, Magasinier, Caissier)
- **BCrypt** : Hash des mots de passe (cost factor 12)
- **HSTS** : Headers de sécurité activés
- **Sync idempotent** : UUID unique par action, doublons ignorés

---

## 6. Mode hors-ligne

L'application fonctionne sans connexion réseau :

1. Les actions sont stockées dans une **file JSON locale**
2. Le `SyncManager` surveille la connectivité
3. Dès que le réseau revient, les actions sont **envoyées en lot**
4. Les doublons sont **automatiquement ignorés** (UUID)
5. Un indicateur visuel montre l'état en temps réel

---

## 7. Support

- **Logs backend** : `backend/logs/` (Logback)
- **Rapport financier** : `GET /api/v1/accounting/report?debut=2026-01-01&fin=2026-12-31`
- **Alertes stock** : `GET /api/v1/stock/alerts`

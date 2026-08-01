# Quantis Stock

Application complète de **Gestion de Stock** — Backend Spring Boot + Frontend Flutter (Desktop & Mobile).

## Architecture

```
Quantis-Stock/
├── backend/          Spring Boot 4.0.7 (Java 21) — API REST
├── frontend/         Flutter (Dart) — Desktop + Mobile
├── docs/             Documentation technique (MCD, RBAC, règles)
├── docker-compose.yml
└── .gitignore
```

## Stack technique

| Composant | Technologie |
|---|---|
| Backend API | Spring Boot 4.0.7, Java 21, Maven |
| Base de données | PostgreSQL 18 |
| Frontend | Flutter (Desktop + Mobile) |
| Base locale | SQLite via Drift |
| Auth | JWT (access + refresh token) |
| Devise | FCFA (Franc CFA) |
| TVA | 18% (Burkina Faso) |

## Démarrage rapide

### Backend
```bash
cd backend
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

### Base de données
```bash
# Créer l'utilisateur et la base
sudo -u postgres psql
CREATE USER quantis_user WITH PASSWORD 'quantis_dev_2026';
CREATE DATABASE quantis_stock OWNER quantis_user;
```

### Frontend
```bash
cd frontend
flutter run -d linux    # Desktop Linux
flutter run -d chrome   # Web (dev)
flutter run             # Mobile connecté
```

## Licence

Propriétaire — © Quantis 2026

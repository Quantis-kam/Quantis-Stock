# Déploiement Cloud Gratuit (0 FCFA) — Quantis-Stock

Architecture complète à **0 FCFA/mois** (zéro carte bancaire requise) sur votre domaine **`quantisbf.com`** :
- **Frontend Web** : `https://stock.quantisbf.com` → **Cloudflare Pages** (gratuit, illimité)
- **Backend API** : `https://api-stock.quantisbf.com/api/v1` → **Render.com** (Docker, plan Free 512 Mo)
- **Base de données** : PostgreSQL → **Neon.tech** (plan Free 512 Mo, Europe/Frankfurt)

---

## Étape 1 — Créer la base PostgreSQL sur Neon (2 min)

1. Allez sur [neon.tech](https://neon.tech) → **Sign up with GitHub** (aucune carte demandée).
2. Créez un projet :
   - **Project name** : `quantis-stock`
   - **Region** : `Europe (Frankfurt)` *(aws-eu-central-1)*
3. Cliquez sur **Connect** et copiez la **Connection string** (elle ressemble à :
   `postgresql://neondb_owner:xxxx@ep-xxxx.eu-central-1.aws.neon.tech/neondb?sslmode=require`).

> `backend/docker-entrypoint.sh` convertit automatiquement cette URL Neon pour Spring Boot JDBC — vous n'avez rien à découper manuellement !

---

## Étape 2 — Déployer le Backend Spring Boot sur Render (5 min)

1. Poussez vos modifications sur votre dépôt **GitHub** (`git add ... && git commit && git push`).
2. Allez sur [render.com](https://render.com) → **Get Started → GitHub** (aucune carte demandée).
3. Cliquez sur **New + → Web Service** (ou **Blueprint** qui détecte automatiquement `render.yaml`) :
   - Sélectionnez votre dépôt `Quantis-Stock`
   - **Root Directory** : `backend`
   - **Runtime** : `Docker` *(Dockerfile détecté automatiquement)*
   - **Region** : `Frankfurt (EU Central)`
   - **Instance Type** : **Free**
   - **Health Check Path** : `/api/v1/health`
4. Ajoutez ces **Environment Variables** dans Render :
   | Variable | Valeur |
   |---|---|
   | `SPRING_PROFILES_ACTIVE` | `prod` |
   | `DATABASE_URL` | *(Collez l'URL complète copiée depuis Neon)* |
   | `JWT_SECRET` | *(Une longue chaîne aléatoire de 64 caractères)* |
   | `SUPER_ADMIN_EMAIL` | `superadmin@quantisbf.com` *(ou votre email)* |
   | `SUPER_ADMIN_PASSWORD` | *(Choisissez un mot de passe fort !)* |
   | `QUANTIS_AI_PROVIDER` | `gemini` |
   | `QUANTIS_AI_API_KEY` | *(Optionnel — votre clé Gemini API gratuite sur aistudio.google.com)* |
5. Cliquez sur **Create Web Service**.
   - Premier build Docker : ~4–6 minutes.
   - Une fois en ligne (`Live`), vérifiez dans le navigateur :
     `https://<votre-service>.onrender.com/api/v1/health` → doit renvoyer `{"success":true,"data":{"status":"UP",...}}`.

---

## Étape 3 — Brancher le sous-domaine `api-stock.quantisbf.com` (2 min)

1. Dans **Render** → votre service → **Settings → Custom Domains → Add Custom Domain** :
   - Entrez : `api-stock.quantisbf.com`
   - Render vous affiche la cible `CNAME` (ex. `quantis-stock-api.onrender.com`).
2. Dans **Cloudflare** → domaine `quantisbf.com` → **DNS → Add record** :
   - **Type** : `CNAME`
   - **Name** : `api-stock`
   - **Target** : `<votre-service>.onrender.com`
   - **Proxy status** : **DNS only** (nuage gris) le temps que Render émette le certificat SSL (~2 min), puis vous pouvez laisser en DNS only ou activer le proxy avec SSL **Full (strict)**.
3. Testez : `https://api-stock.quantisbf.com/api/v1/health` ✅

---

## Étape 4 — Déployer le Frontend Web sur Cloudflare Pages (`stock.quantisbf.com`) (3 min)

Le dossier `frontend/build/web` est déjà prêt (ou reconstruisez-le avec `cd frontend && ../flutter/bin/flutter build web --release`).

1. Dans **Cloudflare** → menu gauche **Workers & Pages → Create → Pages → Direct Upload**.
2. Nom du projet : `quantis-stock-web` → glissez-déposez le dossier **`frontend/build/web`**.
3. Cliquez sur **Deploy site**.
4. Une fois déployé, onglet **Custom domains → Set up a custom domain** :
   - Entrez : `stock.quantisbf.com`
   - Cloudflare configure automatiquement le DNS + HTTPS !
5. Ouvrez **`https://stock.quantisbf.com`** et connectez-vous avec votre compte `SUPER_ADMIN_EMAIL` / `SUPER_ADMIN_PASSWORD` pour créer les espaces de vos premiers commerçants !

---

## Étape 5 — Garder le backend réveillé en journée (0 FCFA, 2 min)

Render met en veille le plan gratuit après 15 min d'inactivité (avec 750 h gratuites/mois disponibles). Pour éviter tout temps d'attente pendant les heures d'ouverture des boutiques (7h–21h = ~420 h/mois) :

1. Créez un compte gratuit sur [cron-job.org](https://cron-job.org) (ou [uptimerobot.com](https://uptimerobot.com)).
2. Créez un job :
   - **URL** : `https://api-stock.quantisbf.com/api/v1/health`
   - **Schedule** : toutes les **10 minutes**, de **07:00 à 21:00** (UTC / GMT Ouagadougou).
3. Résultat : le serveur répond instantanément toute la journée pour vos clients en essai gratuit, à **0 FCFA/mois** !

---

## Application Android (APK)
L'APK généré (`Quantis-Stock.apk`) pointe désormais par défaut sur **`https://api-stock.quantisbf.com/api/v1`** (tout en gardant l'option « Serveur → Auto-détecter le serveur PC » si vous souhaitez démontrer en local hors-ligne).


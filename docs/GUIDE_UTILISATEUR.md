# 📘 Quantis-Stock — Guide d'Utilisation Complet & Accessible

> **Bienvenue sur Quantis-Stock !**  
> Ce guide a été conçu pour être **simple, clair et accessible à tous**, que vous soyez commerçant, gérant de boutique, caissier, magasinier ou responsable comptable, même sans connaissances informatiques particulières.

---

## 📑 Sommaire
1. [Qu'est-ce que Quantis-Stock ?](#1-quest-ce-que-quantis-stock-)
2. [Premiers pas & Connexion](#2-premiers-pas--connexion)
3. [Comprendre l'Interface & Les Rôles](#3-comprendre-linterface--les-rôles)
4. [Le Tableau de Bord (Vue d'ensemble en un clin d'œil)](#4-le-tableau-de-bord)
5. [Caisse & Vente au Comptoir (Point de Vente - POS)](#5-caisse--vente-au-comptoir-pos)
6. [Articles & Catalogue Produits](#6-articles--catalogue-produits)
7. [Gestion des Stocks & Entrepôts](#7-gestion-des-stocks--entrepôts)
8. [Arrêt de Stock & Inventaire Physique](#8-arrêt-de-stock--inventaire-physique)
9. [Clients, Ventes à Crédit & Suivi des Débiteurs](#9-clients-ventes-à-crédit--suivi-des-débiteurs)
10. [Fournisseurs & Réception des Achats](#10-fournisseurs--réception-des-achats)
11. [Factures, Devis & Bons de Livraison](#11-factures-devis--bons-de-livraison)
12. [Caisse, Dépenses & Pré-Comptabilité](#12-caisse-dépenses--pré-comptabilité)
13. [Quantis Voice & Assistant Intelligent (Jarvis)](#13-quantis-voice--assistant-intelligent-jarvis)
14. [Gestion des Utilisateurs & Paramètres](#14-gestion-des-utilisateurs--paramètres)
15. [Guide de Dépannage Rapide & FAQ](#15-guide-de-dépannage-rapide--faq)

---

## 1. Qu'est-ce que Quantis-Stock ?

**Quantis-Stock** est votre logiciel de gestion commerciale tout-en-un. Il remplace avantageusement les cahiers manuels, les feuilles volantes et les fichiers Excel complexes.

Il vous permet de :
* 🛒 **Encaisser rapidement vos clients** au comptoir avec un scanner code-barres ou un écran tactile.
* 📦 **Suivre vos stocks en temps réel** (entrées, sorties, transferts entre magasins).
* ⚠️ **Éviter les ruptures** grâce aux alertes automatiques quand un article devient rare.
* 👥 **Suivre les crédits clients (dettes)** pour savoir qui vous doit de l'argent et à quelle date.
* 📋 **Faire vos inventaires facilement** et comparer ce qui est compté en rayon avec ce qui est enregistré.
* 💰 **Contrôler votre trésorerie** et exporter vos chiffres pour le comptable.
* 🎙️ **Piloter votre entreprise à la voix** avec **Quantis Voice**, votre assistant intelligent interactif.

---

## 2. Premiers pas & Connexion

### 2.1 Accéder à l'application
- **Sur Ordinateur (Navigateur Web Chrome)** : Ouvrez Chrome et rendez-vous sur l'adresse fournie par votre administrateur (ex : `http://localhost:3000` en local ou l'adresse IP réseau de votre boutique).
- **Sur Téléphone ou Tablette Android** : Ouvrez l'application **Quantis-Stock** installée sur votre appareil.

### 2.2 Se connecter à son compte
1. Sur l'écran d'accueil, saisissez votre **Identifiant / Email**.
2. Saisissez votre **Mot de passe**.
3. *(Optionnel)* Si vous travaillez en réseau local, vérifiez que l'adresse du serveur indiquée en bas est correcte.
4. Cliquez sur le bouton vert **Se connecter**.

> [!TIP]
> **Conseil sécurité** : Ne partagez jamais votre mot de passe. Chaque vendeur ou magasinier doit avoir son propre compte pour que chaque opération soit signée à son nom dans l'historique.

---

## 3. Comprendre l'Interface & Les Rôles

### 3.1 La barre de navigation
- **Sur Ordinateur** : Vous disposez d'un menu latéral sur la gauche avec des icônes claires (Tableau de bord, Caisse POS, Factures, Articles, Stock, etc.).
- **Sur Mobile / Tablette** : Une barre en bas de l'écran regroupe les fonctions principales, et le bouton **« Plus »** donne accès aux modules secondaires.
- **Raccourci Recherche Rapide** : Appuyez sur `Ctrl + K` (ou `Cmd + K` sur Mac) à tout moment pour rechercher un produit, un client ou une commande en une seconde.

### 3.2 Les Rôles d'utilisateurs
Chaque personne n'a accès qu'à ce dont elle a besoin pour travailler en toute sérénité :

| Rôle | Qui est-ce ? | Que peut-il faire dans Quantis-Stock ? |
|---|---|---|
| **Admin** | Le Propriétaire / Directeur | Accès total à tous les dépôts, modification des prix, création des utilisateurs, clôtures et suppressions. |
| **Gérant** | Le Responsable de boutique | Supervise les ventes, valide les achats, lance les inventaires, consulte les bénéfices. |
| **Caissier** | Le Vendeur / Opérateur de caisse | Fait les ventes au comptoir (POS), encaisse les règlements, consulte la disponibilité des articles. |
| **Magasinier** | Le Responsable des stocks | Réceptionne les marchandises des fournisseurs, prépare les transferts, compte les stocks. |
| **Comptable** | Le Gestionnaire financier | Consulte les chiffres, le journal de caisse et exporte les rapports en PDF ou Excel. |

---

## 4. Le Tableau de Bord (Dashboard)

Le Tableau de bord est la première page qui s'affiche après votre connexion. C'est le **tableau de commande de votre commerce**.

### Ce que vous y voyez immédiatement :
1. **Chiffre d'affaires du jour** : Total des ventes encaissées aujourd'hui (en FCFA).
2. **Nombre de ventes** : Combien de clients ont acheté aujourd'hui.
3. **Alertes de stock** :
   - 🟠 **Stock bas** : Articles qui approchent du seuil de sécurité.
   - 🔴 **Rupture de stock** : Articles totalement épuisés (quantité = 0).
4. **Créances clients (Dettes à recouvrer)** : Somme totale que vos clients vous doivent actuellement.
5. **Graphique des tendances** : Évolution de vos ventes sur les 7 ou 30 derniers jours.

---

## 5. Caisse & Vente au Comptoir (POS)

Le module **Caisse POS** est l'outil quotidien du caissier. Il a été conçu pour être ultra-rapide et utilisable au clavier, à la souris ou au doigt (tactile).

```
   [ Scanner ou Choisir Article ] ➡️ [ Régler Quantités / Remise ] ➡️ [ Choisir Mode de Paiement ] ➡️ [ Imprimer Ticket ]
```

### 5.1 Enregistrer une vente pas-à-pas :
1. **Ajouter des articles au panier** :
   - *Méthode 1 (Code-barres)* : Pointez votre lecteur code-barres sur l'article. Il s'ajoute automatiquement au panier !
   - *Méthode 2 (Recherche)* : Tapez les premières lettres du nom du produit dans la barre de recherche.
   - *Méthode 3 (Catalogue visuel)* : Cliquez directement sur les cartes de produits affichées à l'écran.
2. **Modifier la quantité** :
   - Cliquez sur `+` ou `-` pour ajuster la quantité.
   - Vous pouvez aussi taper directement le chiffre souhaité.
3. **Associer un client (Facultatif mais recommandé)** :
   - Par défaut, la vente est assignée à « Client Comptoir ».
   - Si le client souhaite une facture nominative ou achète à crédit, cliquez sur **Sélectionner Client** et choisissez-le dans la liste (ou créez-le en 5 secondes avec le bouton `+ Nouveau`).
4. **Appliquer une remise** *(si vous y êtes autorisé)* :
   - Vous pouvez renseigner un pourcentage (ex: 5%) ou un montant de réduction en FCFA.
5. **Encaisser** :
   - Cliquez sur le grand bouton vert **Encaisser (F10)**.
   - Choisissez le mode de règlement :
     * 💵 **Espèces** : Saisissez le montant remis par le client, le logiciel calcule automatiquement la **monnaie à rendre** !
     * 📱 **Mobile Money (Wave, Orange Money, Moov)** : Notez la référence de transaction si nécessaire.
     * 💳 **Carte Bancaire / Chèque / Virement**.
     * 📝 **À Crédit** : Réservé aux clients enregistrés. Le solde dû sera ajouté à leur compte.
6. **Finaliser & Imprimer** :
   - Validez la vente : le stock est déduit automatiquement.
   - Le ticket s'imprime immédiatement sur votre imprimante thermique (format 80mm ou 58mm).

---

## 6. Articles & Catalogue Produits

Ce module vous permet de référencer tout ce que vous vendez ou stockez.

### 6.1 Créer un nouvel article
1. Allez dans le menu **Articles & Produits**.
2. Cliquez sur **+ Ajouter un article**.
3. Remplissez les informations essentielles :
   - **Nom du produit** *(ex: Huile Végétale 5L, Riz Parfumé 25kg, Cahier 200p)*.
   - **Code-barres / SKU** : Scannez le code avec votre douchette ou laissez le logiciel en générer un automatiquement.
   - **Catégorie** : Choisissez ou créez une catégorie (Alimentation, Cosmétique, Électronique, Quincaillerie...).
   - **Unité** : Pièce, Carton, Kilogramme (kg), Litre, Paquet...
   - **Prix d'achat** : Ce que l'article vous coûte chez le fournisseur.
   - **Prix de vente** : Le prix payé par le client au comptoir.
   - **Seuil d'alerte** : À partir de quelle quantité restante vous voulez être prévenu (ex: 5 unités).
4. Cliquez sur **Enregistrer**.

> [!NOTE]
> **Marge bénéficiaire** : Le logiciel calcule automatiquement votre marge bénéficiaire et votre taux de marque pour vous aider à fixer le bon prix de vente.

---

## 7. Gestion des Stocks & Entrepôts

Quantis-Stock gère vos marchandises dépôt par dépôt (ex: *Magasin Principal*, *Dépôt Annexe*, *Boutique Centre-Ville*).

### 7.1 Les 3 types de mouvements de stock :
1. **Entrée de stock (Réception / Ajout)** :
   - Utilisé lors de la livraison de marchandises par un fournisseur ou pour ajouter du stock initial.
   - *Comment faire ?* : Menu **Stock** > **Nouveau mouvement** > Type : **Entrée** > Choisir l'article, la quantité et le motif (ex: `Achat`).
2. **Sortie de stock (Perte / Casse / Sortie manuelle)** :
   - *Remarque* : Les ventes en caisse déduisent automatiquement le stock, vous n'avez pas besoin de faire de sortie manuelle pour une vente.
   - Utilisez ce formulaire pour enregistrer de la casse, un produit périmé, un vol ou une utilisation interne.
3. **Transfert inter-dépôts (Déplacement)** :
   - Utilisé pour déplacer 20 cartons du *Grand Entrepôt* vers la *Boutique*.
   - Le logiciel retire la marchandise du dépôt de départ et l'ajoute au dépôt d'arrivée en une seule opération sécurisée.

> [!IMPORTANT]
> **Règle d'or de la traçabilité** : Un mouvement de stock validé ne peut jamais être effacé. Si une erreur a été commise, il suffit de faire le mouvement inverse (par exemple une entrée pour corriger une fausse sortie). Cela garantit une transparence totale contre les disparitions inexpliquées.

---

## 8. Arrêt de Stock & Inventaire Physique

Faire l'inventaire dans Quantis-Stock est un jeu d'enfant. Fini les calculs à la main !

```
   [ 1. Ouvrir l'inventaire ] ➡️ [ 2. Compter en rayon ] ➡️ [ 3. Voir les écarts ] ➡️ [ 4. Valider l'ajustement ]
```

### Comment réaliser son inventaire :
1. Rendez-vous dans **Arrêts Stock**.
2. Cliquez sur **Nouvel Inventaire** et sélectionnez le dépôt concerné.
3. **Phase de comptage** :
   - Les magasiniers parcourent les rayons avec un téléphone ou une feuille imprimée.
   - Pour chaque produit, ils saisissent la **quantité réelle trouvée sur l'étagère**.
4. **Vérification des écarts** :
   - Le logiciel compare immédiatement le comptage avec le stock théorique de l'ordinateur.
   - Il met en valeur les différences :
     * `+2` : Vous avez 2 unités de plus que prévu.
     * `-3` : Il manque 3 unités.
5. **Validation par le gérant** :
   - Le gérant examine les écarts et clique sur **Clôturer et Ajuster l'inventaire**.
   - Le stock informatique est instantanément aligné sur la réalité physique.

---

## 9. Clients, Ventes à Crédit & Suivi des Débiteurs

### 9.1 Fiche client
Dans le menu **Clients**, vous retrouvez la liste complète de vos clients avec :
- Leurs coordonnées (Téléphone, Adresse, Ville).
- Le total de leurs achats depuis le début.
- Leur **solde actuel** :
  * Solde = 0 FCFA : Client en règle.
  * Solde > 0 FCFA : Le client vous doit de l'argent (dette).

### 9.2 Suivi des Débiteurs (Créances)
Accédez au menu **Débiteurs** pour avoir la liste noire/blanche de tous les clients ayant une dette impayée :
- Vous voyez qui doit quoi, depuis combien de jours, et la date limite convenue.
- **Encaisser un acompte** : Le client vient donner 10 000 FCFA pour réduire sa dette ? Cliquez sur **Régler**, tapez 10 000 FCFA, et son solde diminue immédiatement avec impression d'un reçu d'acompte.

---

## 10. Fournisseurs & Réception des Achats

Le module **Fournisseurs & Achats** vous permet de maîtriser vos dépenses d'approvisionnement :
1. **Créer un fournisseur** : Enregistrez son nom, téléphone et les conditions de paiement accordées.
2. **Passer une commande d'achat** : Sélectionnez les articles que vous souhaitez commander.
3. **Réceptionner la commande** : Lorsque le camion arrive à votre dépôt, vous vérifiez les quantités livrées et cliquez sur **Valider la réception**. Vos stocks augmentent automatiquement sans ressaisie !

---

## 11. Factures, Devis & Bons de Livraison

Dans le menu **Factures & Devis**, vous pouvez émettre tous vos documents commerciaux professionnels avec le logo de votre entreprise :

### Cycle classique d'un document :
* **Devis (Proforma)** : Vous proposez un prix à un client. Rien ne bouge en stock.
* **Bon de Livraison (BL)** : Le client accepte. La marchandise sort du magasin pour lui être livrée.
* **Facture définitive** : Document officiel pour le paiement. Elle peut être marquée comme *Payée*, *Partiellement payée* ou *En attente*.

> [!TIP]
> **Conversion en 1 clic** : Vous pouvez transformer un Devis en Facture d'un simple clic sur le bouton « Convertir en Facture », sans rien retaper !

---

## 12. Caisse, Dépenses & Pré-Comptabilité

Pour éviter que l'argent de la caisse ne disparaisse dans de petites dépenses non suivies :
- **Entrées exceptionnelles** : Apport personnel de monnaie, versement bancaire.
- **Sorties de dépenses quotidiennes** : Achat de fournitures, carburant pour la livraison, facture d'électricité, repas des employés.
- Chaque soir, la clôture de caisse compare le total théorique calculé par les ventes avec l'argent physique réellement présent dans le tiroir-caisse.
- Le menu **Exports Compta** permet de télécharger en un clic le grand livre et les journaux de vente au format Excel/CSV pour votre comptable.

---

## 13. Quantis Voice & Assistant Intelligent (Jarvis)

Quantis-Stock intègre **Quantis Voice**, un assistant vocal intelligent nouvelle génération capable de comprendre le langage humain naturel.

```
   [ 👏 👏 Double Clap ]  OU  [ Clic sur le Micro ]
                       ⬇️
   [ Vous posez votre question en français naturel ]
                       ⬇️
   [ Quantis réfléchit, analyse la base de données ]
                       ⬇️
   [ Réponse vocale immédiate + affichage à l'écran ]
```

### 13.1 Comment réveiller Quantis Voice ?
* **Méthode Mains-Libres (Double Clap)** : Tapez deux fois dans vos mains **👏 👏** à proximité de l'ordinateur ou du téléphone. L'assistant se réveille instantanément sans que vous ayez à toucher le clavier !
* **Méthode Écran** : Cliquez sur la bulle micro ou l'icône Quantis AI en haut à droite de votre écran.

### 13.2 Exemples de questions que vous pouvez lui poser :

| Ce que vous voulez savoir | Ce que vous pouvez dire à voix haute |
|---|---|
| **Ventes du jour** | *« Quantis, quel est le chiffre d'affaires d'aujourd'hui ? »* |
| **Vérifier un stock** | *« Combien de sacs de riz 25kg reste-t-il au magasin principal ? »* |
| **Dettes clients** | *« Qui sont les clients qui nous doivent le plus d'argent ? »* |
| **Articles en rupture** | *« Quels sont les produits en rupture de stock ? »* |
| **Recherche de prix** | *« Quel est le prix de vente du carton de savon ? »* |
| **Action rapide** | *« Ouvre la caisse »* ou *« Montre-moi la liste des factures impayées »* |

L'assistant vous répond à haute voix avec une voix masculine française claire et naturelle, tout en écrivant le détail à l'écran.

---

## 14. Gestion des Utilisateurs & Paramètres

*(Réservé aux Administrateurs et Gérants)*

### 14.1 Ajouter un nouvel employé
1. Rendez-vous dans **Utilisateurs**.
2. Cliquez sur **+ Nouvel utilisateur**.
3. Renseignez son nom, son email/identifiant et choisissez son **Rôle** *(Caissier, Magasinier, Gérant, Comptable)*.
4. Associez-le à son **Dépôt d'affectation**.
5. Définissez son mot de passe initial.

### 14.2 Informations de l'Entreprise
Dans le menu **Entreprise**, vous pouvez personnaliser :
- Le nom commercial de votre établissement.
- Votre logo d'entreprise (qui figurera sur les tickets et factures).
- Vos coordonnées, Numéro IFU / NIF / RCCM.
- La devise par défaut (ex: `FCFA`).
- Le taux de TVA (ex: `18%` ou `0%` selon votre régime fiscal).

---

## 15. Guide de Dépannage Rapide & FAQ

### ❓ Le scanner de code-barres ne tape rien à l'écran.
- **Solution** : Vérifiez que le câble USB de la douchette est bien branché. Cliquez dans le champ de recherche de l'écran avant de scanner. Le voyant du scanner doit émettre un bip sonore à chaque lecture.

### ❓ La voix de Quantis ne s'active pas avec les mains.
- **Solution** : Assurez-vous que votre navigateur a l'autorisation d'accéder au **Microphone** (icône de cadenas ou de micro à gauche de la barre d'adresse dans Chrome). Faites deux claps nets et rapprochés 👏 👏.

### ❓ Mon ticket de caisse ne s'imprime pas.
- **Solution** : Vérifiez que l'imprimante thermique est allumée, qu'il y a du papier dans le bon sens (face thermique vers le haut) et qu'aucun voyant rouge d'erreur ne clignote.

### ❓ Comment corriger une vente faite par erreur ?
- **Solution** : Allez dans **Factures & Devis**, retrouvez la facture concernée, et émettez un **Avoir**. Cela remettra automatiquement les articles en stock et annulera l'encaissement dans le journal de caisse.

### ❓ Que faire en cas de coupure Internet ?
- **Solution** : Si vous travaillez sur le serveur local de votre boutique (`localhost` ou réseau Wi-Fi interne), Quantis-Stock continue de fonctionner normalement même sans connexion Internet externe !

---

> **Besoin d'aide supplémentaire ?**  
> Contactez le support technique de votre entreprise ou posez directement votre question à votre assistant intégré **Quantis AI** !

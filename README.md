# Visite Énergie — PWA pour coordinateur énergie

Application mobile (PWA) pour visiter des maisons avec des acheteurs : dictée vocale et photos pièce par pièce, stockage local (IndexedDB, utilisable hors connexion), diagnostic **indicatif** généré par Claude via un proxy Cloudflare Worker, export PDF, suivi des commissions.

```
app/      site statique (index.html, manifest, service worker, icônes)  → Cloudflare Pages
worker/   proxy vers l'API Anthropic (la clé n'est jamais dans le navigateur) → Cloudflare Workers
```

## Déploiement express (recommandé)

```bash
npm install
npm run deploy
```
Le script se connecte à Cloudflare, publie le site et le proxy, enregistre vos secrets, règle CORS, puis affiche **un lien à ouvrir sur le téléphone** qui configure l'appli tout seul (adresse du proxy + jeton). Il faut seulement votre clé API Anthropic. Les sections 1 à 3 ci-dessous décrivent la même chose à la main.

Déploiement automatique à chaque push sur `main` : ajoutez les secrets GitHub `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `ANTHROPIC_API_KEY`, `APP_TOKEN` (workflow `.github/workflows/deploy.yml`).

## 1. Déployer le Worker (proxy Claude)

Prérequis : un compte Cloudflare, Node 18+, une clé API Anthropic.

```bash
cd worker
npx wrangler login
npx wrangler secret put ANTHROPIC_API_KEY     # collez votre clé Anthropic
npx wrangler secret put APP_TOKEN             # inventez un long mot de passe (ex. 32 caractères)
npx wrangler deploy
```
Notez l'URL affichée (`https://energie-proxy.<compte>.workers.dev`).

Puis, dans `worker/wrangler.toml`, remplacez `ALLOWED_ORIGIN` par l'adresse de votre site (étape 2) et redéployez (`npx wrangler deploy`). Tant que ce n'est pas fait, les appels depuis le site seront refusés par CORS. `MODEL` règle le modèle Claude utilisé.

## 2. Déployer le site (Cloudflare Pages)

```bash
cd app
npx wrangler pages deploy . --project-name visite-energie
```
(ou tableau de bord Cloudflare → Workers & Pages → Create → Pages → *Upload assets* → glisser le dossier `app`).
Le site est servi en HTTPS (obligatoire pour le micro, l'appareil photo et l'installation). Si l'adresse n'est pas `https://visite-energie.pages.dev`, reportez-la dans `ALLOWED_ORIGIN`.

## 3. Configurer l'appli sur le téléphone

1. Ouvrez l'adresse du site, puis **Installer** (Android : menu ⋮ → *Installer l'application* ; iPhone : Partager → *Sur l'écran d'accueil*).
2. Réglages : nom, logo, téléphone/e-mail, **adresse du Worker** + **jeton** (= `APP_TOKEN`), puis « Tester la connexion ».
3. Ajustez la grille de prix si besoin.

## Tests à faire sur votre téléphone

1. **Installation** : l'icône apparaît sur l'écran d'accueil, l'appli s'ouvre en plein écran.
2. **Mode avion** : ouvrez l'appli, créez une visite, écrivez des notes et prenez des photos ; fermez/rouvrez : tout est là.
3. **Dictée** : sur une pièce, touchez le micro, autorisez l'accès, dictez une phrase en français ; le texte s'ajoute, se modifie, s'enregistre seul. Aucune voix ne répond. (La dictée Chrome demande du réseau ; hors ligne, utilisez le micro du clavier.)
4. **Photos** : bouton Photo (appareil arrière), plusieurs photos dans une pièce, légende, suppression.
5. **Plein soleil** : lisibilité des textes et des boutons, micro et photo faciles à toucher d'une main.
6. **Diagnostic** : avec du réseau, « Générer le diagnostic » (1 à 2 min, écran allumé) ; vérifiez synthèse, 8 postes, budget, classement, questions ; modifiez un prix et vérifiez que le total bouge.
7. **PDF** : « Exporter en PDF » → *Enregistrer au format PDF* ; vérifiez nom, logo, mention « avis indicatif non réglementaire », pied de page.
8. **Suivi** : ajoutez un artisan, des travaux de 5 000 € → commission 400 € ; changez le statut de paiement ; l'accueil affiche le total à encaisser.
9. **Sauvegarde** : Réglages → Exporter, puis tester Importer.

## Choix par défaut (modifiables)

- Design : clair et très contrasté (pas de mode sombre), teal profond = confiance, ambre = action ; polices système (fonctionnent hors ligne). Palette adaptée du générateur ui-ux-pro-max, dont la proposition sombre/verre dépoli a été écartée pour l'usage extérieur. Contrastes vérifiés ≥ 4,5:1 ; testé à 375 / 768 / 1024 / 1440 px sans défilement horizontal.
- PDF : impression du navigateur (« Enregistrer au format PDF ») plutôt qu'une bibliothèque PDF : zéro dépendance, fonctionne hors ligne ; photos jointes en option.
- Le Worker détient le prompt système et le schéma de sortie ; l'appli ne peut qu'envoyer des données de visite. Accès protégé par jeton + CORS.
- Confidentialité : le nom de l'acheteur n'est jamais envoyé à Claude ; seul le code postal est extrait de l'adresse.
- Jusqu'à 24 photos (réduites à 1280 px) envoyées par diagnostic ; au-delà, échantillon réparti.
- Les prix de chaque ligne sont recalculés par l'appli : quantité estimée par Claude × grille de prix. Hors grille, l'estimation de Claude est utilisée et signalée.
- Classement gain/coût : gain 1–5 estimé par Claude ÷ coût moyen de la fourchette.
- Postes sans information : « non évalué », exclus du budget.
- Statuts de dossier : En visite, Diagnostic prêt, Envoyé, Travaux en cours, Clos. Nouveaux dossiers : 250 € et 8 % (modifiables par dossier).
- Montants de travaux saisis en HT ; commission = montant × taux.
- Données uniquement sur le téléphone : pensez à l'export de sauvegarde (un changement de téléphone ou l'effacement des données du navigateur les supprime).
- Modèle par défaut du Worker : `claude-sonnet-5-5` (variable `MODEL`).

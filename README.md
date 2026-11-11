# FLASHA

*Chaque instant se révèle.* ✦

FLASHA est une application sociale de photo, vidéo et messages, avec sa propre patte : la
photographie argentique (papier, encre, cyanotype, chambre noire). On y envoie des **Flashs**
éphémères, on remplit sa **Pellicule** de 24 poses par jour, on parcourt la **Planche** des
amis (une planche-contact), on regarde des **Rushs**, on écrit sur **Talka**, et on réagit
d'un **éclat** ✦. Tout est chiffré sur le téléphone, sans base de données. L'identité est
décrite dans [BRAND.md](BRAND.md).

Ce dépôt contient :

| Dossier | Contenu | Technologie |
|---|---|---|
| `src/`, `public/` | le site, installable comme application (PWA), et le relais sans base | Rust, [Paquets](https://github.com/maxlestage/Paquets) (pages rendues par le serveur, îlots WebAssembly, scène 2D avec `paquets::ecs`) |
| `ios/` | l'application iPhone | Swift 6, SwiftUI, AVFoundation |

## Installer FLASHA (PWA) et la partager

Le site est une **application installable** : manifeste, icônes, plein écran, hors connexion.

- **iPhone** : ouvrez le site dans Safari → bouton *Partager* → *Sur l'écran d'accueil*.
- **Android** : bouton « Installer FLASHA » sur le site, ou menu ⋮ de Chrome → *Installer
  l'application*.

La section **Partager** envoie FLASHA par la feuille de partage du téléphone (Messages,
WhatsApp, Mail, AirDrop…), par des liens directs (Messages, WhatsApp, Telegram, e-mail), ou
par un QR code. Les liens partagés s'affichent avec un aperçu (`public/og.png`).

## Le site

Une seule page, en français, **mobile first** : tout est conçu d'abord pour un écran de 320 px,
puis élargi par `min-width`. Aucune largeur fixe ne dépasse l'écran, rien ne défile horizontalement.

- **Scène 2D** (`src/scene.rs`) : dans l'écran du téléphone du héros, des bulles de lumière
  montent en ondulant, et chaque toucher déclenche un éclat de particules. Elle tourne avec le
  moteur ECS de Paquets (`Camera2d`, `Mesh2d`, `ColorMaterial`) dans le canvas d'un îlot.
- **Îlots interactifs** (`src/lib.rs`), écrits en Rust et compilés en WebAssembly :
  - la chambre (caméra) : tirages Cyanotype, Argentique, Halo et Sépia, photo ou vidéo, flash ;
  - le Flash : durée d'affichage (1 s à ∞), photo qui se développe, expiration et relecture ;
  - Talka : une conversation où Léa répond, avec l'indicateur « en train d'écrire ».
  - les Rushs : des vidéos courtes verticales, comme des images de film perforées (glisser,
    flèches), onglets « Découvertes » et « Mes suivis », double toucher pour un éclat ✦,
    minutage, suivre quelqu'un ;
  - la Planche : la planche-contact des tirages des amis ; toucher un tirage l'entoure au
    crayon gras et l'agrandit, il se développe ; éclat privé, commentaires ;
  - Partager (feuille de partage du téléphone ou copie du lien) et Installer (PWA).
- **Animations** en CSS : apparitions au défilement (`animation-timeline: view()`, sans
  JavaScript), bandes de pellicule qui défilent, développement des photos, tirages posés,
  notifications. Tout respecte `prefers-reduced-motion`.
- Mode clair et mode sombre, contenu lisible même sans WebAssembly.

```sh
# Le bundle du navigateur (îlots + scène 2D) → pkg/
rustup target add wasm32-unknown-unknown
cargo install wasm-bindgen-cli --version 0.2.130 --locked
cargo build --lib --target wasm32-unknown-unknown --profile wasm-release
wasm-bindgen --target web --no-typescript --out-dir pkg \
  target/wasm32-unknown-unknown/wasm-release/flasha.wasm

# Le serveur, sur http://localhost:3000
cargo run --release

cargo test                 # les tests de la page
```

Avec la commande `paquets` : `paquets dev` fait les deux.

## Déployer sur GitHub Pages

Le workflow `.github/workflows/pages.yml` publie le site à chaque mise à jour de `master`
(et à la demande : *Actions → Deploy to GitHub Pages → Run workflow*).

1. Une seule fois : GitHub → *Settings → Pages → Build and deployment → Source* :
   **GitHub Actions**.
2. Le site est en ligne sur `https://<compte>.github.io/FLASHA/`.

Le workflow compile le bundle WebAssembly, puis `flasha export dist` écrit le site statique :
la page sort du serveur lui-même (client de test en mémoire de Paquets), ses adresses
reçoivent le chemin de base donné par Pages (`/FLASHA`), avec le manifeste et le service
worker de l'application installable. En local :

```sh
BASE_PATH=/FLASHA cargo run --release -- export dist
```

## L'application iOS

Ouvrez `ios/Flasha.xcodeproj` avec Xcode 27 (Swift 6, iOS 26 minimum, iPhone).

- s'ouvre sur la **caméra** plein écran : photo d'un appui court, appui long pour filmer
  (vidéo convertie en FLASHA Vidéo au relâchement), flash
  auto/activé/désactivé, caméra avant/arrière, zoom au pincement, mise au point tactile, grille ;
- **éditeur** : filtres Core Image, texte, durée du Flash, relecture autorisée, choix des
  destinataires (meilleurs amis en premier) ;
- **Amis** : stories, Flashs reçus qui expirent après la durée choisie, meilleurs amis, ajout
  par pseudo ou lien d'invitation ;
- **Talka** : conversations, recherche, réactions, copie ;
- **Planche** (onglet Amis, avec Flashs et Amis) : les tirages des amis, avec leur dateur,
  double toucher pour un éclat ✦, commentaires, nouvelle publication ;
- **Rushs** : vidéos courtes, page par page, « Découvertes » et « Mes suivis », suivre,
  éclats, commentaires, garder, partager ;
- **Profil** : statistiques privées, grille des publications et contrôles de confidentialité
  (localisation coupée par défaut).

### Données : tout sur le téléphone, tout chiffré

FLASHA ne dépend d'aucun serveur ni d'aucune base de données externe
(`ios/Flasha/Storage/`) :

- **le coffre** (`Vault`) : une base SQLite sur l'iPhone, où chaque enregistrement est
  chiffré en AES-256-GCM ; même les noms des enregistrements sont masqués (HMAC-SHA256) ;
- **les médias** (`MediaStore`) : chaque photo et vidéo est chiffrée de la même façon,
  aucun fichier n'est écrit en clair ;
- **la clé** : 256 bits tirés au hasard à la première ouverture, rangés dans le trousseau
  d'iOS et liés à cet iPhone (ni iCloud ni une sauvegarde ne peuvent relire les données) ;
- l'état est enregistré automatiquement après chaque changement, et le Profil permet de
  tout effacer.

### S'abonner sans base de données : le relais

Pour s'abonner et s'échanger publications, Flashs et messages, les téléphones passent par un
**relais sans base** (`src/relay.rs`, route `/relay` du serveur, en WebSocket) :

- **pas de compte ni d'annuaire** : chaque iPhone crée ses clés (Ed25519 pour signer, X25519
  pour chiffrer) ; son **identifiant FLASHA** (`flasha:…`) se partage par QR code ou par lien
  (Profil) ;
- **chiffré de bout en bout** : chaque paquet est chiffré pour son seul destinataire (X25519 +
  HKDF-SHA256 + ChaCha20-Poly1305, une clé par paquet) et signé par l'expéditeur
  (`Network/Sealing.swift`) ; le relais ne peut rien lire ;
- **rien sur disque** : le relais garde un paquet en mémoire vive tant que son destinataire est
  hors ligne (72 heures au plus, dans des limites de taille), puis l'oublie ; le téléphone qui
  l'a envoyé le garde dans sa boîte d'envoi chiffrée jusqu'à l'**accusé de réception**, et le
  renvoie si besoin ;
- **identités vérifiées** : à la connexion, le téléphone signe un défi aléatoire ; le relais
  garantit l'expéditeur de chaque paquet, et le destinataire vérifie sa signature ;
- s'abonner : « Ajouter un ami » → identifiant → demande chiffrée → la personne accepte dans
  l'onglet Amis → ses tirages arrivent sur la Planche.

Le relais fait partie du serveur Rust : il tourne partout où le serveur tourne (Heroku avec le
secret `HEROKU_API_KEY` et la variable `HEROKU_APP_NAME`, ou tout hébergeur Docker), sans base ni
disque. Son adresse se règle dans l'app (Profil → Relais). GitHub Pages, qui ne sert que des
fichiers, héberge le site mais pas le relais.

### Les formats FLASHA

Chaque photo et chaque vidéo est convertie automatiquement, sur l'iPhone, avant d'être
enregistrée ou envoyée : une seule taille pour tout le monde, aussi légère que possible
sans perte visible sur l'écran d'un téléphone (`ios/Flasha/Media/`).

| Format | Dimensions | Encodage | Poids indicatif |
|---|---|---|---|
| **FLASHA Photo** | 1080 × 1440 (3:4) | HEIC, qualité 0,6, sRGB, sans métadonnées ni GPS | ≈ 150 à 300 Ko |
| Miniature | 270 × 360 | HEIC, qualité 0,5 | ≈ 10 Ko |
| **FLASHA Vidéo** | 1080 × 1920 (9:16), 30 i/s | HEVC 2,5 Mbit/s, image clé toutes les 2 s, AAC stéréo 96 kbit/s, Rec. 709, 60 s au plus | ≈ 19 Mo la minute |

Les fichiers restent du HEIC et du MP4 standards : la puce de l'iPhone les encode et les
décode elle-même (rapide, économe en batterie), et ils se lisent partout. Ce qui ne remplit
pas le format est recadré au centre. Les photos sont affichées sans être décodées en entier
(seulement à la taille de l'écran), ce qui économise aussi la mémoire vive.

Sur le téléphone, une limite de place (1 Go par défaut, réglable dans le Profil) s'applique :
au-delà, les photos et vidéos les plus anciennes sont effacées en premier ; les Souvenirs et
les envois en cours sont gardés.

Sur le simulateur, qui n'a pas de caméra, une photo de démonstration remplace la capture.
Les données sont locales : le serveur, les appels et l'enregistrement vidéo arrivent avec les
phases suivantes de la feuille de route.

## Déployer sur Heroku depuis un téléphone

Le serveur (le site et le relais sans base) se déploie sur Heroku avec le buildpack
[emk/rust](https://elements.heroku.com/buildpacks/emk/heroku-buildpack-rust), sur la pile
heroku-26 (`RustConfig`, `heroku-build.sh`, `Procfile`, `app.json`). Aucun ordinateur n'est
nécessaire : tout se fait dans le navigateur du téléphone.

[![Déployer sur Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/maxlestage/FLASHA)

**1. Créer l'application (une seule fois)**

1. Créez un compte sur [heroku.com](https://signup.heroku.com) et ajoutez un moyen de paiement
   (*Account settings → Billing*) : Heroku n'a pas d'offre gratuite, un dyno *Eco* coûte
   environ 5 $ par mois.
2. Touchez le bouton **Déployer sur Heroku** ci-dessus (ou ouvrez
   `https://heroku.com/deploy?template=https://github.com/maxlestage/FLASHA`), choisissez un nom
   d'application, par exemple `flasha-relais`, puis **Deploy app**. La première compilation dure
   une dizaine de minutes.
3. Touchez **View** : le site s'ouvre sur `https://<nom>.herokuapp.com`.

**2. Brancher l'application iPhone sur le relais**

Dans FLASHA : *Profil → Relais*, saisissez `https://<nom>.herokuapp.com`, puis **Se connecter**.

**3. Déploiement automatique de chaque fusion (facultatif)**

1. Heroku → *Account settings* → *API Key* → **Reveal**, puis copiez la clé.
2. Sur GitHub, dans le navigateur du téléphone (l'application GitHub n'a pas ces réglages ;
   au besoin, demandez la version « ordinateur » du site) : dépôt FLASHA → *Settings → Secrets
   and variables → Actions* :
   - onglet *Secrets* → **New repository secret** : `HEROKU_API_KEY`, avec la clé copiée ;
   - onglet *Variables* → **New repository variable** : `HEROKU_APP_NAME`, avec le nom choisi.
3. Dans l'application GitHub : *Actions → Deploy to Heroku → Run workflow*. Ensuite, chaque
   fusion dans `master` est déployée toute seule.

Le relais n'a ni base de données ni disque : rien à ajouter sur Heroku (pas de module
complémentaire, pas de Postgres). La variable `HEROKU_BUILD=docker` permet de construire avec le
`Dockerfile` à la place du buildpack.

## Toujours fusionné dans master

Chaque push lance la CI (`.github/workflows/ci.yml`) : formatage, clippy (serveur et
WebAssembly), tests et bundle du site, puis compilation de l'application iOS sur macOS. Quand
tout est vert, la branche est **fusionnée automatiquement dans `master`** (sauf les branches
`wip/...`), puis le site est déployé sur GitHub Pages et, s'il est configuré, sur Heroku
(`.github/workflows/heroku.yml`, avec le secret `HEROKU_API_KEY` et la variable `HEROKU_APP_NAME`).

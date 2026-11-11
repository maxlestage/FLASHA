# FLASHA

**Capture. Share. Connect.** — le partage instantané, autrement. 📸

FLASHA est une application sociale mobile centrée sur la photo, la vidéo, les conversations
instantanées et le partage de moments éphémères : une caméra au centre, des Flashs, **Talka** la
messagerie, des Stories et un espace Découvrir.

Ce dépôt contient :

| Dossier | Contenu | Technologie |
|---|---|---|
| `src/`, `public/` | le site de présentation | Rust, [Paquets](https://github.com/maxlestage/Paquets) (pages rendues par le serveur, îlots WebAssembly, scène 2D avec `paquets::ecs`) |
| `ios/` | l'application iPhone | Swift 6, SwiftUI, AVFoundation |

## Le site

Une seule page, en français, **mobile first** : tout est conçu d'abord pour un écran de 320 px,
puis élargi par `min-width`. Aucune largeur fixe ne dépasse l'écran, rien ne défile horizontalement.

- **Scène 2D** (`src/scene.rs`) : dans l'écran du téléphone du héros, des bulles de lumière
  montent en ondulant, et chaque toucher déclenche un éclat de particules. Elle tourne avec le
  moteur ECS de Paquets (`Camera2d`, `Mesh2d`, `ColorMaterial`) dans le canvas d'un îlot.
- **Îlots interactifs** (`src/lib.rs`), écrits en Rust et compilés en WebAssembly :
  - la caméra : filtres, photo ou vidéo, déclencheur qui fait un vrai flash ;
  - le Flash : durée d'affichage (1 s à ∞), compte à rebours, expiration et relecture autorisée ;
  - Talka : une conversation où Léa répond, avec l'indicateur « en train d'écrire ».
  - les Clips : des vidéos courtes verticales, une par écran (glisser, flèches), onglets
    « Pour toi » et « Abonnements », double toucher pour aimer, suivre un créateur, son qui défile ;
  - le Fil : une publication en carrousel (glisser, flèches), double toucher pour aimer,
    enregistrer, commenter.
- **Animations** en CSS : apparitions au défilement (`animation-timeline: view()`, sans
  JavaScript), téléphone flottant, bande défilante des outils de l'éditeur, anneaux de stories,
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
- **Fil** (onglet Amis, avec Flashs et Amis) : stories, publications en carrousel, double
  toucher pour aimer, commentaires, enregistrement, nouvelle publication ;
- **Découvrir** : les Clips, page par page, « Pour toi » et « Abonnements », suivre un créateur,
  aimer, commenter, enregistrer, partager, disque du son qui tourne ;
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

## Toujours fusionné dans master

Chaque push lance la CI (`.github/workflows/ci.yml`) : formatage, clippy (serveur et
WebAssembly), tests et bundle du site, puis compilation de l'application iOS sur macOS. Quand
tout est vert, la branche est **fusionnée automatiquement dans `master`** (sauf les branches
`wip/...`), puis le site est déployé sur GitHub Pages et, s'il est configuré, sur Heroku
(`.github/workflows/heroku.yml`, avec le secret `HEROKU_API_KEY` et la variable `HEROKU_APP_NAME`).

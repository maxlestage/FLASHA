//! Les textes du site. FLASHA a son propre vocabulaire, tiré de la photo argentique :
//! les Flashs (éphémères), la Pellicule (24 poses par jour), la Planche (la
//! planche-contact des amis), les Rushs (les vidéos courtes), les Éclats (pour réagir),
//! et des photos qui se développent à l'écran.

/// Une carte : icône (nom dans `icons`), titre, texte.
pub struct Card {
    pub icon: &'static str,
    pub title: &'static str,
    pub text: &'static str,
}

/// Les expériences réunies dans FLASHA.
pub const EXPERIENCES: [Card; 6] = [
    Card {
        icon: "camera",
        title: "La chambre",
        text: "La caméra s'ouvre la première. Un appui pour une photo, un appui long pour filmer. Chaque image se développe sous vos yeux.",
    },
    Card {
        icon: "bolt",
        title: "Flashs",
        text: "Des photos et vidéos qui ne durent qu'un instant, de 1 seconde à sans limite. Vous décidez si l'on peut les revoir.",
    },
    Card {
        icon: "roll",
        title: "Pellicule",
        text: "24 poses par jour, pas une de plus. Votre journée en 24 images, visibles 24 heures par ceux que vous choisissez.",
    },
    Card {
        icon: "sheet",
        title: "Planche",
        text: "Les tirages de vos amis, rangés comme une planche-contact. On entoure ses préférés au crayon gras.",
    },
    Card {
        icon: "chat",
        title: "Talka",
        text: "La messagerie de FLASHA : messages, vocaux, réactions, groupes et appels, chiffrés de bout en bout.",
    },
    Card {
        icon: "reel",
        title: "Rushs",
        text: "Des vidéos courtes, avec leur son et leur minutage. Glissez pour passer au rush suivant.",
    },
];

/// Les outils de l'atelier (l'éditeur), montrés en défilement continu.
pub const EDITOR: [&str; 14] = [
    "Texte",
    "Crayon gras",
    "Dateur",
    "Cadre papier",
    "Grain",
    "Cyanotype",
    "Argentique",
    "Halo",
    "Recadrage",
    "Contraste",
    "Sous-titres",
    "Voix off",
    "Ralenti",
    "Musique",
];

/// Les fonctions de Talka : (nom, description).
pub const TALKA: [(&str, &str); 6] = [
    (
        "Flash dans Talka",
        "Une photo envoyée directement dans la conversation, qui s'efface après lecture.",
    ),
    (
        "Revoir",
        "Revoir un média une seule fois, quand son expéditeur l'autorise.",
    ),
    (
        "Planche partagée",
        "Un album à plusieurs : chacun y glisse ses tirages.",
    ),
    (
        "Mots",
        "Des notes courtes, écrites à la main ou au clavier.",
    ),
    ("Éclats", "Réagir d'un éclat ✦ plutôt que d'un cœur."),
    (
        "À côté",
        "Retrouver des amis proches, uniquement avec leur accord.",
    ),
];

/// Les amis dont la Pellicule du jour est montrée : (prénom, initiale, poses prises).
pub const STORIES: [(&str, &str, u8); 6] = [
    ("Léa", "L", 12),
    ("Sam", "S", 24),
    ("Inès", "I", 7),
    ("Noah", "N", 0),
    ("Jade", "J", 18),
    ("Yanis", "Y", 3),
];

/// Qui peut voir chaque publication.
pub const AUDIENCES: [&str; 5] = [
    "Tout le monde",
    "Mes amis",
    "Mes proches",
    "Une liste",
    "Une seule personne",
];

/// La confidentialité, dès la conception.
pub const PRIVACY: [Card; 6] = [
    Card {
        icon: "lock",
        title: "Tout reste sur votre téléphone",
        text: "Profil, photos, messages et abonnements sont chiffrés en AES-256 sur votre appareil. Aucune base de données ne les garde ailleurs.",
    },
    Card {
        icon: "shield",
        title: "Chiffré de bout en bout",
        text: "Ce que vous envoyez n'est lisible que par son destinataire. Le relais qui le transmet ne peut rien lire.",
    },
    Card {
        icon: "eye",
        title: "Visibilité au choix",
        text: "Qui peut vous écrire, vous appeler, voir votre Pellicule ou votre présence : vous décidez.",
    },
    Card {
        icon: "pin",
        title: "Localisation coupée",
        text: "La géolocalisation est désactivée par défaut et se règle séparément, personne par personne.",
    },
    Card {
        icon: "flag",
        title: "Pas d'annuaire",
        text: "On vous ajoute avec votre QR code. Personne ne peut vous trouver par votre numéro sans votre accord.",
    },
    Card {
        icon: "scale",
        title: "RGPD et DSA",
        text: "Effacement en un geste, portabilité, protection des mineurs et signalement des contenus illicites.",
    },
];

/// La feuille de route : (étape, titre, contenu).
pub const ROADMAP: [(&str, &str, &str); 5] = [
    (
        "Pose 1",
        "La chambre et les Flashs",
        "Caméra, développement à l'écran, Flashs éphémères, coffre chiffré sur le téléphone.",
    ),
    (
        "Pose 2",
        "Talka et le relais",
        "Messages, vocaux, groupes et appels, chiffrés de bout en bout par un relais sans base.",
    ),
    (
        "Pose 3",
        "Pellicule et Planche",
        "24 poses par jour, planche-contact des amis, abonnements par QR code.",
    ),
    (
        "Pose 4",
        "Rushs et atelier",
        "Vidéos courtes, filtres argentiques, cadres papier, dateur, montage.",
    ),
    (
        "Pose 5",
        "FLASHA+",
        "Plus de place, filtres d'auteur, tirages papier livrés chez vous.",
    ),
];

/// Ce qui fait la différence : (domaine, ambition).
pub const EDGE: [(&str, &str); 6] = [
    (
        "Le développement",
        "Chaque photo apparaît comme dans un bac de révélateur.",
    ),
    (
        "24 poses",
        "Une journée, 24 images : on choisit plutôt qu'on accumule.",
    ),
    (
        "La planche-contact",
        "Les tirages des amis, côte à côte, entourés au crayon gras.",
    ),
    (
        "Les éclats",
        "On réagit d'un éclat ✦, pas d'un cœur, et sans compteur public.",
    ),
    (
        "Le papier",
        "Une interface couleur papier et encre, sans dégradés criards.",
    ),
    (
        "Le secret",
        "Tout chiffré sur le téléphone, sans base de données ni annuaire.",
    ),
];

/// Les offres : (nom, prix, mention, avantages, mise en avant ?).
pub const PLANS: [(&str, &str, &str, &[&str], bool); 2] = [
    (
        "FLASHA",
        "0 €",
        "Pour tout le monde, pour toujours.",
        &[
            "La chambre et l'atelier",
            "Flashs et Talka",
            "Pellicule de 24 poses",
            "Planche et Rushs",
            "Appels audio et vidéo",
            "Filtres argentiques",
        ],
        false,
    ),
    (
        "FLASHA+",
        "4,99 €",
        "Par mois, prix indicatif.",
        &[
            "Plus de place sur le téléphone",
            "Filtres d'auteur",
            "Cadres et dateurs exclusifs",
            "Tirages papier livrés",
            "Statistiques privées",
            "Un réseau sans publicité",
        ],
        true,
    ),
];

/// Les ateliers à venir.
pub const LABS: [(&str, &str); 6] = [
    (
        "Le révélateur",
        "Améliorer ses photos sans jamais les envoyer à un serveur.",
    ),
    (
        "La double exposition",
        "Deux photos superposées, comme sur un film.",
    ),
    (
        "L'atelier vidéo",
        "Monter ses rushs : couper, ralentir, sous-titrer.",
    ),
    ("Le direct", "Filmer en direct pour ses proches."),
    (
        "Les filtres d'auteur",
        "Des filtres créés par des photographes.",
    ),
    (
        "Les tirages",
        "Recevoir sa Pellicule du mois imprimée sur papier.",
    ),
];

/// Un Rush : une vidéo courte et verticale.
pub struct Clip {
    pub creator: &'static str,
    pub caption: &'static str,
    pub sound: &'static str,
    pub likes: u32,
    pub comments: u32,
    /// Le décor animé du Rush (classe CSS `clip--…`).
    pub scene: &'static str,
}

/// Les Rushs de la démonstration. Les deux premiers créateurs sont suivis.
pub const CLIPS: [Clip; 4] = [
    Clip {
        creator: "sam.photo",
        caption: "Marée basse, lumière rasante.",
        sound: "Son original — sam.photo",
        likes: 1_240,
        comments: 31,
        scene: "sunset",
    },
    Clip {
        creator: "lea",
        caption: "24 poses, aucune ratée.",
        sound: "Néons — Atelier FLASHA",
        likes: 892,
        comments: 20,
        scene: "neon",
    },
    Clip {
        creator: "ines.danse",
        caption: "La chorégraphie de Jade, à ma façon.",
        sound: "Pulse — Les Ondes",
        likes: 3_010,
        comments: 120,
        scene: "dance",
    },
    Clip {
        creator: "noah.cuisine",
        caption: "Crêpes, en 30 secondes chrono.",
        sound: "Son original — noah.cuisine",
        likes: 531,
        comments: 9,
        scene: "food",
    },
];

/// Les tirages de la planche-contact : (décor, description, auteur, n° de vue).
pub const SLIDES: [(&str, &str, &str, &str); 9] = [
    (
        "peaks",
        "Des montagnes au lever du soleil",
        "sam.photo",
        "12",
    ),
    ("lake", "Un lac et ses reflets", "sam.photo", "12A"),
    (
        "night",
        "Un ciel étoilé au-dessus du refuge",
        "sam.photo",
        "13",
    ),
    ("sea", "La mer, bleu cyanotype", "lea", "13A"),
    ("sun", "Un soleil orange sur la ville", "lea", "14"),
    ("spark", "Un éclat dans le noir", "ines.danse", "14A"),
    ("dunes", "Des dunes au crépuscule", "jade", "15"),
    ("window", "Une fenêtre, un matin", "noah.cuisine", "15A"),
    ("moon", "La lune au-dessus des toits", "jade", "16"),
];

/// Ce que les Rushs et la Planche savent faire.
pub const SOCIAL: [&str; 8] = [
    "Découvertes et Mes suivis",
    "Sons et musiques autorisés",
    "Minutage image par image",
    "Planche-contact des amis",
    "Crayon gras pour entourer",
    "Éclats ✦ sans compteur public",
    "Partager en Flash ou dans Talka",
    "Abonnement par QR code",
];

/// `12400` → `12,4 k`, à la française.
pub fn compact(n: u32) -> String {
    match n {
        0..1_000 => n.to_string(),
        1_000..1_000_000 => {
            let tenths = n / 100;
            if tenths.is_multiple_of(10) {
                format!("{} k", tenths / 10)
            } else {
                format!("{},{} k", tenths / 10, tenths % 10)
            }
        }
        _ => format!("{},{} M", n / 1_000_000, (n / 100_000) % 10),
    }
}

/// Les formats FLASHA : (nom, dimensions, détails, poids indicatif).
pub const FORMATS: [(&str, &str, &str, &str); 2] = [
    (
        "FLASHA Photo",
        "1080 × 1440",
        "HEIC, recadrée et réduite automatiquement, sans position GPS ni métadonnées.",
        "≈ 200 Ko au lieu de 3 Mo",
    ),
    (
        "FLASHA Vidéo",
        "1080 × 1920 · 30 i/s",
        "HEVC à 2,5 Mbit/s, son AAC stéréo, lecture immédiate.",
        "≈ 19 Mo la minute au lieu de 170 Mo",
    ),
];

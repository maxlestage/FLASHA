//! Les textes du site, tirés du cahier des charges de FLASHA.

/// Une carte : icône (nom dans `icons`), titre, texte.
pub struct Card {
    pub icon: &'static str,
    pub title: &'static str,
    pub text: &'static str,
}

/// Les cinq expériences réunies dans FLASHA.
pub const EXPERIENCES: [Card; 5] = [
    Card {
        icon: "camera",
        title: "Caméra",
        text: "Prête à l'ouverture. Photo d'un appui court, vidéo d'un appui long, zoom, flash, minuteur et mise au point tactile.",
    },
    Card {
        icon: "bolt",
        title: "Snaps",
        text: "Des photos et vidéos éphémères, de 1 seconde à sans limite, avec accusés d'ouverture et relecture autorisée ou non.",
    },
    Card {
        icon: "chat",
        title: "Talka",
        text: "La messagerie complète : messages, vocaux, réactions, groupes, appels audio et vidéo.",
    },
    Card {
        icon: "stories",
        title: "Stories",
        text: "Le quotidien en photos et vidéos pendant 24 heures, pour tout le monde, les amis ou les meilleurs amis.",
    },
    Card {
        icon: "compass",
        title: "Découvrir",
        text: "Vidéos courtes, créateurs, tendances et défis, dans un flux vertical que l'on personnalise.",
    },
];

/// Les outils de l'éditeur, montrés en défilement continu.
pub const EDITOR: [&str; 14] = [
    "Texte",
    "Dessin",
    "Autocollants",
    "Emojis",
    "GIF",
    "Musique",
    "Recadrage",
    "Filtres",
    "Luminosité",
    "Contraste",
    "Sous-titres",
    "Voix off",
    "Ralenti",
    "Transitions",
];

/// Les fonctions exclusives de Talka : (nom, description).
pub const TALKA: [(&str, &str); 7] = [
    (
        "Talka Flash",
        "Une photo envoyée directement dans la conversation.",
    ),
    (
        "Talka Replay",
        "Revoir un média quand son expéditeur l'autorise.",
    ),
    (
        "Talka Live",
        "Partager une vidéo en direct avec un ami, le temps d'un moment.",
    ),
    (
        "Talka Moments",
        "Des albums partagés, alimentés à plusieurs.",
    ),
    (
        "Talka Notes",
        "Des notes personnelles, envoyées à qui l'on veut.",
    ),
    (
        "Talka Stories",
        "Une story partagée directement dans une conversation.",
    ),
    (
        "Talka Nearby",
        "Des amis à proximité, seulement avec consentement.",
    ),
];

/// Les amis dont la story s'affiche : (prénom, initiale, nouvelle story ?).
pub const STORIES: [(&str, &str, bool); 6] = [
    ("Léa", "L", true),
    ("Sam", "S", true),
    ("Inès", "I", true),
    ("Noah", "N", false),
    ("Jade", "J", true),
    ("Yanis", "Y", false),
];

/// Qui peut voir chaque publication.
pub const AUDIENCES: [&str; 5] = [
    "Tout le monde",
    "Mes amis",
    "Mes meilleurs amis",
    "Une liste personnalisée",
    "Une seule personne",
];

/// La confidentialité, dès la conception.
pub const PRIVACY: [Card; 6] = [
    Card {
        icon: "lock",
        title: "Conversations chiffrées",
        text: "Chiffrement en transit et au repos, et de bout en bout pour les conversations privées, pensé dès l'architecture.",
    },
    Card {
        icon: "shield",
        title: "Comptes protégés",
        text: "Double authentification, connexion biométrique, appareils connectés et déconnexion à distance.",
    },
    Card {
        icon: "eye",
        title: "Visibilité au choix",
        text: "Qui peut vous écrire, vous appeler, voir vos stories ou votre présence en ligne : vous décidez.",
    },
    Card {
        icon: "pin",
        title: "Localisation désactivée",
        text: "La géolocalisation est coupée par défaut et se règle séparément, personne par personne.",
    },
    Card {
        icon: "flag",
        title: "Protection contre les abus",
        text: "Blocage, signalement, filtres anti-spam, modération des contenus publics et procédure d'appel.",
    },
    Card {
        icon: "scale",
        title: "RGPD et DSA",
        text: "Effacement, portabilité, protection des mineurs et signalement des contenus illicites.",
    },
];

/// La feuille de route : (phase, titre, étapes).
pub const ROADMAP: [(&str, &str, &str); 5] = [
    (
        "Phase 1",
        "Le socle social",
        "Comptes, profils, amis, caméra, éditeur simple, Snaps et leur expiration, notifications.",
    ),
    (
        "Phase 2",
        "Talka",
        "Messages privés, médias, vocaux, groupes, appels audio et vidéo, réactions.",
    ),
    (
        "Phase 3",
        "Réseau social",
        "Stories, meilleurs amis, souvenirs, profils publics, Découvrir, créateurs.",
    ),
    (
        "Phase 4",
        "Expérience avancée",
        "Filtres AR, FLASHA AI, FLASHA Studio, albums collaboratifs, FLASHA Live.",
    ),
    (
        "Phase 5",
        "Commercialisation",
        "FLASHA+, boutique de filtres, outils créateurs, international.",
    ),
];

/// Ce qui fera la différence : (domaine, ambition).
pub const EDGE: [(&str, &str); 6] = [
    ("Caméra", "Capture rapide et éditeur plus complet"),
    ("Messagerie", "Talka, une vraie messagerie complète"),
    ("Confidentialité", "Des contrôles précis et transparents"),
    ("Souvenirs", "Albums et sauvegardes mieux organisés"),
    (
        "Création",
        "Filtres, réalité augmentée et intelligence artificielle",
    ),
    ("Communauté", "Amis et créateurs dans la même application"),
];

/// Les offres : (nom, prix, mention, avantages, mise en avant ?).
pub const PLANS: [(&str, &str, &str, &[&str], bool); 2] = [
    (
        "FLASHA Free",
        "0 €",
        "Pour tout le monde, pour toujours.",
        &[
            "Caméra et éditeur",
            "Snaps et Talka",
            "Stories et Découvrir",
            "Appels audio et vidéo",
            "Filtres classiques",
            "Souvenirs limités",
        ],
        false,
    ),
    (
        "FLASHA+",
        "4,99 €",
        "Par mois, prix indicatif.",
        &[
            "Stockage étendu",
            "Filtres exclusifs",
            "Personnalisation avancée",
            "Statistiques supplémentaires",
            "Outils de création",
            "Fonctionnalités exclusives",
        ],
        true,
    ),
];

/// Les modules à venir, en badges.
pub const LABS: [(&str, &str); 6] = [
    (
        "FLASHA AI",
        "Amélioration des photos, suppression d'objets, sous-titres.",
    ),
    (
        "FLASHA AR",
        "Effets 3D, masques, avatars et expériences interactives.",
    ),
    (
        "FLASHA Studio",
        "Un éditeur vidéo avancé pour préparer ses publications.",
    ),
    (
        "FLASHA Live",
        "Diffusions en direct et événements communautaires.",
    ),
    (
        "FLASHA Creator",
        "Stickers, filtres et effets créés par la communauté.",
    ),
    (
        "FLASHA Moments",
        "Albums collaboratifs, voyages et anniversaires.",
    ),
];

//! Le serveur du site de FLASHA : une page rendue par le serveur avec ses balises
//! SEO, des îlots WebAssembly et une scène 2D, la sécurité de Paquets devant
//! chaque requête.
//!
//!     paquets dev      # http://localhost:3000

use flasha::content::{
    AUDIENCES, Card, EDGE, EDITOR, EXPERIENCES, LABS, PLANS, PRIVACY, ROADMAP, STORIES, TALKA,
};
use flasha::{camera, flash, scene, talka};
use paquets::prelude::*;

mod export;

const DESCRIPTION: &str = "FLASHA, l'application sociale du partage instantané : caméra, Flashs éphémères, Talka la messagerie, Stories et Découvrir. Sur iOS et Android.";

/// Le logo : un flash photographique stylisé.
const LOGO: &str = r##"<svg viewBox="0 0 48 48" width="34" height="34" aria-hidden="true" focusable="false"><defs><linearGradient id="lg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8b5cf6"/><stop offset=".55" stop-color="#ec4899"/><stop offset="1" stop-color="#fb923c"/></linearGradient></defs><rect width="48" height="48" rx="14" fill="url(#lg)"/><path d="M27 7 13 27h9l-3 14 16-21h-9l1-13z" fill="#fff"/></svg>"##;

fn icon(name: &str) -> Element {
    let path = match name {
        "camera" => {
            r#"<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/>"#
        }
        "bolt" => r#"<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>"#,
        "chat" => {
            r#"<path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 8.6 8.6 0 0 1-3.8-.9L3 21l1.9-5.7a8.4 8.4 0 0 1-.9-3.8 8.5 8.5 0 0 1 8.4-8.5A8.4 8.4 0 0 1 21 11.5z"/>"#
        }
        "stories" => {
            r#"<circle cx="12" cy="12" r="9" stroke-dasharray="4 3"/><circle cx="12" cy="12" r="4"/>"#
        }
        "compass" => {
            r#"<circle cx="12" cy="12" r="10"/><path d="m16.2 7.8-2.1 6.3-6.3 2.1 2.1-6.3z"/>"#
        }
        "lock" => {
            r#"<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>"#
        }
        "shield" => {
            r#"<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>"#
        }
        "eye" => {
            r#"<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>"#
        }
        "pin" => {
            r#"<path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/><path d="m4 4 16 16"/>"#
        }
        "flag" => {
            r#"<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><path d="M4 22v-7"/>"#
        }
        "scale" => {
            r#"<path d="M12 3v18"/><path d="M5 21h14"/><path d="m3 13 3-7 3 7a3 3 0 0 1-6 0z"/><path d="m15 13 3-7 3 7a3 3 0 0 1-6 0z"/><path d="M6 6h12"/>"#
        }
        "check" => r#"<path d="M20 6 9 17l-5-5"/>"#,
        "apple" => {
            r#"<path d="M16.4 12.6c0-2.4 2-3.5 2-3.6a4.3 4.3 0 0 0-3.4-1.8c-1.4-.2-2.8.8-3.5.8s-1.8-.8-3-.8a4.5 4.5 0 0 0-3.8 2.3c-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7c1.3 0 2.1-1.1 2.8-2.3a10 10 0 0 0 1.3-2.6 3.9 3.9 0 0 1-2.5-3.6zM14.2 5.6a3.9 3.9 0 0 0 .9-2.8 4 4 0 0 0-2.6 1.3 3.7 3.7 0 0 0-.9 2.7 3.3 3.3 0 0 0 2.6-1.2z"/>"#
        }
        _ => r#"<path d="M5 3l14 9-14 9V3z"/>"#,
    };
    span().class("ico").attr("aria-hidden", "true").html(format!(
        r#"<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" focusable="false">{path}</svg>"#
    ))
}

/// Un titre de section, avec son sur-titre.
fn heading(kicker: &str, title: &str, lead: &str) -> Element {
    div()
        .class("heading")
        .attr("data-reveal", "")
        .child(span().class("kicker").text(kicker.to_owned()))
        .child(h2().text(title.to_owned()))
        .child(p().class("lead").text(lead.to_owned()))
}

fn card(card: &Card, i: usize) -> Element {
    article()
        .class("card")
        .attr("data-reveal", "")
        .style(format!("--i:{i}"))
        .child(icon(card.icon))
        .child(h3().text(card.title))
        .child(p().text(card.text))
}

fn header_bar() -> Element {
    header().class("top").child(
        div()
            .class("wrap top__inner")
            .child(
                a().class("brand")
                    .href("#accueil")
                    .attr("aria-label", "FLASHA, accueil")
                    .child(span().class("brand__logo").html(LOGO))
                    .child(span().class("brand__name").text("FLASHA")),
            )
            .child(
                nav()
                    .class("top__nav")
                    .attr("aria-label", "Sections")
                    .child(a().href("#experiences").text("Expériences"))
                    .child(a().href("#flashs").text("Flashs"))
                    .child(a().href("#talka").text("Talka"))
                    .child(a().href("#confidentialite").text("Confidentialité"))
                    .child(a().href("#offres").text("Offres")),
            )
            .child(
                a().class("btn btn--primary btn--sm")
                    .href("#telecharger")
                    .text("Télécharger"),
            ),
    )
}

fn hero() -> Element {
    section()
        .class("hero")
        .id("accueil")
        .child(div().class("hero__glow").attr("aria-hidden", "true"))
        .child(
            div()
                .class("wrap hero__grid")
                .child(
                    div()
                        .class("hero__text")
                        .child(span().class("pill").text("📸 Le partage instantané, autrement"))
                        .child(
                            h1().child(span().class("hero__brand").text("FLASHA"))
                                .child(span().class("hero__tag").text("Capture the moment.")),
                        )
                        .child(p().class("lead").text(
                            "Une caméra au centre, des Flashs éphémères, Talka pour discuter, des Stories pour partager son quotidien et un espace pour découvrir. Une seule application, rapide et sûre.",
                        ))
                        .child(
                            div()
                                .class("hero__cta")
                                .child(a().class("btn btn--primary").href("#telecharger").text("Rejoindre la bêta"))
                                .child(a().class("btn btn--ghost").href("#experiences").text("Découvrir FLASHA")),
                        )
                        .child(
                            ul().class("tags")
                                .attr("aria-label", "Plateformes et fonctions")
                                .child(li().text("iOS"))
                                .child(li().text("Android"))
                                .child(li().text("Photos & vidéos"))
                                .child(li().text("Messagerie Talka")),
                        ),
                )
                .child(
                    div()
                        .class("hero__device")
                        .child(
                            div()
                                .class("phone")
                                .child(span().class("phone__notch").attr("aria-hidden", "true"))
                                .child(
                                    div()
                                        .class("phone__screen")
                                        .child(island("scene", "", scene))
                                        .child(
                                            div()
                                                .class("phone__ui")
                                                .attr("aria-hidden", "true")
                                                .child(span().class("phone__top").text("FLASHA"))
                                                .child(span().class("phone__hint").text("Touchez l'écran ✨"))
                                                .child(
                                                    span()
                                                        .class("phone__shutter")
                                                        .child(span()),
                                                ),
                                        ),
                                ),
                        )
                        .child(span().class("float float--a").attr("aria-hidden", "true").text("❤️"))
                        .child(span().class("float float--b").attr("aria-hidden", "true").text("⚡"))
                        .child(span().class("float float--c").attr("aria-hidden", "true").text("💬"))
                        .child(
                            div()
                                .class("toast")
                                .attr("aria-hidden", "true")
                                .child(span().class("toast__dot"))
                                .child(span().text("Léa a ouvert ton Flash")),
                        ),
                ),
        )
}

fn experiences() -> Element {
    section()
        .class("section")
        .id("experiences")
        .child(
            div()
                .class("wrap")
                .child(heading(
                    "Une application, cinq expériences",
                    "Tout ce qui compte, au même endroit",
                    "Caméra, Flashs, Talka, Stories et Découvrir : une navigation en cinq onglets, avec la caméra au centre.",
                ))
                .child(
                    div()
                        .class("grid grid--cards")
                        .children(EXPERIENCES.iter().enumerate().map(|(i, c)| card(c, i))),
                )
                .child(
                    nav()
                        .class("tabbar")
                        .attr("aria-label", "Aperçu de la navigation de l'application")
                        .attr("data-reveal", "")
                        .child(span().text("Amis"))
                        .child(span().text("Talka"))
                        .child(span().class("tabbar__cam").attr("aria-label", "Caméra").child(icon("camera")))
                        .child(span().text("Découvrir"))
                        .child(span().text("Profil")),
                ),
        )
}

fn camera_section() -> Element {
    section()
        .class("section section--alt")
        .id("camera")
        .child(
            div()
                .class("wrap split")
                .child(
                    div()
                        .child(heading(
                            "La caméra FLASHA",
                            "Ouverte en un instant",
                            "Un appui court pour une photo, un appui long pour filmer. Choisissez un filtre et déclenchez : la démo ci-contre est écrite en Rust.",
                        ))
                        .child(
                            ul().class("checks")
                                .attr("data-reveal", "")
                                .children(
                                    [
                                        "Caméra avant et arrière, zoom progressif",
                                        "Flash, minuteur, grille et mise au point tactile",
                                        "Mode portrait et haute résolution",
                                        "Pause et reprise pendant l'enregistrement",
                                    ]
                                    .into_iter()
                                    .map(|t| li().child(icon("check")).child(span().text(t))),
                                ),
                        ),
                )
                .child(div().class("demo").attr("data-reveal", "").child(island("camera", "", camera))),
        )
        .child(
            div()
                .class("marquee")
                .attr("aria-label", "Les outils de l'éditeur")
                .child(
                    div()
                        .class("marquee__track")
                        .children(EDITOR.iter().chain(EDITOR.iter()).enumerate().map(|(i, t)| {
                            span()
                                .class("marquee__item")
                                .attr_if_hidden(i >= EDITOR.len())
                                .text(*t)
                        })),
                ),
        )
}

/// Les doublons de la bande défilante sont cachés aux lecteurs d'écran.
trait HiddenCopy {
    fn attr_if_hidden(self, hidden: bool) -> Self;
}

impl HiddenCopy for Element {
    fn attr_if_hidden(self, hidden: bool) -> Self {
        if hidden {
            self.attr("aria-hidden", "true")
        } else {
            self
        }
    }
}

fn flashs() -> Element {
    section()
        .class("section")
        .id("flashs")
        .child(
            div()
                .class("wrap split split--rev")
                .child(
                    div()
                        .child(heading(
                            "Le système Flash",
                            "Éphémère, et vraiment sous contrôle",
                            "Choisissez combien de temps votre Flash reste à l'écran, s'il peut être revu, et à qui il est envoyé. Essayez :",
                        ))
                        .child(
                            p().class("note")
                                .attr("data-reveal", "")
                                .text("Les captures d'écran sont signalées quand c'est détectable, mais un contenu éphémère peut toujours être photographié par un autre appareil : FLASHA le dit clairement."),
                        ),
                )
                .child(div().class("demo").attr("data-reveal", "").child(island("flash", "", flash))),
        )
}

fn talka_section() -> Element {
    section()
        .class("section section--alt")
        .id("talka")
        .child(
            div()
                .class("wrap split")
                .child(
                    div()
                        .child(heading(
                            "Talka, la messagerie intégrée",
                            "Discuter comme on en a envie",
                            "Messages, vocaux, GIF, réactions, groupes et appels vidéo. Écrivez à Léa, elle répond.",
                        ))
                        .child(
                            ul().class("features")
                                .children(TALKA.iter().enumerate().map(|(i, (name, text))| {
                                    li().attr("data-reveal", "")
                                        .style(format!("--i:{i}"))
                                        .child(strong().text(*name))
                                        .child(span().text(*text))
                                })),
                        ),
                )
                .child(div().class("demo demo--sticky").attr("data-reveal", "").child(island("talka", "", talka))),
        )
}

fn stories() -> Element {
    section()
        .class("section")
        .id("stories")
        .child(
            div()
                .class("wrap")
                .child(heading(
                    "Stories et amis",
                    "Votre quotidien, pour qui vous voulez",
                    "Des stories de 24 heures par défaut, des réactions rapides et des réponses privées. Chaque publication a son public.",
                ))
                .child(
                    ul().class("stories")
                        .attr("aria-label", "Stories de vos amis")
                        .attr("data-reveal", "")
                        .children(STORIES.iter().enumerate().map(|(i, (name, initial, new))| {
                            li().class(if *new { "story story--new" } else { "story" })
                                .style(format!("--i:{i}"))
                                .child(span().class("story__ring").attr("aria-hidden", "true").child(span().class("story__avatar").text(*initial)))
                                .child(span().class("story__name").text(*name))
                        })),
                )
                .child(
                    div()
                        .class("audience")
                        .attr("data-reveal", "")
                        .child(h3().text("Qui peut voir cette story ?"))
                        .child(
                            ul().class("audience__list").children(AUDIENCES.iter().enumerate().map(|(i, a)| {
                                li().class(if i == 1 { "opt is-on" } else { "opt" }).text(*a)
                            })),
                        ),
                ),
        )
}

fn privacy() -> Element {
    section()
        .class("section section--dark")
        .id("confidentialite")
        .child(
            div()
                .class("wrap")
                .child(heading(
                    "Confidentialité et sécurité",
                    "La sécurité dès la conception",
                    "Une application qui transporte vos photos et vidéos personnelles doit les protéger dès le premier jour, pas à la fin du développement.",
                ))
                .child(div().class("grid grid--cards").children(PRIVACY.iter().enumerate().map(|(i, c)| card(c, i)))),
        )
}

fn edge() -> Element {
    section()
        .class("section")
        .id("difference")
        .child(
            div()
                .class("wrap")
                .child(heading(
                    "Ce qui fait la différence",
                    "Pas une copie : une identité",
                    "FLASHA reprend ce qui fait le succès des applications de partage instantané, avec ses propres avantages.",
                ))
                .child(
                    div().class("grid grid--edge").children(EDGE.iter().enumerate().map(|(i, (domain, goal))| {
                        div().class("edge")
                            .attr("data-reveal", "")
                            .style(format!("--i:{i}"))
                            .child(span().class("edge__domain").text(*domain))
                            .child(p().text(*goal))
                    })),
                )
                .child(
                    div().class("labs").children(LABS.iter().enumerate().map(|(i, (name, text))| {
                        div().class("lab")
                            .attr("data-reveal", "")
                            .style(format!("--i:{i}"))
                            .child(strong().text(*name))
                            .child(span().text(*text))
                    })),
                ),
        )
}

fn roadmap() -> Element {
    section()
        .class("section section--alt")
        .id("feuille-de-route")
        .child(
            div()
                .class("wrap")
                .child(heading(
                    "Feuille de route",
                    "Un MVP solide, puis l'ambition",
                    "Une caméra excellente et une messagerie fiable d'abord : c'est plus important qu'une centaine de fonctions inachevées.",
                ))
                .child(
                    ol().class("timeline").children(ROADMAP.iter().enumerate().map(|(i, (phase, title, text))| {
                        li().attr("data-reveal", "")
                            .style(format!("--i:{i}"))
                            .child(span().class("timeline__dot").attr("aria-hidden", "true"))
                            .child(span().class("kicker").text(*phase))
                            .child(h3().text(*title))
                            .child(p().text(*text))
                    })),
                ),
        )
}

fn plans() -> Element {
    section()
        .class("section")
        .id("offres")
        .child(
            div()
                .class("wrap")
                .child(heading(
                    "Offres",
                    "Gratuit pour l'essentiel",
                    "Envoyer des photos, discuter et appeler ne sera jamais payant. FLASHA+ ajoute du stockage et des outils de création.",
                ))
                .child(
                    div().class("grid grid--plans").children(PLANS.iter().map(|(name, price, note, perks, featured)| {
                        article()
                            .class(if *featured { "plan plan--featured" } else { "plan" })
                            .attr("data-reveal", "")
                            .child(h3().text(*name))
                            .child(p().class("plan__price").text(*price))
                            .child(p().class("muted").text(*note))
                            .child(ul().class("checks").children(perks.iter().map(|p| li().child(icon("check")).child(span().text(*p)))))
                    })),
                ),
        )
}

fn download() -> Element {
    section().class("section cta").id("telecharger").child(
        div()
            .class("wrap cta__inner")
            .attr("data-reveal", "")
            .child(span().class("cta__logo").html(LOGO))
            .child(h2().text("Every moment deserves a flash."))
            .child(p().class("lead").text(
                "FLASHA arrive d'abord sur iPhone, puis sur Android. Inscrivez-vous pour la bêta.",
            ))
            .child(
                div()
                    .class("stores")
                    .child(
                        a().class("store")
                            .href("#telecharger")
                            .attr("aria-label", "Bientôt sur l'App Store")
                            .child(icon("apple"))
                            .child(
                                span()
                                    .child(small().text("Bientôt sur"))
                                    .child(strong().text("App Store")),
                            ),
                    )
                    .child(
                        a().class("store")
                            .href("#telecharger")
                            .attr("aria-label", "Bientôt sur Google Play")
                            .child(icon("play"))
                            .child(
                                span()
                                    .child(small().text("Bientôt sur"))
                                    .child(strong().text("Google Play")),
                            ),
                    ),
            ),
    )
}

fn footer_bar() -> Element {
    footer().class("foot").child(
        div()
            .class("wrap foot__inner")
            .child(
                div()
                    .class("brand")
                    .child(span().class("brand__logo").html(LOGO))
                    .child(span().class("brand__name").text("FLASHA")),
            )
            .child(p().class("muted").text("Capture. Share. Connect."))
            .child(
                p().class("muted small")
                    .text("© 2026 FLASHA. Site écrit en Rust avec Paquets."),
            ),
    )
}

async fn home(_req: Request) -> Page {
    Page::new("FLASHA — Capture the moment.")
        .lang("fr")
        .description(DESCRIPTION)
        .plain()
        .stylesheet(concat!("/flasha.css?v=", env!("CARGO_PKG_VERSION")))
        .head(r##"<link rel="icon" href="/favicon.svg" type="image/svg+xml"/><meta name="color-scheme" content="dark light"/>"##)
        .view_transitions()
        .body(a().class("skip").href("#contenu").text("Aller au contenu"))
        .body(header_bar())
        .body(
            html::main()
                .id("contenu")
                .child(hero())
                .child(experiences())
                .child(camera_section())
                .child(flashs())
                .child(talka_section())
                .child(stories())
                .child(privacy())
                .child(edge())
                .child(roadmap())
                .child(plans())
                .child(download()),
        )
        .body(footer_bar())
}

fn app() -> App {
    let mut app = App::new();
    app.get("/", home);
    app.health("/health");
    app.pwa(Pwa::new("FLASHA").theme_color("#0d0618"));
    app
}

fn main() -> std::io::Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        // `flasha export dist` : le site statique, pour GitHub Pages.
        Some("export") => {
            let out = std::path::PathBuf::from(args.get(1).map_or("dist", String::as_str));
            let base = std::env::var("BASE_PATH").unwrap_or_default();
            let runtime = tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()?;
            let written = runtime.block_on(export::export(app(), &out, &base))?;
            println!("{written} fichiers écrits dans {}", out.display());
            Ok(())
        }
        _ => app().run(), // $PORT sur Heroku, 3000 sinon
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn the_home_page_has_every_section() {
        let client = app().test().await;
        let res = client.get("/").await;
        assert_eq!(res.status(), 200);
        let html = res.text();
        for id in [
            "accueil",
            "experiences",
            "camera",
            "flashs",
            "talka",
            "stories",
            "confidentialite",
            "offres",
            "telecharger",
        ] {
            assert!(html.contains(&format!(r#"id="{id}""#)), "section {id}");
        }
        for name in ["scene", "camera", "flash", "talka"] {
            assert!(
                html.contains(&format!(r#"name="{name}""#)) || html.contains(name),
                "island {name}"
            );
        }
        assert!(html.contains("Capture the moment."));
        assert!(html.contains(r#"lang="fr""#));
        assert!(html.contains("width=device-width"), "mobile viewport");
    }

    #[tokio::test]
    async fn static_files_and_health() {
        let client = app().test().await;
        assert_eq!(client.get("/health").await.status(), 200);
        assert_eq!(client.get("/manifest.webmanifest").await.status(), 200);
    }
}

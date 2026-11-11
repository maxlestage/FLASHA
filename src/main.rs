//! Le serveur de FLASHA : la page de présentation (rendue par le serveur, avec ses
//! îlots WebAssembly et sa scène 2D), installable comme une application (PWA), et le
//! relais sans base de données. La sécurité de Paquets est devant chaque requête.
//!
//!     paquets dev      # http://localhost:3000

use flasha::content::{
    AUDIENCES, Card, EDGE, EDITOR, EXPERIENCES, FORMATS, LABS, PLANS, PRIVACY, ROADMAP, SOCIAL,
    STORIES, TALKA,
};
use flasha::share::SHARE_TEXT;
use flasha::{camera, clips, fil, flash, install, scene, share, talka};
use paquets::active::Seo;
use paquets::prelude::*;

mod export;
mod relay;

const TITLE: &str = "FLASHA — Chaque instant se révèle.";
const DESCRIPTION: &str = "FLASHA, l'appli photo où chaque instant se révèle : Flashs éphémères, Pellicule de 24 poses, Planche des amis, Talka. Tout chiffré sur ton téléphone, sans base de données.";

/// Les couleurs de FLASHA (voir `public/flasha.css`).
const PAPER: &str = "#F2ECE1";

/// Le logo, « l'Éclat » : un tirage rond sur fond cyanotype, et l'étincelle du flash.
const LOGO: &str = r##"<svg viewBox="0 0 48 48" width="34" height="34" aria-hidden="true" focusable="false"><rect width="48" height="48" rx="11" fill="#1D3FD1"/><circle cx="21.5" cy="27" r="12.5" fill="#F2ECE1"/><path d="M34.5 4C35.4 10.6 36.9 12.1 43.5 13C36.9 13.9 35.4 15.4 34.5 22C33.6 15.4 32.1 13.9 25.5 13C32.1 12.1 33.6 10.6 34.5 4Z" fill="#FF5B2E"/></svg>"##;

/// L'éclat ✦ de FLASHA, en grand.
const SPARK: &str = r##"<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 1.5c.7 5.3 2.2 6.8 7.5 7.5-5.3.7-6.8 2.2-7.5 7.5-.7-5.3-2.2-6.8-7.5-7.5 5.3-.7 6.8-2.2 7.5-7.5z" fill="currentColor"/></svg>"##;

/// L'adresse publique du site, avec une barre finale : `SITE_URL` si elle est réglée
/// (l'export pour GitHub Pages), sinon celle de la requête (Heroku, en local…).
fn public_url(req: &Request) -> String {
    if let Ok(url) = std::env::var("SITE_URL")
        && !url.trim().is_empty()
    {
        let url = url.trim().trim_end_matches('/');
        return format!("{url}/");
    }
    let host = req
        .header("x-forwarded-host")
        .or_else(|| req.header("host"))
        .unwrap_or("localhost:3000");
    let scheme = req.header("x-forwarded-proto").unwrap_or(
        if host.starts_with("localhost") || host.starts_with("127.") {
            "http"
        } else {
            "https"
        },
    );
    format!("{scheme}://{host}/")
}

/// Un texte pour une adresse (`?text=`).
fn encode(text: &str) -> String {
    let mut out = String::with_capacity(text.len() * 3);
    for byte in text.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(byte as char)
            }
            _ => out.push_str(&format!("%{byte:02X}")),
        }
    }
    out
}

/// Le QR code d'une adresse, en SVG, aux couleurs de FLASHA.
fn qr_svg(url: &str) -> String {
    use qrcode::render::svg;
    qrcode::QrCode::new(url.as_bytes()).map_or_else(
        |_| String::new(),
        |code| {
            code.render::<svg::Color>()
                .min_dimensions(220, 220)
                .quiet_zone(true)
                .dark_color(svg::Color("#15130F"))
                .light_color(svg::Color("#FBF8F2"))
                .build()
        },
    )
}

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
        "roll" => {
            r#"<rect x="3" y="6" width="12" height="14" rx="2"/><path d="M6 6V4h6v2"/><path d="M15 9h4a2 2 0 0 1 2 2v2h-6"/><path d="M7 10h4M7 14h4"/>"#
        }
        "sheet" => {
            r#"<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M9 3v18M15 3v18"/>"#
        }
        "reel" => {
            r#"<rect x="5" y="2" width="14" height="20" rx="2"/><path d="M9 2v20M15 2v20"/><path d="M5 6h4M5 10h4M5 14h4M5 18h4M15 6h4M15 10h4M15 14h4M15 18h4"/>"#
        }
        "message" => {
            r#"<path d="M4 5h16a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H9l-5 4V6a1 1 0 0 1 1-1z"/>"#
        }
        "mail" => r#"<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>"#,
        "send" => r#"<path d="M22 2 11 13"/><path d="M22 2 15 22l-4-9-9-4 20-7z"/>"#,
        "phone" => r#"<rect x="6" y="2" width="12" height="20" rx="3"/><path d="M11 18h2"/>"#,
        "plus" => r#"<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M12 8v8M8 12h8"/>"#,
        "dots" => {
            r#"<circle cx="12" cy="5" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="19" r="1.5"/>"#
        }
        _ => r#"<path d="M5 3l14 9-14 9V3z"/>"#,
    };
    span().class("ico").attr("aria-hidden", "true").html(format!(
        r#"<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" focusable="false">{path}</svg>"#
    ))
}

/// Un titre de section : le numéro de vue, le sur-titre, le titre et le chapeau.
fn heading(number: &str, kicker: &str, title: &str, lead: &str) -> Element {
    div()
        .class("heading")
        .attr("data-reveal", "")
        .child(
            span()
                .class("kicker")
                .child(span().class("kicker__num").text(number.to_owned()))
                .child(span().text(kicker.to_owned())),
        )
        .child(h2().html(title.to_owned()))
        .child(p().class("lead").text(lead.to_owned()))
}

/// Une carte, présentée comme un tirage numéroté.
fn card(card: &Card, i: usize) -> Element {
    article()
        .class("card")
        .attr("data-reveal", "")
        .style(format!("--i:{i}"))
        .child(icon(card.icon))
        .child(span().class("card__num").text(format!("N° {:02}", i + 1)))
        .child(h3().text(card.title))
        .child(p().text(card.text))
}

/// Une bande de pellicule, avec ses repères de vue.
fn film_edge(start: usize) -> Element {
    div()
        .class("film")
        .attr("aria-hidden", "true")
        .child(div().class("film__track").children((0..2).map(|_| {
            span().class("film__run").text(
                (start..start + 8)
                    .map(|n| format!("FLASHA 400 ▸ {n} ▸ {n}A"))
                    .collect::<Vec<_>>()
                    .join("   "),
            )
        })))
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
                    .child(span().class("brand__name").text("flasha")),
            )
            .child(
                nav()
                    .class("top__nav")
                    .attr("aria-label", "Sections")
                    .child(a().href("#experiences").text("L'appli"))
                    .child(a().href("#flashs").text("Flashs"))
                    .child(a().href("#pellicule").text("Pellicule"))
                    .child(a().href("#planche").text("Planche"))
                    .child(a().href("#talka").text("Talka"))
                    .child(a().href("#confidentialite").text("Secret")),
            )
            .child(
                a().class("btn btn--primary btn--sm")
                    .href("#installer")
                    .text("Installer"),
            ),
    )
}

fn hero() -> Element {
    section()
        .class("hero")
        .id("accueil")
        .child(
            div()
                .class("wrap hero__grid")
                .child(
                    div()
                        .class("hero__text")
                        .child(span().class("stamp").text("N° 001 · FLASHA 400 · 24 POSES"))
                        .child(h1().html("Chaque instant <em>se révèle.</em>"))
                        .child(p().class("lead").text(
                            "FLASHA est l'appli photo qui prend son temps : vos images se développent sous vos yeux, votre journée tient en 24 poses, et vos amis se retrouvent sur une planche-contact. Tout est chiffré sur votre téléphone.",
                        ))
                        .child(
                            div()
                                .class("hero__cta")
                                .child(a().class("btn btn--primary").href("#installer").text("Installer FLASHA"))
                                .child(a().class("btn btn--ghost").href("#partager").text("Partager à un ami")),
                        )
                        .child(
                            ul().class("tags")
                                .attr("aria-label", "Où utiliser FLASHA")
                                .child(li().text("iPhone"))
                                .child(li().text("Android"))
                                .child(li().text("Navigateur"))
                                .child(li().text("Sans base de données")),
                        ),
                )
                .child(
                    div()
                        .class("hero__visual")
                        .child(
                            div()
                                .class("viewfinder")
                                .child(island("scene", "", scene))
                                .child(
                                    div()
                                        .class("viewfinder__ui")
                                        .attr("aria-hidden", "true")
                                        .child(span().class("viewfinder__corner viewfinder__corner--tl"))
                                        .child(span().class("viewfinder__corner viewfinder__corner--tr"))
                                        .child(span().class("viewfinder__corner viewfinder__corner--bl"))
                                        .child(span().class("viewfinder__corner viewfinder__corner--br"))
                                        .child(span().class("viewfinder__count").text("12 / 24"))
                                        .child(span().class("viewfinder__hint").text("Touchez le viseur"))
                                        .child(span().class("viewfinder__date").text("11 11 '26")),
                                ),
                        )
                        .child(
                            figure()
                                .class("tirage tirage--a")
                                .attr("aria-hidden", "true")
                                .html(r##"<svg viewBox="0 0 100 100"><rect width="100" height="100" fill="#1D3FD1"/><circle cx="68" cy="34" r="16" fill="#F2ECE1"/><path d="M0 70 Q25 60 50 70 T100 70 V100 H0Z" fill="#0B1E6E"/></svg>"##),
                        )
                        .child(
                            figure()
                                .class("tirage tirage--b")
                                .attr("aria-hidden", "true")
                                .html(r##"<svg viewBox="0 0 100 100"><rect width="100" height="100" fill="#FF5B2E"/><circle cx="50" cy="50" r="28" fill="#FFB199"/><circle cx="50" cy="50" r="14" fill="#FBF8F2"/></svg>"##),
                        )
                        .child(
                            div()
                                .class("note-card")
                                .attr("aria-hidden", "true")
                                .child(span().class("note-card__spark").html(SPARK))
                                .child(span().text("Léa vous envoie un éclat")),
                        ),
                ),
        )
        .child(film_edge(1))
}

fn experiences() -> Element {
    section()
        .class("section")
        .id("experiences")
        .child(
            div()
                .class("wrap")
                .child(heading(
                    "02",
                    "L'appli",
                    "Six pièces, <em>un atelier</em>",
                    "FLASHA s'ouvre sur la chambre, la caméra. Autour : les Flashs, la Pellicule, la Planche, Talka et les Rushs.",
                ))
                .child(
                    div()
                        .class("grid grid--cards")
                        .children(EXPERIENCES.iter().enumerate().map(|(i, c)| card(c, i))),
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
                            "03",
                            "La chambre",
                            "Ouverte d'un geste, <em>développée</em> sous vos yeux",
                            "Un appui court pour une photo, un appui long pour filmer. Choisissez un tirage, Cyanotype, Argentique, Halo ou Sépia, et déclenchez : la démo ci-contre est écrite en Rust.",
                        ))
                        .child(
                            ul().class("checks")
                                .attr("data-reveal", "")
                                .children(
                                    [
                                        "Caméra avant et arrière, zoom au pincement",
                                        "Flash, grille et mise au point tactile",
                                        "Filtres argentiques et cadre papier",
                                        "Dateur orange, comme sur les vieux appareils",
                                    ]
                                    .into_iter()
                                    .map(|t| li().child(icon("check")).child(span().text(t))),
                                ),
                        ),
                )
                .child(
                    div()
                        .class("demo")
                        .attr("data-reveal", "")
                        .child(island("camera", "", camera)),
                ),
        )
        .child(
            div()
                .class("wrap formats")
                .children(FORMATS.iter().enumerate().map(
                    |(i, (name, size, details, weight))| {
                        article()
                            .class("format")
                            .attr("data-reveal", "")
                            .style(format!("--i:{i}"))
                            .child(span().class("kicker").text(*name))
                            .child(strong().class("format__size").text(*size))
                            .child(p().text(*details))
                            .child(span().class("format__weight").text(*weight))
                    },
                )),
        )
        .child(
            div()
                .class("marquee")
                .attr("aria-label", "Les outils de l'atelier")
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
    section().class("section").id("flashs").child(
        div()
            .class("wrap split split--rev")
            .child(
                div()
                    .child(heading(
                        "04",
                        "Les Flashs",
                        "Un instant, <em>puis plus rien</em>",
                        "Choisissez combien de temps votre Flash reste à l'écran, s'il peut être revu, et à qui il part. À l'ouverture, la photo se développe. Essayez :",
                    ))
                    .child(p().class("note").attr("data-reveal", "").text(
                        "Les captures d'écran sont signalées quand c'est détectable, mais un contenu éphémère peut toujours être photographié par un autre appareil : FLASHA le dit clairement.",
                    )),
            )
            .child(
                div()
                    .class("demo")
                    .attr("data-reveal", "")
                    .child(island("flash", "", flash)),
            ),
    )
}

fn pellicule() -> Element {
    section()
        .class("section section--alt")
        .id("pellicule")
        .child(
            div()
                .class("wrap")
                .child(heading(
                    "05",
                    "La Pellicule",
                    "24 poses par jour, <em>pas une de plus</em>",
                    "Votre journée tient sur une pellicule : 24 images au plus, visibles 24 heures par ceux que vous choisissez. On choisit ses moments plutôt que de les accumuler.",
                ))
                .child(
                    ul().class("rolls")
                        .attr("aria-label", "Pellicules du jour de vos amis")
                        .children(STORIES.iter().enumerate().map(|(i, (name, initial, shots))| {
                            let shots = usize::from(*shots);
                            li().class("roll")
                                .attr("data-reveal", "")
                                .style(format!("--i:{i}"))
                                .child(
                                    div()
                                        .class("roll__head")
                                        .child(span().class("roll__avatar").attr("aria-hidden", "true").text(*initial))
                                        .child(span().class("roll__name").text(*name))
                                        .child(span().class("roll__count").text(format!("{shots}/24"))),
                                )
                                .child(
                                    div()
                                        .class("roll__strip")
                                        .attr("role", "img")
                                        .attr("aria-label", format!("{shots} poses sur 24"))
                                        .children((0..24).map(move |n| {
                                            span().class(if n < shots { "roll__pose is-on" } else { "roll__pose" })
                                        })),
                                )
                        })),
                )
                .child(
                    div()
                        .class("audience")
                        .attr("data-reveal", "")
                        .child(h3().text("Qui voit ma Pellicule aujourd'hui ?"))
                        .child(ul().class("audience__list").children(
                            AUDIENCES.iter().enumerate().map(|(i, a)| {
                                li().class(if i == 1 { "opt is-on" } else { "opt" }).text(*a)
                            }),
                        )),
                ),
        )
}

fn social() -> Element {
    section()
        .class("section")
        .id("planche")
        .child(
            div()
                .class("wrap")
                .child(heading(
                    "06",
                    "La Planche et les Rushs",
                    "Les tirages des amis, <em>entourés au crayon</em>",
                    "La Planche range les photos de vos amis comme une planche-contact : touchez un tirage pour l'entourer et l'agrandir. Les Rushs, ce sont les vidéos courtes, image par image. On réagit d'un éclat ✦, en privé, sans compteur public.",
                ))
                .child(
                    div()
                        .class("social")
                        .child(
                            div()
                                .class("social__demo")
                                .attr("data-reveal", "")
                                .child(h3().class("social__label").text("La Planche"))
                                .child(island("fil", "", fil)),
                        )
                        .child(
                            div()
                                .class("social__demo")
                                .id("rushs")
                                .attr("data-reveal", "")
                                .child(h3().class("social__label").text("Les Rushs"))
                                .child(island("clips", "", clips)),
                        ),
                )
                .child(
                    ul().class("social__features")
                        .attr("data-reveal", "")
                        .children(
                            SOCIAL
                                .iter()
                                .map(|f| li().child(icon("check")).child(span().text(*f))),
                        ),
                ),
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
                            "07",
                            "Talka",
                            "La messagerie, <em>chiffrée de bout en bout</em>",
                            "Messages, vocaux, réactions, groupes et appels. Ce que vous écrivez n'est lisible que par la personne à qui vous l'envoyez. Écrivez à Léa, elle répond.",
                        ))
                        .child(ul().class("features").children(TALKA.iter().enumerate().map(
                            |(i, (name, text))| {
                                li().attr("data-reveal", "")
                                    .style(format!("--i:{i}"))
                                    .child(strong().text(*name))
                                    .child(span().text(*text))
                            },
                        ))),
                )
                .child(
                    div()
                        .class("demo demo--sticky")
                        .attr("data-reveal", "")
                        .child(island("talka", "", talka)),
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
                    "08",
                    "La chambre noire",
                    "Vos photos ne sortent <em>pas d'ici</em>",
                    "Tout est chiffré sur votre téléphone, sans base de données. Pour s'abonner et s'écrire, les téléphones passent par un relais qui ne garde rien et ne peut rien lire.",
                ))
                .child(
                    div()
                        .class("grid grid--cards")
                        .children(PRIVACY.iter().enumerate().map(|(i, c)| card(c, i))),
                ),
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
                    "09",
                    "Notre patte",
                    "Pas une copie : <em>un atelier</em>",
                    "FLASHA puise dans la photographie argentique, le papier, l'encre et le cyanotype, plutôt que dans les codes des autres réseaux.",
                ))
                .child(div().class("grid grid--edge").children(EDGE.iter().enumerate().map(
                    |(i, (domain, goal))| {
                        div()
                            .class("edge")
                            .attr("data-reveal", "")
                            .style(format!("--i:{i}"))
                            .child(span().class("edge__domain").text(*domain))
                            .child(p().text(*goal))
                    },
                )))
                .child(div().class("labs").children(LABS.iter().enumerate().map(
                    |(i, (name, text))| {
                        div()
                            .class("lab")
                            .attr("data-reveal", "")
                            .style(format!("--i:{i}"))
                            .child(strong().text(*name))
                            .child(span().text(*text))
                    },
                ))),
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
                    "10",
                    "Feuille de route",
                    "Pose après pose",
                    "Une chambre excellente et des messages fiables d'abord : c'est plus important qu'une centaine de fonctions inachevées.",
                ))
                .child(ol().class("timeline").children(ROADMAP.iter().enumerate().map(
                    |(i, (phase, title, text))| {
                        li().attr("data-reveal", "")
                            .style(format!("--i:{i}"))
                            .child(span().class("timeline__dot").attr("aria-hidden", "true"))
                            .child(span().class("kicker").text(*phase))
                            .child(h3().text(*title))
                            .child(p().text(*text))
                    },
                ))),
        )
}

fn plans() -> Element {
    section().class("section").id("offres").child(
        div()
            .class("wrap")
            .child(heading(
                "11",
                "Offres",
                "Gratuit pour <em>l'essentiel</em>",
                "Photographier, envoyer, écrire et appeler ne sera jamais payant. Pas de publicité : FLASHA+ fait vivre l'atelier.",
            ))
            .child(
                div()
                    .class("grid grid--plans")
                    .children(PLANS.iter().map(|(name, price, note, perks, featured)| {
                        article()
                            .class(if *featured { "plan plan--featured" } else { "plan" })
                            .attr("data-reveal", "")
                            .child(h3().text(*name))
                            .child(p().class("plan__price").text(*price))
                            .child(p().class("muted").text(*note))
                            .child(ul().class("checks").children(
                                perks.iter().map(|p| li().child(icon("check")).child(span().text(*p))),
                            ))
                    })),
            ),
    )
}

/// Partager FLASHA : la feuille de partage du téléphone, des liens directs vers les
/// messageries, et un QR code à scanner.
fn share_section(url: &str) -> Element {
    let text = format!("{SHARE_TEXT} {url}");
    let links = [
        (
            "message",
            "Messages",
            format!("sms:?&body={}", encode(&text)),
        ),
        (
            "send",
            "WhatsApp",
            format!("https://wa.me/?text={}", encode(&text)),
        ),
        (
            "send",
            "Telegram",
            format!(
                "https://t.me/share/url?url={}&text={}",
                encode(url),
                encode(SHARE_TEXT)
            ),
        ),
        (
            "mail",
            "E-mail",
            format!(
                "mailto:?subject={}&body={}",
                encode("Viens sur FLASHA"),
                encode(&text)
            ),
        ),
    ];
    section()
        .class("section section--alt")
        .id("partager")
        .child(
            div()
                .class("wrap split")
                .child(
                    div()
                        .child(heading(
                            "12",
                            "Partager",
                            "Envoyez FLASHA <em>à un ami</em>",
                            "Un message, et c'est fait : le lien s'ouvre sur ce site, avec son aperçu, et s'installe en un geste.",
                        ))
                        .child(island("share", url.to_owned(), share))
                        .child(
                            ul().class("share__links").attr("data-reveal", "").children(links.into_iter().map(
                                |(glyph, name, href)| {
                                    li().child(
                                        a().class("share__link")
                                            .href(href)
                                            .attr("rel", "noopener")
                                            .child(icon(glyph))
                                            .child(span().text(name)),
                                    )
                                },
                            )),
                        ),
                )
                .child(
                    figure()
                        .class("qr")
                        .attr("data-reveal", "")
                        .child(div().class("qr__code").attr("role", "img").attr("aria-label", "QR code du site FLASHA").html(qr_svg(url)))
                        .child(
                            figcaption()
                                .child(strong().text("Scannez pour ouvrir FLASHA"))
                                .child(span().class("qr__url").text(url.to_owned())),
                        ),
                ),
        )
}

/// Installer FLASHA sur l'écran d'accueil, comme une application (PWA).
fn install_section() -> Element {
    section()
        .class("section cta")
        .id("installer")
        .child(
            div()
                .class("wrap")
                .child(heading(
                    "13",
                    "Installer",
                    "FLASHA sur votre <em>écran d'accueil</em>",
                    "Pas besoin de boutique : FLASHA s'installe depuis ce site, en plein écran, et fonctionne même hors connexion.",
                ))
                .child(island("install", "", install))
                .child(
                    div()
                        .class("steps")
                        .child(
                            article()
                                .class("step")
                                .attr("data-reveal", "")
                                .child(span().class("kicker").text("iPhone · Safari"))
                                .child(ol().children(
                                    [
                                        "Ouvrez ce site dans Safari.",
                                        "Touchez le bouton Partager, en bas de l'écran.",
                                        "Choisissez « Sur l'écran d'accueil », puis « Ajouter ».",
                                    ]
                                    .into_iter()
                                    .map(|t| li().text(t)),
                                )),
                        )
                        .child(
                            article()
                                .class("step")
                                .attr("data-reveal", "")
                                .child(span().class("kicker").text("Android · Chrome"))
                                .child(ol().children(
                                    [
                                        "Touchez « Installer FLASHA » ci-dessus.",
                                        "Ou ouvrez le menu ⋮ de Chrome.",
                                        "Choisissez « Installer l'application ».",
                                    ]
                                    .into_iter()
                                    .map(|t| li().text(t)),
                                )),
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
                    .child(span().class("brand__name").text("flasha")),
            )
            .child(p().class("foot__motto").text("Chaque instant se révèle."))
            .child(p().class("muted small").text(
                "© 2026 FLASHA. Site écrit en Rust avec Paquets, sans traceur ni base de données.",
            )),
    )
}

async fn home(req: Request) -> Page {
    let url = public_url(&req);
    Page::new(TITLE)
        .lang("fr")
        .description(DESCRIPTION)
        .seo(
            Seo::new()
                .canonical(url.clone())
                .image(format!("{url}og.png"))
                .site_name("FLASHA")
                .locale("fr_FR"),
        )
        .plain()
        .stylesheet(concat!("/flasha.css?v=", env!("CARGO_PKG_VERSION")))
        .head(r##"<link rel="icon" href="/favicon.svg" type="image/svg+xml"/><link rel="preload" href="/fonts/fraunces-normal-400-900.woff2" as="font" type="font/woff2" crossorigin/><meta name="color-scheme" content="light dark"/><meta name="apple-mobile-web-app-status-bar-style" content="default"/>"##)
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
                .child(pellicule())
                .child(social())
                .child(talka_section())
                .child(privacy())
                .child(edge())
                .child(roadmap())
                .child(plans())
                .child(share_section(&url))
                .child(install_section()),
        )
        .body(footer_bar())
}

fn app() -> App {
    let mut app = App::new();
    app.get("/", home);
    // Le relais sans base : il ne fait que transmettre des paquets chiffrés.
    let relay = relay::Relay::new(relay::Limits::default());
    app.get("/relay", move |req: Request| {
        relay::handler(relay.clone(), req)
    });
    app.health("/health");
    // Installable comme une application : plein écran, hors connexion, nos icônes.
    app.pwa(
        Pwa::new("FLASHA")
            .short_name("FLASHA")
            .description("L'appli photo où chaque instant se révèle.")
            .id("/")
            .start_url("/")
            .scope("/")
            .display("standalone")
            .orientation("portrait")
            .lang("fr")
            .theme_color(PAPER)
            .background_color(PAPER)
            .categories(["photo", "social"])
            .icon("/icons/icon-192.png", "192x192", "image/png")
            .icon("/icons/icon-512.png", "512x512", "image/png")
            .maskable_icon("/icons/icon-maskable-512.png", "512x512", "image/png"),
    );
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
            "pellicule",
            "planche",
            "rushs",
            "talka",
            "confidentialite",
            "offres",
            "partager",
            "installer",
        ] {
            assert!(html.contains(&format!(r#"id="{id}""#)), "section {id}");
        }
        for name in [
            "scene", "camera", "flash", "talka", "clips", "fil", "share", "install",
        ] {
            assert!(html.contains(name), "island {name}");
        }
        assert!(html.contains("se révèle"));
        assert!(html.contains(r#"lang="fr""#));
        assert!(html.contains("width=device-width"), "mobile viewport");
        assert!(html.contains("og.png"), "share preview image");
        assert!(html.contains("wa.me/?text="), "WhatsApp link");
        assert!(html.contains("<svg"), "QR code");
    }

    #[tokio::test]
    async fn it_is_an_installable_app() {
        let client = app().test().await;
        assert_eq!(client.get("/health").await.status(), 200);
        let manifest = client.get("/manifest.webmanifest").await;
        assert_eq!(manifest.status(), 200);
        let manifest = manifest.text();
        assert!(manifest.contains(r#""display":"standalone""#), "{manifest}");
        assert!(manifest.contains("/icons/icon-512.png"), "{manifest}");
        assert!(manifest.contains("maskable"), "{manifest}");
        assert_eq!(client.get("/sw.js").await.status(), 200);
    }

    #[test]
    fn share_texts_are_encoded() {
        assert_eq!(encode("a b&c"), "a%20b%26c");
        assert_eq!(encode("é"), "%C3%A9");
        assert!(qr_svg("https://example.com/").contains("<svg"));
    }
}

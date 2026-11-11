//! FLASHA : ce que le serveur et le navigateur partagent.
//!
//! Le serveur (`src/main.rs`) rend ces composants en HTML ; compilé en WebAssembly,
//! ce fichier rend les îlots interactifs dans le navigateur, et la scène 2D
//! (`scene.rs`, avec le moteur `paquets::ecs`) s'anime dans le téléphone du héros.

use paquets::prelude::*;

pub mod content;
pub mod share;
pub mod social;

pub use share::{install, share};
pub use social::{clips, fil};

#[cfg(target_arch = "wasm32")]
mod scene;

/// Chaque îlot, sous le nom donné à [`island`].
pub const ISLANDS: [(&str, paquets::active::IslandFn); 8] = [
    ("scene", scene),
    ("camera", camera),
    ("flash", flash),
    ("talka", talka),
    ("clips", clips),
    ("fil", fil),
    ("share", share),
    ("install", install),
];

// ----- La scène 2D -------------------------------------------------------------------

/// Le viseur : une scène 2D de grains d'argent qui montent, et un
/// éclat de particules à chaque toucher.
pub fn scene(_props: &str) -> Node {
    canvas()
        .class("flash-canvas")
        .attr("role", "img")
        .attr(
            "aria-label",
            "Animation : des grains bleus, orange et noirs qui montent. Touchez le viseur pour déclencher un éclat.",
        )
        .use_action(play)
        .into()
}

#[cfg(target_arch = "wasm32")]
fn play(canvas: &paquets::active::Dom) -> impl FnOnce() + use<> {
    let running = scene::start(canvas);
    move || drop(running)
}

#[cfg(not(target_arch = "wasm32"))]
fn play(_canvas: &paquets::active::Dom) -> impl FnOnce() + use<> {
    || {}
}

// ----- La caméra -----------------------------------------------------------------------

/// Les filtres de la caméra de démonstration : (nom affiché, classe CSS).
pub const FILTERS: [(&str, &str); 5] = [
    ("Naturel", "f-natural"),
    ("Cyanotype", "f-cyano"),
    ("Argentique", "f-silver"),
    ("Halo", "f-halo"),
    ("Sépia", "f-sepia"),
];

/// Une caméra de démonstration : des filtres, photo ou vidéo, et un déclencheur
/// qui fait un vrai flash.
pub fn camera(_props: &str) -> Node {
    let filter = use_state(0usize);
    let shots = use_state(0u32);
    let video = use_state(false);
    let recording = use_state(false);

    div()
        .class("cam")
        .child(
            div()
                .class("cam__view")
                .class_if("f-natural", move || filter.get() == 0)
                .class_if("f-cyano", move || filter.get() == 1)
                .class_if("f-silver", move || filter.get() == 2)
                .class_if("f-halo", move || filter.get() == 3)
                .class_if("f-sepia", move || filter.get() == 4)
                .class_if("is-recording", move || recording.get())
                .child(
                    div()
                        .class("cam__scene")
                        .attr("aria-hidden", "true")
                        .html(SCENE_SVG),
                )
                .child(
                    span()
                        .class("cam__flash")
                        .class_if("go-a", move || shots.get() % 2 == 1)
                        .class_if("go-b", move || {
                            shots.get() > 0 && shots.get().is_multiple_of(2)
                        })
                        .attr("aria-hidden", "true"),
                )
                .child(span().class("cam__grid").attr("aria-hidden", "true"))
                .child(
                    span()
                        .class("cam__rec")
                        .bool_attr("hidden", move || !recording.get())
                        .text("● REC"),
                )
                .child(
                    span()
                        .class("cam__count")
                        .attr("aria-live", "polite")
                        .text_dyn(move || match shots.get() {
                            0 => "Prêt".to_owned(),
                            1 => "1 photo".to_owned(),
                            n => format!("{n} photos"),
                        }),
                ),
        )
        .child(
            div()
                .class("chips")
                .attr("role", "group")
                .attr("aria-label", "Filtres")
                .children(FILTERS.iter().enumerate().map(|(i, (name, _))| {
                    button()
                        .class("chip")
                        .class_if("is-on", move || filter.get() == i)
                        .attr("type", "button")
                        .attr_dyn("aria-pressed", move || (filter.get() == i).to_string())
                        .on_click(move |_| filter.set(i))
                        .text(*name)
                })),
        )
        .child(
            div()
                .class("cam__bar")
                .child(
                    button()
                        .class("cam__mode")
                        .attr("type", "button")
                        .attr_dyn("aria-pressed", move || video.get().to_string())
                        .on_click(move |_| {
                            video.update(|v| *v = !*v);
                            recording.set(false);
                        })
                        .text_dyn(move || if video.get() { "Vidéo" } else { "Photo" }.to_owned()),
                )
                .child(
                    button()
                        .class("shutter")
                        .class_if("is-video", move || video.get())
                        .class_if("is-recording", move || recording.get())
                        .attr("type", "button")
                        .attr_dyn("aria-label", move || {
                            if !video.get() {
                                "Prendre une photo"
                            } else if recording.get() {
                                "Arrêter l'enregistrement"
                            } else {
                                "Filmer"
                            }
                            .to_owned()
                        })
                        .on_click(move |_| {
                            if video.get() {
                                recording.update(|r| *r = !*r);
                            } else {
                                shots.update(|n| *n += 1);
                            }
                        })
                        .child(span().class("shutter__core")),
                )
                .child(span().class("cam__hint").text_dyn(move || {
                    if video.get() {
                        "Appui long pour filmer"
                    } else {
                        "Appui court : photo"
                    }
                    .to_owned()
                })),
        )
        .into()
}

/// Le paysage vu par la caméra : un coucher de soleil en 2D, animé en CSS.
const SCENE_SVG: &str = r##"<svg viewBox="0 0 320 400" preserveAspectRatio="xMidYMid slice" focusable="false">
<defs>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1D3FD1"/><stop offset=".6" stop-color="#7C93FF"/><stop offset="1" stop-color="#FFB199"/></linearGradient>
<radialGradient id="sun" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#FFF3E6"/><stop offset=".55" stop-color="#FF7A4D"/><stop offset="1" stop-color="#FF5B2E" stop-opacity="0"/></radialGradient>
</defs>
<rect width="320" height="400" fill="url(#sky)"/>
<g class="sc-stars" fill="#fff"><circle cx="40" cy="50" r="1.4"/><circle cx="110" cy="30" r="1"/><circle cx="200" cy="60" r="1.6"/><circle cx="270" cy="35" r="1.1"/><circle cx="160" cy="95" r="1"/><circle cx="290" cy="110" r="1.3"/></g>
<circle class="sc-sun" cx="160" cy="250" r="70" fill="url(#sun)"/>
<g class="sc-cloud" fill="#ffffff" fill-opacity=".35"><ellipse cx="70" cy="140" rx="46" ry="12"/><ellipse cx="96" cy="132" rx="26" ry="11"/></g>
<g class="sc-cloud sc-cloud--2" fill="#ffffff" fill-opacity=".25"><ellipse cx="240" cy="180" rx="40" ry="10"/><ellipse cx="258" cy="173" rx="22" ry="9"/></g>
<path d="M0 300 L60 250 L110 285 L170 235 L230 290 L280 255 L320 280 L320 400 L0 400Z" fill="#132C94"/>
<path d="M0 330 L70 300 L140 335 L210 305 L270 330 L320 312 L320 400 L0 400Z" fill="#15130F"/>
<g class="sc-waves" stroke="#F2ECE1" stroke-opacity=".5" stroke-width="2" fill="none"><path d="M20 365 q20 -8 40 0 t40 0"/><path d="M180 375 q20 -8 40 0 t40 0"/></g>
</svg>"##;

// ----- Les Flashs -----------------------------------------------------------------------

/// Les durées d'expiration d'un Flash : (libellé, secondes ; 0 = sans limite).
pub const DURATIONS: [(&str, u32); 6] = [
    ("1 s", 1),
    ("3 s", 3),
    ("5 s", 5),
    ("10 s", 10),
    ("30 s", 30),
    ("∞", 0),
];

/// Un Flash de démonstration : choisir sa durée, l'ouvrir, le voir expirer, et
/// le revoir une fois si l'expéditeur l'autorise.
pub fn flash(_props: &str) -> Node {
    let chosen = use_state(2usize);
    // 0 : pas encore ouvert, 1 : ouvert, 2 : expiré.
    let phase = use_state(0u8);
    let runs = use_state(0u32);
    let replay = use_state(true);
    let replayed = use_state(false);
    let seconds = move || DURATIONS[chosen.get()].1;

    let open = move || {
        phase.set(1);
        runs.update(|n| *n += 1);
    };

    div()
        .class("flashdemo")
        .child(
            div()
                .class("chips")
                .attr("role", "group")
                .attr("aria-label", "Durée d'affichage")
                .children(DURATIONS.iter().enumerate().map(|(i, (label, _))| {
                    button()
                        .class("chip")
                        .class_if("is-on", move || chosen.get() == i)
                        .attr("type", "button")
                        .attr_dyn("aria-pressed", move || (chosen.get() == i).to_string())
                        .on_click(move |_| {
                            chosen.set(i);
                            phase.set(0);
                            replayed.set(false);
                        })
                        .text(*label)
                })),
        )
        .child(
            label()
                .class("switch")
                .child(
                    input()
                        .attr("type", "checkbox")
                        .bind_checked(replay)
                        .on("change", move |_| replayed.set(false)),
                )
                .child(span().class("switch__track").attr("aria-hidden", "true"))
                .child(span().text("Autoriser une relecture")),
        )
        .child(
            div()
                .class("flashdemo__stage")
                .class_if("is-open", move || phase.get() == 1)
                .class_if("is-expired", move || phase.get() == 2)
                .child(
                    div()
                        .class("flashdemo__closed")
                        .bool_attr("hidden", move || phase.get() != 0)
                        .child(span().class("flashdemo__badge").attr("aria-hidden", "true"))
                        .child(strong().text("Nouveau Flash de Léa"))
                        .child(
                            button()
                                .class("btn btn--primary")
                                .attr("type", "button")
                                .on_click(move |_| open())
                                .text("Ouvrir le Flash"),
                        ),
                )
                .child(
                    div()
                        .class("flashdemo__open")
                        .bool_attr("hidden", move || phase.get() != 1)
                        .child(
                            div()
                                .class("flashdemo__photo")
                                .attr("aria-hidden", "true")
                                .html(FLASH_SVG),
                        )
                        .child(
                            span()
                                .class("ring")
                                .class_if("run-a", move || seconds() > 0 && runs.get() % 2 == 1)
                                .class_if("run-b", move || {
                                    seconds() > 0 && runs.get().is_multiple_of(2)
                                })
                                .attr_dyn("style", move || format!("--dur:{}s", seconds().max(1)))
                                .attr("aria-hidden", "true")
                                .on("animationend", move |_| phase.set(2))
                                .child(span().class("ring__label").text_dyn(
                                    move || match seconds() {
                                        0 => "∞".to_owned(),
                                        s => format!("{s}s"),
                                    },
                                )),
                        )
                        .child(
                            button()
                                .class("flashdemo__close")
                                .attr("type", "button")
                                .attr("aria-label", "Fermer le Flash")
                                .on_click(move |_| phase.set(2))
                                .text("✕"),
                        ),
                )
                .child(
                    div()
                        .class("flashdemo__gone")
                        .bool_attr("hidden", move || phase.get() != 2)
                        .attr("aria-live", "polite")
                        .child(strong().text("Flash expiré"))
                        .child(p().class("muted").text_dyn(move || {
                            if replay.get() && !replayed.get() {
                                "L'expéditeur autorise une relecture."
                            } else if replayed.get() {
                                "Relecture utilisée : l'expéditeur en est informé."
                            } else {
                                "Il n'est conservé nulle part, sauf si l'expéditeur l'a voulu."
                            }
                            .to_owned()
                        }))
                        .child(
                            button()
                                .class("btn btn--ghost")
                                .attr("type", "button")
                                .bool_attr("hidden", move || !replay.get() || replayed.get())
                                .on_click(move |_| {
                                    replayed.set(true);
                                    open();
                                })
                                .text("Revoir une fois"),
                        )
                        .child(
                            button()
                                .class("btn btn--ghost")
                                .attr("type", "button")
                                .on_click(move |_| {
                                    phase.set(0);
                                    replayed.set(false);
                                })
                                .text("Recevoir un autre Flash"),
                        ),
                ),
        )
        .into()
}

/// La photo du Flash de démonstration.
const FLASH_SVG: &str = r##"<svg viewBox="0 0 300 300" preserveAspectRatio="xMidYMid slice" focusable="false">
<defs><linearGradient id="sn" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1D3FD1"/><stop offset="1" stop-color="#2E5BFF"/></linearGradient></defs>
<rect width="300" height="300" fill="url(#sn)"/>
<g class="sn-confetti"><rect x="40" y="40" width="10" height="18" rx="3" fill="#FF5B2E"/><rect x="230" y="60" width="10" height="18" rx="3" fill="#fff" transform="rotate(30 235 69)"/><circle cx="70" cy="230" r="7" fill="#fff"/><circle cx="250" cy="220" r="6" fill="#FF5B2E"/></g>
<circle cx="150" cy="140" r="62" fill="#F2ECE1"/>
<circle cx="128" cy="128" r="8" fill="#15130F"/><circle cx="172" cy="128" r="8" fill="#15130F"/>
<path d="M120 158 q30 28 60 0" stroke="#15130F" stroke-width="8" fill="none" stroke-linecap="round"/>
<text x="150" y="262" text-anchor="middle" font-size="26" font-weight="800" fill="#fff" font-family="Fraunces,serif" font-style="italic">Coucou ✦</text>
</svg>"##;

// ----- Talka ---------------------------------------------------------------------------

/// Un message de Talka : (de moi ?, texte).
type Message = (bool, String);

/// Les réponses de Léa, à tour de rôle.
pub const REPLIES: [&str; 5] = [
    "Trop bien ! Envoie-moi un Flash ✦",
    "Je t'appelle en vidéo dans 5 min ?",
    "Ajouté à notre Planche partagée",
    "Haha 😂 j'adore",
    "On se retrouve ce soir ?",
];

/// Une conversation Talka : écrire, envoyer, et Léa répond.
pub fn talka(_props: &str) -> Node {
    let messages = use_state(vec![
        (false, "Salut ! Tu as vu la Pellicule de Sam ?".to_owned()),
        (true, "Oui, le coucher de soleil était fou".to_owned()),
    ]);
    let draft = use_state(String::new());
    let sent = use_state(0usize);

    let send = move || {
        let text = draft.with(|d| d.trim().to_owned());
        if text.is_empty() {
            return;
        }
        let reply = REPLIES[sent.get() % REPLIES.len()].to_owned();
        messages.update(|m: &mut Vec<Message>| {
            m.push((true, text));
            m.push((false, reply));
            // Seuls les derniers messages restent à l'écran.
            let extra = m.len().saturating_sub(8);
            m.drain(..extra);
        });
        sent.update(|n| *n += 1);
        draft.set(String::new());
    };

    div()
        .class("talka")
        .child(
            div()
                .class("talka__head")
                .child(
                    span()
                        .class("avatar avatar--lea")
                        .attr("aria-hidden", "true")
                        .text("L"),
                )
                .child(
                    div()
                        .child(strong().text("Léa"))
                        .child(span().class("talka__status").text("en ligne")),
                )
                .child(
                    div()
                        .class("talka__actions")
                        .attr("aria-hidden", "true")
                        .html(CALL_ICONS),
                ),
        )
        .child(
            div()
                .class("talka__list")
                .attr("role", "log")
                .attr("aria-live", "polite")
                .attr("aria-label", "Conversation avec Léa")
                .children_dyn(move || {
                    let all = messages.get();
                    let last = all.len().saturating_sub(1);
                    all.into_iter()
                        .enumerate()
                        .map(|(i, (mine, text))| {
                            let reply = !mine && i == last && sent.get() > 0;
                            div()
                                .class(if mine { "bubble bubble--me" } else { "bubble" })
                                .class_if("bubble--reply", move || reply)
                                .text(text)
                                .into()
                        })
                        .collect()
                }),
        )
        .child(
            form()
                .class("talka__form")
                .on_submit(move |_| send())
                .child(
                    input()
                        .attr("type", "text")
                        .attr("name", "message")
                        .attr("placeholder", "Écrire à Léa…")
                        .attr("aria-label", "Message")
                        .attr("autocomplete", "off")
                        .attr("enterkeyhint", "send")
                        .attr("maxlength", "200")
                        .bind_value(draft),
                )
                .child(
                    button()
                        .class("talka__send")
                        .attr("type", "submit")
                        .attr("aria-label", "Envoyer")
                        .html(SEND_ICON),
                ),
        )
        .into()
}

const CALL_ICONS: &str = r#"<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.4 1.8.7 2.7a2 2 0 0 1-.5 2.1L8 9.8a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.7.7a2 2 0 0 1 1.7 2z"/></svg><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m23 7-7 5 7 5V7z"/><rect x="1" y="5" width="15" height="14" rx="2"/></svg>"#;

const SEND_ICON: &str = r#"<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M22 2 11 13"/><path d="M22 2 15 22l-4-9-9-4 20-7z"/></svg>"#;

// ----- Le navigateur -------------------------------------------------------------------

/// Le point d'entrée du navigateur : rend chaque îlot de la page interactif.
#[cfg(target_arch = "wasm32")]
#[wasm_bindgen::prelude::wasm_bindgen(start)]
pub fn start() {
    paquets::hydrate(&ISLANDS);
}

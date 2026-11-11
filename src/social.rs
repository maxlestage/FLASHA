//! Les Clips (des vidéos courtes, verticales, une par écran) et le Fil (les
//! publications photo en carrousel) : deux îlots, rendus par le serveur et
//! interactifs dans le navigateur. Les décors sont des scènes 2D animées en CSS.

use paquets::prelude::*;

use crate::content::{CLIPS, SLIDES, compact};

/// La position du pointeur d'un événement (`clientX`, `clientY`).
#[cfg(target_arch = "wasm32")]
fn pointer(e: &paquets::active::Event) -> (f64, f64) {
    use wasm_bindgen::JsCast;
    e.raw()
        .dyn_ref::<web_sys::MouseEvent>()
        .map_or((0.0, 0.0), |m| {
            (f64::from(m.client_x()), f64::from(m.client_y()))
        })
}

#[cfg(not(target_arch = "wasm32"))]
fn pointer(_e: &paquets::active::Event) -> (f64, f64) {
    (0.0, 0.0)
}

/// Un geste : `Some(+1)` vers l'avant, `Some(-1)` vers l'arrière, le long de l'axe
/// vertical (`vertical`) ou horizontal, s'il est assez franc.
fn swipe(start: (f64, f64), end: (f64, f64), vertical: bool) -> Option<i32> {
    let (dx, dy) = (end.0 - start.0, end.1 - start.1);
    let (along, across) = if vertical { (dy, dx) } else { (dx, dy) };
    (along.abs() > 40.0 && along.abs() > across.abs()).then_some(if along < 0.0 { 1 } else { -1 })
}

fn svg_icon(path: &str) -> String {
    format!(
        r#"<svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">{path}</svg>"#
    )
}

const HEART: &str = r#"<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8l1 1.1L12 21.2l7.8-7.7 1-1.1a5.5 5.5 0 0 0 0-7.8z"/>"#;
const COMMENT: &str = r#"<path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 8.6 8.6 0 0 1-3.8-.9L3 21l1.9-5.7a8.4 8.4 0 0 1-.9-3.8 8.5 8.5 0 0 1 8.4-8.5A8.4 8.4 0 0 1 21 11.5z"/>"#;
const SHARE: &str = r#"<path d="M22 2 11 13"/><path d="M22 2 15 22l-4-9-9-4 20-7z"/>"#;
const SAVE: &str = r#"<path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>"#;
const REMIX: &str = r#"<path d="M17 1l4 4-4 4"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><path d="M7 23l-4-4 4-4"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/>"#;
const UP: &str = r#"<path d="m18 15-6-6-6 6"/>"#;
const DOWN: &str = r#"<path d="m6 9 6 6 6-6"/>"#;
const LEFT: &str = r#"<path d="m15 18-6-6 6-6"/>"#;
const RIGHT: &str = r#"<path d="m9 18 6-6-6-6"/>"#;

// ----- Les Clips ---------------------------------------------------------------------------

/// Le décor 2D d'un Clip : des formes animées en CSS, différentes pour chaque scène.
fn clip_scene(scene: &str) -> &'static str {
    match scene {
        "sunset" => {
            r##"<svg viewBox="0 0 270 480" preserveAspectRatio="xMidYMid slice" focusable="false"><defs><linearGradient id="c1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3b1d6e"/><stop offset=".6" stop-color="#e2558f"/><stop offset="1" stop-color="#ffb35c"/></linearGradient></defs><rect width="270" height="480" fill="url(#c1)"/><circle class="cl-sun" cx="135" cy="300" r="62" fill="#ffe1a1"/><rect y="330" width="270" height="150" fill="#2a1450"/><g class="cl-waves" stroke="#ffb3d1" stroke-width="3" fill="none" stroke-linecap="round"><path d="M20 360h60M120 380h90M40 410h70M170 430h60"/></g><g class="cl-birds" stroke="#2a1450" stroke-width="3" fill="none"><path d="M60 120q8-8 16 0q8-8 16 0"/><path d="M150 90q6-6 12 0q6-6 12 0"/></g></svg>"##
        }
        "neon" => {
            r##"<svg viewBox="0 0 270 480" preserveAspectRatio="xMidYMid slice" focusable="false"><rect width="270" height="480" fill="#120726"/><g class="cl-grid" stroke="#8b5cf6" stroke-opacity=".5"><path d="M0 330h270M0 370h270M0 420h270M0 480h270M135 300v180M60 300l-60 180M210 300l60 180"/></g><path class="cl-bolt" d="M150 90 95 210h40l-15 100 70-140h-40z" fill="#fb923c"/><circle class="cl-ring" cx="135" cy="200" r="90" fill="none" stroke="#ec4899" stroke-width="4"/></svg>"##
        }
        "dance" => {
            r##"<svg viewBox="0 0 270 480" preserveAspectRatio="xMidYMid slice" focusable="false"><defs><radialGradient id="c3" cx=".5" cy=".3" r=".8"><stop offset="0" stop-color="#f472b6"/><stop offset="1" stop-color="#4c1d95"/></radialGradient></defs><rect width="270" height="480" fill="url(#c3)"/><g class="cl-dancer" fill="#fff"><circle cx="135" cy="170" r="22"/><path d="M135 195v90" stroke="#fff" stroke-width="14" stroke-linecap="round"/><path class="cl-arm" d="M135 215l-50-30M135 215l50-40" stroke="#fff" stroke-width="10" stroke-linecap="round"/><path d="M135 285l-35 70M135 285l35 70" stroke="#fff" stroke-width="11" stroke-linecap="round"/></g><g class="cl-notes" fill="#fde68a"><circle cx="50" cy="120" r="7"/><circle cx="220" cy="150" r="6"/><circle cx="60" cy="300" r="5"/><circle cx="215" cy="320" r="7"/></g></svg>"##
        }
        _ => {
            r##"<svg viewBox="0 0 270 480" preserveAspectRatio="xMidYMid slice" focusable="false"><rect width="270" height="480" fill="#ffedd5"/><circle cx="135" cy="300" r="95" fill="#1f2937"/><circle cx="135" cy="300" r="75" fill="#374151"/><g class="cl-crepe"><ellipse cx="135" cy="300" rx="62" ry="58" fill="#fbbf24"/><circle cx="115" cy="285" r="8" fill="#f59e0b"/><circle cx="155" cy="315" r="6" fill="#f59e0b"/></g><path d="M230 300h40" stroke="#1f2937" stroke-width="14" stroke-linecap="round"/><g class="cl-steam" stroke="#9ca3af" stroke-width="4" fill="none" stroke-linecap="round"><path d="M110 190q-10-20 0-40"/><path d="M135 180q-10-20 0-40"/><path d="M160 190q-10-20 0-40"/></g></svg>"##
        }
    }
}

/// Les Clips : une vidéo par écran, glisser vers le haut pour la suivante, toucher
/// deux fois pour aimer, suivre les créateurs, et l'onglet Abonnements qui ne
/// montre que les créateurs suivis.
pub fn clips(_props: &str) -> Node {
    let n = CLIPS.len();
    // 0 : Abonnements, 1 : Pour toi.
    let tab = use_state(1usize);
    let current = use_state(0usize);
    let liked = use_state(vec![false; n]);
    let following = use_state(vec![true, true, false, false]);
    let bursts = use_state(vec![0u32; n]);
    let start = use_state((0.0f64, 0.0f64));

    // Les Clips de l'onglet, par leur numéro.
    let visible = move || -> Vec<usize> {
        if tab.get() == 1 {
            (0..n).collect()
        } else {
            following.with(|f| (0..n).filter(|&i| f[i]).collect())
        }
    };
    let position = move || {
        let list = visible();
        list.iter().position(|&i| i == current.get()).unwrap_or(0)
    };
    let go = move |step: i32| {
        let list = visible();
        if list.is_empty() {
            return;
        }
        let at = position() as i32 + step;
        let at = at.clamp(0, list.len() as i32 - 1) as usize;
        current.set(list[at]);
    };
    let like = move |i: usize, toggle: bool| {
        let was = liked.with(|l| l[i]);
        if toggle || !was {
            liked.update(|l| l[i] = !was);
        }
        if !was {
            bursts.update(|b| b[i] += 1);
        }
    };

    div()
        .class("clips")
        .child(
            div()
                .class("clips__tabs")
                .attr("role", "group")
                .attr("aria-label", "Fil de Clips")
                .children(
                    ["Abonnements", "Pour toi"]
                        .into_iter()
                        .enumerate()
                        .map(|(t, label)| {
                            button()
                                .class("clips__tab")
                                .class_if("is-on", move || tab.get() == t)
                                .attr("type", "button")
                                .attr_dyn("aria-pressed", move || (tab.get() == t).to_string())
                                .on_click(move |_| {
                                    tab.set(t);
                                    if let Some(&first) = visible().first() {
                                        current.set(first);
                                    }
                                })
                                .text(label)
                        }),
                ),
        )
        .child(
            div()
                .class("clips__screen")
                .on("pointerdown", move |e| start.set(pointer(&e)))
                .on("pointerup", move |e| {
                    if let Some(step) = swipe(start.get(), pointer(&e), true) {
                        go(step);
                    }
                })
                .child(
                    div()
                        .class("clips__empty")
                        .bool_attr("hidden", move || !visible().is_empty())
                        .text(
                            "Suivez un créateur depuis « Pour toi » pour retrouver ses Clips ici.",
                        ),
                )
                .child(
                    div()
                        .class("clips__track")
                        .attr_dyn("style", move || format!("--at:{}", position()))
                        .children(CLIPS.iter().enumerate().map(|(i, clip)| {
                            clip_view(i, clip, current, liked, following, bursts, visible, like)
                        })),
                )
                .child(
                    div()
                        .class("clips__nav")
                        .child(
                            button()
                                .class("clips__arrow")
                                .attr("type", "button")
                                .attr("aria-label", "Clip précédent")
                                .bool_attr("disabled", move || position() == 0)
                                .on_click(move |_| go(-1))
                                .html(svg_icon(UP)),
                        )
                        .child(
                            button()
                                .class("clips__arrow")
                                .attr("type", "button")
                                .attr("aria-label", "Clip suivant")
                                .bool_attr("disabled", move || position() + 1 >= visible().len())
                                .on_click(move |_| go(1))
                                .html(svg_icon(DOWN)),
                        ),
                ),
        )
        .into()
}

#[allow(clippy::too_many_arguments)]
fn clip_view(
    i: usize,
    clip: &'static crate::content::Clip,
    current: State<usize>,
    liked: State<Vec<bool>>,
    following: State<Vec<bool>>,
    bursts: State<Vec<u32>>,
    visible: impl Fn() -> Vec<usize> + Copy + 'static,
    like: impl Fn(usize, bool) + Copy + 'static,
) -> Element {
    article()
        .class(format!("clip clip--{}", clip.scene))
        .bool_attr("hidden", move || !visible().contains(&i))
        .class_if("is-current", move || current.get() == i)
        .attr("aria-label", format!("Clip de @{}", clip.creator))
        .on("dblclick", move |_| like(i, false))
        .child(
            div()
                .class("clip__scene")
                .attr("aria-hidden", "true")
                .html(clip_scene(clip.scene)),
        )
        .child(
            span()
                .class("clip__burst")
                .class_if("go-a", move || bursts.with(|b| b[i] % 2 == 1))
                .class_if("go-b", move || {
                    bursts.with(|b| b[i] > 0 && b[i].is_multiple_of(2))
                })
                .attr("aria-hidden", "true")
                .html(svg_icon(HEART)),
        )
        .child(
            div()
                .class("clip__rail")
                .child(
                    button()
                        .class("clip__avatar")
                        .attr("type", "button")
                        .class_if("is-followed", move || following.with(|f| f[i]))
                        .attr_dyn("aria-label", move || {
                            if following.with(|f| f[i]) {
                                format!("Ne plus suivre @{}", clip.creator)
                            } else {
                                format!("Suivre @{}", clip.creator)
                            }
                        })
                        .on_click(move |_| following.update(|f| f[i] = !f[i]))
                        .child(span().text(clip.creator[..1].to_uppercase()))
                        .child(
                            span()
                                .class("clip__follow")
                                .attr("aria-hidden", "true")
                                .text_dyn(move || {
                                    if following.with(|f| f[i]) { "✓" } else { "+" }.to_owned()
                                }),
                        ),
                )
                .child(
                    button()
                        .class("clip__action clip__like")
                        .class_if("is-on", move || liked.with(|l| l[i]))
                        .attr("type", "button")
                        .attr_dyn("aria-pressed", move || liked.with(|l| l[i]).to_string())
                        .attr("aria-label", "J'aime")
                        .on_click(move |_| like(i, true))
                        .child(span().class("clip__icon").html(svg_icon(HEART)))
                        .child(span().text_dyn(move || {
                            compact(clip.likes + u32::from(liked.with(|l| l[i])))
                        })),
                )
                .child(
                    span()
                        .class("clip__action")
                        .attr("aria-label", format!("{} commentaires", clip.comments))
                        .child(span().class("clip__icon").html(svg_icon(COMMENT)))
                        .child(span().text(compact(clip.comments))),
                )
                .child(
                    span()
                        .class("clip__action")
                        .attr("aria-label", "Remixer")
                        .child(span().class("clip__icon").html(svg_icon(REMIX)))
                        .child(span().text("Remix")),
                )
                .child(
                    span()
                        .class("clip__action")
                        .attr("aria-label", "Partager")
                        .child(span().class("clip__icon").html(svg_icon(SHARE)))
                        .child(span().text("Partager")),
                )
                .child(span().class("clip__disc").attr("aria-hidden", "true")),
        )
        .child(
            div()
                .class("clip__info")
                .child(strong().text(format!("@{}", clip.creator)))
                .child(p().text(clip.caption))
                .child(
                    div().class("clip__sound").child(
                        span()
                            .class("clip__sound-text")
                            .text(format!("♪ {}", clip.sound)),
                    ),
                ),
        )
        .child(span().class("clip__progress").attr("aria-hidden", "true"))
}

// ----- Le Fil ------------------------------------------------------------------------------

fn slide_scene(scene: &str) -> &'static str {
    match scene {
        "peaks" => {
            r##"<svg viewBox="0 0 400 400" preserveAspectRatio="xMidYMid slice" focusable="false"><defs><linearGradient id="s1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fcd2e4"/><stop offset="1" stop-color="#fb923c"/></linearGradient></defs><rect width="400" height="400" fill="url(#s1)"/><circle class="sl-sun" cx="290" cy="150" r="46" fill="#fff7d6"/><path d="M0 330 110 160l70 90 60-80 160 160v70H0z" fill="#7c3aed"/><path d="M0 360 90 260l80 70 70-50 160 80v40H0z" fill="#4c1d95"/><path d="M110 160l-22 34h44zM240 170l-18 26h36z" fill="#fff"/></svg>"##
        }
        "lake" => {
            r##"<svg viewBox="0 0 400 400" preserveAspectRatio="xMidYMid slice" focusable="false"><rect width="400" height="210" fill="#f9a8d4"/><rect y="210" width="400" height="190" fill="#c084fc"/><circle cx="200" cy="160" r="50" fill="#fff1f2"/><g class="sl-ripples" fill="#fff1f2" fill-opacity=".7"><rect x="150" y="240" width="100" height="6" rx="3"/><rect x="170" y="270" width="60" height="5" rx="2.5"/><rect x="185" y="298" width="30" height="4" rx="2"/></g><path d="M0 210 70 150l50 60z M260 210l70-80 70 80z" fill="#6d28d9"/></svg>"##
        }
        _ => {
            r##"<svg viewBox="0 0 400 400" preserveAspectRatio="xMidYMid slice" focusable="false"><rect width="400" height="400" fill="#0f0a24"/><g class="sl-stars" fill="#fff"><circle cx="40" cy="60" r="2"/><circle cx="120" cy="40" r="1.5"/><circle cx="220" cy="80" r="2.2"/><circle cx="330" cy="50" r="1.6"/><circle cx="300" cy="140" r="1.4"/><circle cx="80" cy="150" r="1.8"/><circle cx="180" cy="130" r="1.2"/></g><path class="sl-comet" d="M60 100l80 30" stroke="#fde68a" stroke-width="3" stroke-linecap="round"/><path d="M0 320 140 230l90 60 170-80v190H0z" fill="#1e1b4b"/><rect x="170" y="280" width="60" height="44" fill="#312e81"/><path d="M160 282l40-30 40 30z" fill="#4338ca"/><rect x="192" y="298" width="16" height="16" fill="#fbbf24"/></svg>"##
        }
    }
}

/// Une publication du Fil : un carrousel de photos à faire glisser, toucher deux
/// fois pour aimer, enregistrer, et des commentaires.
pub fn fil(_props: &str) -> Node {
    let n = SLIDES.len();
    let index = use_state(0usize);
    let liked = use_state(false);
    let saved = use_state(false);
    let burst = use_state(0u32);
    let start = use_state((0.0f64, 0.0f64));
    let comments = use_state(vec![
        ("lea".to_owned(), "Magnifique 😍".to_owned()),
        ("ines.danse".to_owned(), "On y va cet été ?".to_owned()),
    ]);
    let draft = use_state(String::new());
    let go = move |step: i32| {
        let at = (index.get() as i32 + step).clamp(0, n as i32 - 1);
        index.set(at as usize);
    };
    let like_once = move || {
        if !liked.get() {
            liked.set(true);
        }
        burst.update(|b| *b += 1);
    };

    article()
        .class("fil")
        .child(
            div()
                .class("fil__head")
                .child(
                    span()
                        .class("avatar avatar--sm")
                        .attr("aria-hidden", "true")
                        .text("S"),
                )
                .child(
                    div().child(strong().text("sam.photo")).child(
                        span()
                            .class("muted small")
                            .text("Refuge des Lacs, Pyrénées"),
                    ),
                ),
        )
        .child(
            div()
                .class("fil__media")
                .attr("role", "group")
                .attr("aria-roledescription", "carrousel")
                .attr("aria-label", "Photos de la publication")
                .on("pointerdown", move |e| start.set(pointer(&e)))
                .on("pointerup", move |e| {
                    if let Some(step) = swipe(start.get(), pointer(&e), false) {
                        go(step);
                    }
                })
                .on("dblclick", move |_| like_once())
                .child(
                    div()
                        .class("fil__track")
                        .attr_dyn("style", move || format!("--at:{}", index.get()))
                        .children(SLIDES.iter().enumerate().map(|(i, (scene, alt))| {
                            div()
                                .class("fil__slide")
                                .attr("role", "img")
                                .attr("aria-label", format!("Photo {} sur {n} : {alt}", i + 1))
                                .html(slide_scene(scene))
                        })),
                )
                .child(
                    span()
                        .class("fil__count")
                        .text_dyn(move || format!("{}/{n}", index.get() + 1)),
                )
                .child(
                    span()
                        .class("clip__burst")
                        .class_if("go-a", move || burst.get() % 2 == 1)
                        .class_if("go-b", move || {
                            burst.get() > 0 && burst.get().is_multiple_of(2)
                        })
                        .attr("aria-hidden", "true")
                        .html(svg_icon(HEART)),
                )
                .child(
                    button()
                        .class("fil__arrow fil__arrow--prev")
                        .attr("type", "button")
                        .attr("aria-label", "Photo précédente")
                        .bool_attr("hidden", move || index.get() == 0)
                        .on_click(move |_| go(-1))
                        .html(svg_icon(LEFT)),
                )
                .child(
                    button()
                        .class("fil__arrow fil__arrow--next")
                        .attr("type", "button")
                        .attr("aria-label", "Photo suivante")
                        .bool_attr("hidden", move || index.get() + 1 >= n)
                        .on_click(move |_| go(1))
                        .html(svg_icon(RIGHT)),
                ),
        )
        .child(
            div()
                .class("fil__bar")
                .child(
                    button()
                        .class("fil__btn fil__like")
                        .class_if("is-on", move || liked.get())
                        .attr("type", "button")
                        .attr("aria-label", "J'aime")
                        .attr_dyn("aria-pressed", move || liked.get().to_string())
                        .on_click(move |_| {
                            liked.update(|l| *l = !*l);
                            if liked.get() {
                                burst.update(|b| *b += 1);
                            }
                        })
                        .html(svg_icon(HEART)),
                )
                .child(
                    span()
                        .class("fil__btn")
                        .attr("aria-hidden", "true")
                        .html(svg_icon(COMMENT)),
                )
                .child(
                    span()
                        .class("fil__btn")
                        .attr("aria-hidden", "true")
                        .html(svg_icon(SHARE)),
                )
                .child(
                    div()
                        .class("fil__dots")
                        .attr("aria-hidden", "true")
                        .children(
                            (0..n).map(|i| span().class_if("is-on", move || index.get() == i)),
                        ),
                )
                .child(
                    button()
                        .class("fil__btn fil__save")
                        .class_if("is-on", move || saved.get())
                        .attr("type", "button")
                        .attr_dyn("aria-label", move || {
                            if saved.get() {
                                "Retirer des favoris"
                            } else {
                                "Enregistrer"
                            }
                            .to_owned()
                        })
                        .attr_dyn("aria-pressed", move || saved.get().to_string())
                        .on_click(move |_| saved.update(|s| *s = !*s))
                        .html(svg_icon(SAVE)),
                ),
        )
        .child(
            div()
                .class("fil__text")
                .child(strong().text_dyn(move || {
                    format!("{} J'aime", compact(2_841 + u32::from(liked.get())))
                }))
                .child(p().child(strong().text("sam.photo ")).child(
                    span().text("Trois jours là-haut, sans réseau, et un ciel comme ça 🏔️ #rando"),
                ))
                .child(
                    ul().class("fil__comments")
                        .attr("aria-live", "polite")
                        .children_dyn(move || {
                            comments
                                .get()
                                .into_iter()
                                .map(|(who, text)| {
                                    li().child(strong().text(format!("{who} ")))
                                        .child(span().text(text))
                                        .into()
                                })
                                .collect()
                        }),
                )
                .child(
                    form()
                        .class("fil__form")
                        .on_submit(move |_| {
                            let text = draft.with(|d| d.trim().to_owned());
                            if !text.is_empty() {
                                comments.update(|c| {
                                    c.push(("vous".to_owned(), text));
                                    let extra = c.len().saturating_sub(4);
                                    c.drain(..extra);
                                });
                                draft.set(String::new());
                            }
                        })
                        .child(
                            input()
                                .attr("type", "text")
                                .attr("name", "comment")
                                .attr("placeholder", "Ajouter un commentaire…")
                                .attr("aria-label", "Commentaire")
                                .attr("autocomplete", "off")
                                .attr("maxlength", "150")
                                .bind_value(draft),
                        )
                        .child(
                            button()
                                .class("fil__publish")
                                .attr("type", "submit")
                                .text("Publier"),
                        ),
                ),
        )
        .into()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn swipes() {
        assert_eq!(swipe((0.0, 300.0), (5.0, 100.0), true), Some(1));
        assert_eq!(swipe((0.0, 100.0), (5.0, 300.0), true), Some(-1));
        assert_eq!(swipe((0.0, 100.0), (10.0, 110.0), true), None, "a tap");
        assert_eq!(swipe((300.0, 0.0), (100.0, 10.0), false), Some(1));
        assert_eq!(
            swipe((300.0, 0.0), (100.0, 10.0), true),
            None,
            "not vertical"
        );
    }

    #[test]
    fn counts() {
        assert_eq!(compact(318), "318");
        assert_eq!(compact(12_400), "12,4 k");
        assert_eq!(compact(30_000), "30 k");
        assert_eq!(compact(2_841), "2,8 k");
        assert_eq!(compact(1_250_000), "1,2 M");
    }
}

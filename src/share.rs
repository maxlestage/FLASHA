//! Partager FLASHA, et l'installer comme une application (PWA).
//!
//! - Partager : la feuille de partage du téléphone (Messages, WhatsApp, Mail, AirDrop…)
//!   quand le navigateur l'a, sinon le lien est copié.
//! - Installer : sur Android et dans Chrome, le bouton « Installer FLASHA » ouvre la
//!   proposition d'installation du navigateur. Sur iPhone, Safari n'a pas ce bouton :
//!   la page explique « Partager → Sur l'écran d'accueil ».

use paquets::prelude::*;

/// Le texte qui accompagne le lien partagé.
pub const SHARE_TEXT: &str = "FLASHA, l'appli photo où chaque instant se révèle. Chiffrée sur ton téléphone, sans base de données.";

const SHARE_ICON: &str = r#"<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M12 3v12"/><path d="m7 8 5-5 5 5"/><path d="M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>"#;

/// Les boutons de partage ; `props` est l'adresse du site.
pub fn share(props: &str) -> Node {
    let status = use_state(String::new());
    let (to_share, to_copy) = (props.to_owned(), props.to_owned());
    div()
        .class("share")
        .child(
            button()
                .class("btn btn--primary")
                .attr("type", "button")
                .on_click(move |_| open_share_sheet(&to_share, status))
                .child(span().class("btn__icon").html(SHARE_ICON))
                .child(span().text("Partager FLASHA…")),
        )
        .child(
            button()
                .class("btn btn--ghost")
                .attr("type", "button")
                .on_click(move |_| copy_link(&to_copy, status))
                .text("Copier le lien"),
        )
        .child(
            p().class("share__status")
                .attr("aria-live", "polite")
                .text_dyn(move || status.get()),
        )
        .into()
}

/// Le bouton « Installer FLASHA », montré quand le navigateur le propose.
pub fn install(_props: &str) -> Node {
    let available = use_state(false);
    let installed = use_state(false);
    div()
        .class("install")
        .on_mount(move |_dom| listen_for_install(available, installed))
        .child(
            button()
                .class("btn btn--primary")
                .attr("type", "button")
                .bool_attr("hidden", move || !available.get())
                .on_click(move |_| prompt_install(available))
                .text("Installer FLASHA"),
        )
        .child(
            p().class("install__done")
                .bool_attr("hidden", move || !installed.get())
                .text("FLASHA est installée ✦ Retrouvez-la sur votre écran d'accueil."),
        )
        .into()
}

#[cfg(target_arch = "wasm32")]
fn open_share_sheet(url: &str, status: State<String>) {
    client::share(url, status);
}

#[cfg(target_arch = "wasm32")]
fn copy_link(url: &str, status: State<String>) {
    client::copy(url, status);
}

#[cfg(target_arch = "wasm32")]
fn listen_for_install(available: State<bool>, installed: State<bool>) {
    client::listen(available, installed);
}

#[cfg(target_arch = "wasm32")]
fn prompt_install(available: State<bool>) {
    client::prompt(available);
}

#[cfg(not(target_arch = "wasm32"))]
fn open_share_sheet(_url: &str, _status: State<String>) {}

#[cfg(not(target_arch = "wasm32"))]
fn copy_link(_url: &str, _status: State<String>) {}

#[cfg(not(target_arch = "wasm32"))]
fn listen_for_install(_available: State<bool>, _installed: State<bool>) {}

#[cfg(not(target_arch = "wasm32"))]
fn prompt_install(_available: State<bool>) {}

#[cfg(target_arch = "wasm32")]
mod client {
    use std::cell::RefCell;

    use paquets::prelude::State;
    use wasm_bindgen::prelude::*;
    use wasm_bindgen::{JsCast, JsValue};
    use wasm_bindgen_futures::{JsFuture, spawn_local};

    thread_local! {
        /// La proposition d'installation, gardée jusqu'au toucher du bouton.
        static PROMPT: RefCell<Option<web_sys::Event>> = const { RefCell::new(None) };
    }

    pub fn share(url: &str, status: State<String>) {
        let Some(window) = web_sys::window() else {
            return;
        };
        let navigator = window.navigator();
        let can_share =
            js_sys::Reflect::has(&navigator, &JsValue::from_str("share")).unwrap_or(false);
        if !can_share {
            copy(url, status);
            return;
        }
        let data = web_sys::ShareData::new();
        data.set_title("FLASHA");
        data.set_text(super::SHARE_TEXT);
        data.set_url(url);
        let promise = navigator.share_with_data(&data);
        spawn_local(async move {
            if JsFuture::from(promise).await.is_ok() {
                status.set("Merci d'avoir partagé FLASHA ✦".to_owned());
            }
        });
    }

    pub fn copy(url: &str, status: State<String>) {
        let Some(window) = web_sys::window() else {
            return;
        };
        let promise = window.navigator().clipboard().write_text(url);
        let url = url.to_owned();
        spawn_local(async move {
            let message = if JsFuture::from(promise).await.is_ok() {
                "Lien copié : collez-le dans un message.".to_owned()
            } else {
                format!("Copiez ce lien : {url}")
            };
            status.set(message);
        });
    }

    pub fn listen(available: State<bool>, installed: State<bool>) {
        let Some(window) = web_sys::window() else {
            return;
        };
        let on_prompt = Closure::<dyn FnMut(web_sys::Event)>::new(move |event: web_sys::Event| {
            // Le navigateur attend notre bouton au lieu de sa bannière.
            event.prevent_default();
            PROMPT.with(|prompt| *prompt.borrow_mut() = Some(event));
            available.set(true);
        });
        let _ = window.add_event_listener_with_callback(
            "beforeinstallprompt",
            on_prompt.as_ref().unchecked_ref(),
        );
        on_prompt.forget();
        let on_installed =
            Closure::<dyn FnMut(web_sys::Event)>::new(move |_event: web_sys::Event| {
                available.set(false);
                installed.set(true);
            });
        let _ = window.add_event_listener_with_callback(
            "appinstalled",
            on_installed.as_ref().unchecked_ref(),
        );
        on_installed.forget();
    }

    pub fn prompt(available: State<bool>) {
        PROMPT.with(|prompt| {
            if let Some(event) = prompt.borrow_mut().take()
                && let Ok(function) = js_sys::Reflect::get(&event, &JsValue::from_str("prompt"))
                && let Some(function) = function.dyn_ref::<js_sys::Function>()
            {
                let _ = function.call0(&event);
            }
        });
        available.set(false);
    }
}

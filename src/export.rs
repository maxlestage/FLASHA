//! `flasha export <dossier>` : tout le site en fichiers statiques, pour GitHub Pages.
//!
//! Chaque fichier vient du serveur lui-même, par le client de test en mémoire de
//! Paquets (`app.test()`) : le site exporté et le site servi sont identiques. Seules
//! les adresses absolues reçoivent le chemin de base (`BASE_PATH`, par exemple
//! `/FLASHA` pour `https://<compte>.github.io/FLASHA/`).

use std::io;
use std::path::{Path, PathBuf};

use paquets::prelude::*;

/// Les adresses absolues que la page écrit, à placer derrière le chemin de base.
const ABSOLUTE: [&str; 6] = [
    "\"/flasha.css",
    "\"/favicon.svg\"",
    "\"/pkg/",
    "\"/paquets/",
    "\"/manifest.webmanifest\"",
    "\"/sw.js\"",
];

/// `"/FLASHA"` ou `""` : sans barre finale, avec une barre initiale.
pub fn normalize_base(base: &str) -> String {
    let trimmed = base.trim().trim_matches('/');
    if trimmed.is_empty() {
        String::new()
    } else {
        format!("/{trimmed}")
    }
}

/// Le HTML, ses adresses absolues derrière `base`.
pub fn with_base(html: &str, base: &str) -> String {
    if base.is_empty() {
        return html.to_owned();
    }
    ABSOLUTE.iter().fold(html.to_owned(), |html, url| {
        html.replace(url, &format!("\"{base}{}", &url[1..]))
    })
}

/// Un fichier JSON ou JavaScript (manifeste, service worker) : toutes ses adresses
/// absolues (`"/…"`) derrière `base`.
pub fn with_base_everywhere(text: &str, base: &str) -> String {
    if base.is_empty() {
        return text.to_owned();
    }
    text.replace("\"/", &format!("\"{base}/"))
}

/// Écrit le site dans `out` ; renvoie le nombre de fichiers écrits.
pub async fn export(mut app: App, out: &Path, base: &str) -> io::Result<usize> {
    let base = normalize_base(base);
    if !Path::new("pkg").is_dir() {
        eprintln!("attention : pkg/ manque, la scène 2D et les îlots ne seront pas interactifs");
    }
    // Des fichiers statiques n'ont pas de serveur à protéger, et l'export demande
    // tout d'un coup (la limitation de débit l'arrêterait).
    app.security(None);
    let client = app.test().await;
    let mut written = 0;
    let mut write = |path: &str, bytes: &[u8]| -> io::Result<()> {
        let file = out.join(path.trim_start_matches('/'));
        if let Some(parent) = file.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(file, bytes)?;
        written += 1;
        Ok(())
    };

    let get = |path: &'static str| {
        let client = &client;
        async move {
            let res = client.get(path).await;
            if res.status() != 200 {
                return Err(io::Error::other(format!("GET {path} : {}", res.status())));
            }
            Ok(res)
        }
    };

    let page = with_base(&get("/").await?.text(), &base);
    write("index.html", page.as_bytes())?;
    // Une seule page : toute adresse inconnue y mène.
    write("404.html", page.as_bytes())?;

    for file in ["/manifest.webmanifest", "/sw.js"] {
        let body = get(file).await?.text();
        write(file, with_base_everywhere(&body, &base).as_bytes())?;
    }
    for icon in [
        "/paquets/icon-192.png",
        "/paquets/icon-512.png",
        "/paquets/icon-maskable-512.png",
    ] {
        write(icon, get(icon).await?.bytes())?;
    }
    for folder in ["public", "pkg"] {
        let root = Path::new(folder);
        let prefix = if folder == "pkg" { "pkg/" } else { "" };
        for file in files(root) {
            let relative = file.strip_prefix(root).map_err(io::Error::other)?;
            let url = format!("{prefix}{}", relative.to_string_lossy().replace('\\', "/"));
            // Les fichiers de wasm-bindgen inutiles pour charger le bundle.
            if url.ends_with(".gitignore") || url.ends_with("package.json") {
                continue;
            }
            write(&url, &std::fs::read(&file)?)?;
        }
    }
    // Les fichiers sont servis tels quels : pas de Jekyll sur GitHub Pages.
    write(".nojekyll", b"")?;
    Ok(written)
}

/// Chaque fichier sous `dir`, récursivement.
fn files(dir: &Path) -> Vec<PathBuf> {
    let mut found = Vec::new();
    let Ok(entries) = std::fs::read_dir(dir) else {
        return found;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            found.extend(files(&path));
        } else {
            found.push(path);
        }
    }
    found.sort();
    found
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bases() {
        assert_eq!(normalize_base(""), "");
        assert_eq!(normalize_base("/"), "");
        assert_eq!(normalize_base("FLASHA"), "/FLASHA");
        assert_eq!(normalize_base("/FLASHA/"), "/FLASHA");
    }

    #[test]
    fn only_urls_get_the_base() {
        let html = r##"<link href="/flasha.css?v=1"/><script src="/pkg/a.js"></script><a href="#offres">x</a><meta content="a"/>"##;
        let out = with_base(html, "/FLASHA");
        assert!(out.contains(r#""/FLASHA/flasha.css?v=1""#));
        assert!(out.contains(r#""/FLASHA/pkg/a.js""#));
        assert!(out.contains(r##""#offres""##));
        assert!(
            out.contains(r#"content="a"/>"#),
            "self-closing tags are untouched"
        );
        assert_eq!(with_base(html, ""), html);
    }
}

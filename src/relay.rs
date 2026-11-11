//! Le relais de FLASHA : un facteur aveugle, sans base de données.
//!
//! Les téléphones gardent tout, chiffré, chez eux. Pour s'échanger des abonnements, des
//! publications, des Flashs et des messages, ils passent par ce relais, qui :
//!
//! - ne voit que des paquets chiffrés de bout en bout (il n'a aucune clé) ;
//! - n'écrit rien sur disque : un paquet dont le destinataire est hors ligne attend en
//!   mémoire vive (72 heures au plus, dans des limites de taille), puis disparaît. Le
//!   téléphone qui l'a envoyé le garde jusqu'à l'accusé de réception du destinataire,
//!   et le renvoie si besoin (après un redémarrage du relais, par exemple) ;
//! - identifie chaque téléphone par sa clé publique Ed25519 : à la connexion, le
//!   téléphone signe un défi aléatoire. Pas de compte, pas de mot de passe, pas de base.
//!
//! Le protocole, sur `GET /relay` (WebSocket) :
//!
//! 1. relais → texte `{"t":"challenge","nonce":"<base64>"}` ;
//! 2. téléphone → texte `{"t":"hello","id":"<base64 de la clé publique>","sig":"<base64>"}`,
//!    la signature portant sur `flasha-relay-v1` suivi du défi ;
//! 3. relais → texte `{"t":"ready","pending":<n>}`, puis les paquets en attente ;
//! 4. un paquet est un message binaire : 1 octet de type, 32 octets d'adresse, le contenu
//!    chiffré. Type 1 (téléphone → relais) : l'adresse est celle du destinataire. Type 2
//!    (relais → téléphone) : l'adresse est celle de l'expéditeur, garantie par le relais.

use std::collections::{HashMap, VecDeque};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use ed25519_dalek::{Signature, VerifyingKey};
use paquets::prelude::*;
use paquets::vitesse::IntoResponse;
use paquets::vitesse::ws::{Message, Upgrade, WebSocket};
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc;

/// Une adresse : la clé publique Ed25519 d'un téléphone.
pub type Address = [u8; 32];

/// Ce que signe un téléphone pour prouver qu'il détient sa clé.
const CONTEXT: &[u8] = b"flasha-relay-v1";
/// Paquet d'un téléphone vers le relais.
pub const SEND: u8 = 1;
/// Paquet du relais vers un téléphone.
pub const DELIVER: u8 = 2;
/// La taille maximale d'un paquet : une FLASHA Vidéo de 60 secondes, chiffrée.
pub const MAX_PACKET: usize = 24 * 1024 * 1024;

/// Les limites de la mémoire d'attente.
#[derive(Clone, Copy, Debug)]
pub struct Limits {
    /// Combien de temps un paquet attend son destinataire.
    pub ttl: Duration,
    /// Octets en attente pour un même destinataire.
    pub per_recipient: usize,
    /// Octets en attente pour tout le relais.
    pub total: usize,
}

impl Default for Limits {
    fn default() -> Self {
        Limits {
            ttl: Duration::from_secs(72 * 3600),
            per_recipient: 128 * 1024 * 1024,
            total: 1024 * 1024 * 1024,
        }
    }
}

struct Parcel {
    from: Address,
    payload: Vec<u8>,
    at: Instant,
}

#[derive(Default)]
struct State {
    online: HashMap<Address, (u64, mpsc::UnboundedSender<Vec<u8>>)>,
    waiting: HashMap<Address, VecDeque<Parcel>>,
    waiting_bytes: usize,
    next_connection: u64,
}

/// Ce que devient un paquet confié au relais.
#[derive(Debug, PartialEq, Eq)]
pub enum Outcome {
    /// Remis tout de suite : le destinataire est en ligne.
    Delivered,
    /// Mis en attente, en mémoire vive.
    Queued,
    /// Refusé : la mémoire d'attente est pleine ; l'expéditeur réessaiera.
    Full,
}

/// Le relais : uniquement de la mémoire vive.
#[derive(Clone, Default)]
pub struct Relay {
    state: Arc<Mutex<State>>,
    limits: Limits,
}

impl Relay {
    pub fn new(limits: Limits) -> Relay {
        Relay {
            state: Arc::default(),
            limits,
        }
    }

    /// Le paquet tel qu'il est remis : type, adresse de l'expéditeur, contenu.
    fn frame(from: &Address, payload: &[u8]) -> Vec<u8> {
        let mut frame = Vec::with_capacity(33 + payload.len());
        frame.push(DELIVER);
        frame.extend_from_slice(from);
        frame.extend_from_slice(payload);
        frame
    }

    /// Un téléphone se connecte : il reçoit ce qui l'attendait. Renvoie le numéro de la
    /// connexion et le nombre de paquets remis.
    fn connect(&self, address: Address, outbox: mpsc::UnboundedSender<Vec<u8>>) -> (u64, usize) {
        let mut state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        state.next_connection += 1;
        let connection = state.next_connection;
        state.online.insert(address, (connection, outbox.clone()));
        let mut delivered = 0;
        if let Some(parcels) = state.waiting.remove(&address) {
            for parcel in parcels {
                state.waiting_bytes -= parcel.payload.len();
                if parcel.at.elapsed() < self.limits.ttl
                    && outbox
                        .send(Relay::frame(&parcel.from, &parcel.payload))
                        .is_ok()
                {
                    delivered += 1;
                }
            }
        }
        (connection, delivered)
    }

    fn disconnect(&self, address: &Address, connection: u64) {
        let mut state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        if state
            .online
            .get(address)
            .is_some_and(|(c, _)| *c == connection)
        {
            state.online.remove(address);
        }
    }

    /// Confie un paquet au relais.
    pub fn post(&self, from: Address, to: Address, payload: Vec<u8>) -> Outcome {
        let mut state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        if let Some((_, outbox)) = state.online.get(&to)
            && outbox.send(Relay::frame(&from, &payload)).is_ok()
        {
            return Outcome::Delivered;
        }
        self.expire(&mut state);
        let queued: usize = state
            .waiting
            .get(&to)
            .map_or(0, |q| q.iter().map(|p| p.payload.len()).sum());
        if queued + payload.len() > self.limits.per_recipient
            || state.waiting_bytes + payload.len() > self.limits.total
        {
            return Outcome::Full;
        }
        state.waiting_bytes += payload.len();
        state.waiting.entry(to).or_default().push_back(Parcel {
            from,
            payload,
            at: Instant::now(),
        });
        Outcome::Queued
    }

    /// Oublie les paquets trop anciens.
    fn expire(&self, state: &mut State) {
        let ttl = self.limits.ttl;
        let mut freed = 0;
        state.waiting.retain(|_, parcels| {
            while parcels.front().is_some_and(|p| p.at.elapsed() >= ttl) {
                if let Some(p) = parcels.pop_front() {
                    freed += p.payload.len();
                }
            }
            !parcels.is_empty()
        });
        state.waiting_bytes -= freed;
    }

    /// Octets en attente.
    #[cfg(test)]
    pub fn waiting_bytes(&self) -> usize {
        self.state.lock().map_or(0, |s| s.waiting_bytes)
    }
}

/// Un défi aléatoire de 32 octets.
fn challenge() -> [u8; 32] {
    let mut nonce = [0u8; 32];
    // Sans source d'aléa, la connexion échoue plus loin (signature invalide).
    let _ = getrandom::fill(&mut nonce);
    nonce
}

/// Vérifie qu'un téléphone détient la clé de son adresse.
pub fn verify(address: &Address, nonce: &[u8], signature: &[u8]) -> bool {
    let (Ok(key), Ok(signature)) = (
        VerifyingKey::from_bytes(address),
        <[u8; 64]>::try_from(signature),
    ) else {
        return false;
    };
    let mut message = CONTEXT.to_vec();
    message.extend_from_slice(nonce);
    key.verify_strict(&message, &Signature::from_bytes(&signature))
        .is_ok()
}

#[derive(Serialize)]
#[serde(tag = "t", rename_all = "lowercase")]
enum ServerText {
    Challenge { nonce: String },
    Ready { pending: usize },
    Full,
    Error { reason: &'static str },
}

#[derive(Deserialize)]
struct Hello {
    t: String,
    id: String,
    sig: String,
}

fn text(message: &ServerText) -> Message {
    Message::Text(serde_json::to_string(message).unwrap_or_default())
}

/// `GET /relay` : la connexion WebSocket d'un téléphone.
pub async fn handler(relay: Relay, req: Request) -> Response {
    match Upgrade::new(&req) {
        Ok(upgrade) => upgrade
            .max_message_size(MAX_PACKET + 33)
            .on_upgrade(req, move |_req, socket| session(relay, socket)),
        Err(error) => error.into_response(),
    }
}

async fn session(relay: Relay, mut socket: WebSocket) {
    // 1. Le défi, puis la preuve d'identité, en 30 secondes au plus.
    let nonce = challenge();
    let challenge = ServerText::Challenge {
        nonce: STANDARD.encode(nonce),
    };
    if socket.send(text(&challenge)).await.is_err() {
        return;
    }
    let hello = tokio::time::timeout(Duration::from_secs(30), socket.recv()).await;
    let Ok(Some(Ok(Message::Text(hello)))) = hello else {
        return;
    };
    let address = serde_json::from_str::<Hello>(&hello)
        .ok()
        .and_then(|hello| {
            let id: Address = STANDARD.decode(&hello.id).ok()?.try_into().ok()?;
            let sig = STANDARD.decode(&hello.sig).ok()?;
            (hello.t == "hello" && verify(&id, &nonce, &sig)).then_some(id)
        });
    let Some(address) = address else {
        let _ = socket
            .send(text(&ServerText::Error { reason: "identity" }))
            .await;
        let _ = socket.close(1008, "identity").await;
        return;
    };

    // 2. En ligne : ce qui attendait est remis, puis tout ce qui arrive.
    let (outbox, mut inbox) = mpsc::unbounded_channel::<Vec<u8>>();
    let (sender, mut receiver) = socket.split();
    let (connection, pending) = relay.connect(address, outbox.clone());
    let writer = tokio::spawn(async move {
        let mut sender = sender;
        if sender
            .send(text(&ServerText::Ready { pending }))
            .await
            .is_err()
        {
            return;
        }
        while let Some(frame) = inbox.recv().await {
            let message = match String::from_utf8(frame) {
                // Les messages de contrôle du relais sont du texte JSON.
                Ok(json) if json.starts_with('{') => Message::Text(json),
                Ok(json) => Message::Binary(json.into_bytes().into()),
                Err(e) => Message::Binary(e.into_bytes().into()),
            };
            if sender.send(message).await.is_err() {
                break;
            }
        }
    });

    // 3. Les paquets du téléphone.
    while let Some(Ok(message)) = receiver.recv().await {
        let Message::Binary(data) = message else {
            if message.is_close() {
                break;
            }
            continue;
        };
        if data.len() < 33 || data[0] != SEND {
            continue;
        }
        let Ok(to) = <Address>::try_from(&data[1..33]) else {
            continue;
        };
        if relay.post(address, to, data[33..].to_vec()) == Outcome::Full {
            let full = serde_json::to_string(&ServerText::Full).unwrap_or_default();
            let _ = outbox.send(full.into_bytes());
        }
    }

    relay.disconnect(&address, connection);
    writer.abort();
}

#[cfg(test)]
mod tests {
    use super::*;

    fn address(n: u8) -> Address {
        [n; 32]
    }

    #[test]
    fn a_parcel_waits_then_is_delivered_once() {
        let relay = Relay::default();
        assert_eq!(
            relay.post(address(1), address(2), b"bonjour".to_vec()),
            Outcome::Queued
        );
        assert_eq!(relay.waiting_bytes(), 7);

        let (outbox, mut inbox) = mpsc::unbounded_channel();
        let (_, pending) = relay.connect(address(2), outbox);
        assert_eq!(pending, 1);
        assert_eq!(
            relay.waiting_bytes(),
            0,
            "nothing stays in memory once delivered"
        );
        let frame = inbox.try_recv().unwrap();
        assert_eq!(frame[0], DELIVER);
        assert_eq!(
            &frame[1..33],
            &address(1),
            "the relay vouches for the sender"
        );
        assert_eq!(&frame[33..], b"bonjour");
        assert!(inbox.try_recv().is_err());
    }

    #[test]
    fn online_recipients_get_parcels_at_once() {
        let relay = Relay::default();
        let (outbox, mut inbox) = mpsc::unbounded_channel();
        relay.connect(address(2), outbox);
        assert_eq!(
            relay.post(address(1), address(2), vec![9; 10]),
            Outcome::Delivered
        );
        assert_eq!(relay.waiting_bytes(), 0);
        assert_eq!(inbox.try_recv().unwrap().len(), 43);
    }

    #[test]
    fn memory_is_bounded() {
        let relay = Relay::new(Limits {
            ttl: Duration::from_secs(60),
            per_recipient: 10,
            total: 15,
        });
        assert_eq!(
            relay.post(address(1), address(2), vec![0; 8]),
            Outcome::Queued
        );
        assert_eq!(
            relay.post(address(1), address(2), vec![0; 8]),
            Outcome::Full,
            "per recipient"
        );
        assert_eq!(
            relay.post(address(1), address(3), vec![0; 8]),
            Outcome::Full,
            "in total"
        );
        assert_eq!(
            relay.post(address(1), address(3), vec![0; 7]),
            Outcome::Queued
        );
    }

    #[test]
    fn old_parcels_are_forgotten() {
        let relay = Relay::new(Limits {
            ttl: Duration::ZERO,
            ..Limits::default()
        });
        relay.post(address(1), address(2), vec![0; 8]);
        relay.post(address(1), address(3), vec![0; 8]);
        assert_eq!(relay.waiting_bytes(), 8, "the first one expired");
    }

    #[test]
    fn identities_are_checked() {
        use ed25519_dalek::{Signer, SigningKey};
        let key = SigningKey::from_bytes(&[7; 32]);
        let id = key.verifying_key().to_bytes();
        let nonce = [3u8; 32];
        let mut message = CONTEXT.to_vec();
        message.extend_from_slice(&nonce);
        let signature = key.sign(&message).to_bytes();
        assert!(verify(&id, &nonce, &signature));
        assert!(!verify(&id, &[4u8; 32], &signature), "another challenge");
        assert!(!verify(&[9; 32], &nonce, &signature), "another key");
        assert!(
            !verify(&id, &nonce, &signature[..10]),
            "a truncated signature"
        );
    }
}

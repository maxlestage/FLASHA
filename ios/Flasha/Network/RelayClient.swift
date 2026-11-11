import Foundation
import Observation

/// La connexion au relais, en WebSocket. Le relais ne voit que des paquets chiffrés.
@Observable
final class RelayClient {
    enum Status {
        case offline
        case connecting
        case online
    }

    private(set) var status: Status = .offline
    private var task: URLSessionWebSocketTask?

    /// Un paquet arrive : l'adresse de l'expéditeur (garantie par le relais) et le contenu.
    var onParcel: ((Data, Data) -> Void)?
    /// La connexion est établie et authentifiée.
    var onReady: (() -> Void)?
    /// La connexion est perdue.
    var onClosed: (() -> Void)?

    /// Se connecte à `base` (par exemple `https://flasha.example.com`), sur `/relay`.
    func connect(to base: URL, identity: Identity) {
        guard status == .offline,
              var components = URLComponents(url: base.appending(path: "relay"), resolvingAgainstBaseURL: false)
        else { return }
        components.scheme = base.scheme == "http" ? "ws" : "wss"
        guard let url = components.url else { return }
        let task = URLSession.shared.webSocketTask(with: url)
        task.maximumMessageSize = 26 * 1024 * 1024
        self.task = task
        status = .connecting
        task.resume()
        Task { await run(task, identity: identity) }
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        status = .offline
    }

    /// Envoie un paquet chiffré à une adresse ; `false` si le relais est injoignable.
    func send(_ payload: Data, to address: Data) async -> Bool {
        guard status == .online, let task else { return false }
        var frame = Data([1])
        frame.append(address)
        frame.append(payload)
        do {
            try await task.send(.data(frame))
            return true
        } catch {
            return false
        }
    }

    private func run(_ task: URLSessionWebSocketTask, identity: Identity) async {
        do {
            while true {
                switch try await task.receive() {
                case let .string(text):
                    try await control(text, task: task, identity: identity)
                case let .data(data):
                    guard data.count > 33, data.first == 2 else { continue }
                    onParcel?(Data(data.dropFirst().prefix(32)), Data(data.dropFirst(33)))
                @unknown default:
                    continue
                }
            }
        } catch {
            // Connexion perdue ou refusée.
        }
        if self.task === task {
            self.task = nil
            status = .offline
            onClosed?()
        }
    }

    private struct Control: Decodable {
        var t: String
        var nonce: String?
    }

    private struct Hello: Encodable {
        var t = "hello"
        var id: String
        var sig: String
    }

    private func control(_ text: String, task: URLSessionWebSocketTask, identity: Identity) async throws {
        let message = try JSONDecoder().decode(Control.self, from: Data(text.utf8))
        switch message.t {
        case "challenge":
            guard let nonce = message.nonce.flatMap({ Data(base64Encoded: $0) }) else { return }
            let hello = Hello(
                id: identity.id.signing.base64EncodedString(),
                sig: try identity.signChallenge(nonce).base64EncodedString()
            )
            let json = String(decoding: try JSONEncoder().encode(hello), as: UTF8.self)
            try await task.send(.string(json))
        case "ready":
            status = .online
            onReady?()
        default:
            break
        }
    }
}

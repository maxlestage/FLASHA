import Foundation
import SwiftUI

/// Les échanges entre téléphones, par le relais sans base :
///
/// - s'abonner : on ajoute quelqu'un par son identifiant FLASHA (QR code ou lien), une
///   demande lui part ; s'il l'accepte, ses publications nous arrivent ;
/// - chaque publication, Flash ou message est chiffré de bout en bout pour chacun de ses
///   destinataires, puis rangé dans la boîte d'envoi jusqu'à l'accusé de réception ;
/// - un paquet reçu n'est accepté que d'un contact connu (sauf une demande d'abonnement).
extension AppStore {
    // MARK: Connexion

    var myID: FlashaID { Identity.shared.id }

    var myProfile: Profile { Profile(name: me.name, username: me.username) }

    func startNetwork() {
        relay.onReady = { [weak self] in
            self?.flushOutbox()
        }
        relay.onParcel = { [weak self] sender, payload in
            self?.receive(payload, from: sender)
        }
        relay.onClosed = { [weak self] in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(15))
                self?.connectRelay()
            }
        }
        connectRelay()
    }

    func connectRelay() {
        let text = relayURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard relay.status == .offline,
              let url = URL(string: text),
              url.scheme == "https" || url.scheme == "http"
        else { return }
        relay.connect(to: url, identity: .shared)
    }

    func setRelayURL(_ text: String) {
        relayURL = text
        relay.disconnect()
        connectRelay()
    }

    // MARK: Boîte d'envoi

    private static var outboxDirectory: URL {
        Vault.shared.directory.appending(path: "Outbox", directoryHint: .isDirectory)
    }

    private static func outboxFile(_ id: UUID) -> URL {
        outboxDirectory.appending(path: "\(id.uuidString).parcel")
    }

    /// Chiffre un paquet pour son destinataire et le confie à la boîte d'envoi.
    func enqueue(_ body: Parcel.Body, to recipient: FlashaID) {
        let parcel = Parcel(body: body)
        guard let content = try? parcel.encoded(),
              let sealed = try? Sealing.seal(content, to: recipient, from: .shared)
        else { return }
        if case .receipt = body {
            // Un accusé de réception n'est pas lui-même accusé : envoyé une fois.
            Task { _ = await relay.send(sealed, to: recipient.signing) }
            return
        }
        try? FileManager.default.createDirectory(at: Self.outboxDirectory, withIntermediateDirectories: true)
        guard let stored = try? Vault.shared.seal(sealed),
              (try? stored.write(to: Self.outboxFile(parcel.id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])) != nil
        else { return }
        outbox.append(Outgoing(id: parcel.id, to: recipient, createdAt: .now, lastSent: nil))
        flushOutbox()
    }

    /// Envoie ce qui attend : jamais envoyé, ou sans accusé depuis 30 minutes. Un paquet
    /// sans accusé depuis 30 jours est abandonné.
    func flushOutbox() {
        guard relay.status == .online else { return }
        let now = Date.now
        for item in outbox where now.timeIntervalSince(item.createdAt) > 30 * 86_400 {
            drop(item.id)
        }
        for item in outbox where item.lastSent.map({ now.timeIntervalSince($0) > 1_800 }) ?? true {
            guard let stored = try? Data(contentsOf: Self.outboxFile(item.id)),
                  let sealed = try? Vault.shared.open(stored)
            else {
                drop(item.id)
                continue
            }
            let id = item.id
            let address = item.to.signing
            Task {
                if await relay.send(sealed, to: address),
                   let index = outbox.firstIndex(where: { $0.id == id }) {
                    outbox[index].lastSent = .now
                }
            }
        }
    }

    private func drop(_ id: UUID) {
        outbox.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: Self.outboxFile(id))
    }

    // MARK: Réception

    func receive(_ payload: Data, from sender: Data) {
        guard let opened = try? Sealing.open(payload, relaySender: sender, identity: .shared),
              let parcel = try? Parcel.decode(opened.1)
        else { return }
        let from = opened.0
        if case let .receipt(id) = parcel.body {
            drop(id)
            return
        }
        // Toujours accuser réception, pour que l'expéditeur arrête de renvoyer.
        enqueue(.receipt(parcel.id), to: from)
        guard !seenParcels.contains(parcel.id) else { return }
        seenParcels.append(parcel.id)
        if seenParcels.count > 1_000 {
            seenParcels.removeFirst(seenParcels.count - 1_000)
        }
        withAnimation(.spring) { handle(parcel, from: from) }
    }

    private func handle(_ parcel: Parcel, from sender: FlashaID) {
        let contact = friends.first { $0.publicID == sender }
        switch parcel.body {
        case let .followRequest(profile):
            if followerIDs.contains(sender) {
                enqueue(.followAccepted(myProfile), to: sender)
            } else if !requests.contains(where: { $0.publicID == sender }) {
                var request = Friend(name: profile.name, username: profile.username, color: Theme.violet)
                request.publicID = sender
                requests.append(request)
            }
        case let .followAccepted(profile):
            guard requestedIDs.contains(sender) || followingIDs.contains(sender) else { return }
            requestedIDs.remove(sender)
            followingIDs.insert(sender)
            upsertContact(sender, profile)
        case .unfollow:
            followerIDs.remove(sender)
        case let .post(post):
            guard followingIDs.contains(sender), let author = contact,
                  !feed.contains(where: { $0.id == post.postID })
            else { return }
            let slides = post.photos.compactMap { data -> Slide? in
                guard let id = try? MediaStore.shared.savePhoto(data) else { return nil }
                return Slide(colors: [Theme.violet, Theme.pink], symbol: "photo", mediaID: id)
            }
            var item = FeedPost(
                author: author,
                place: post.place,
                caption: post.caption,
                slides: slides,
                likes: 0,
                comments: [],
                date: post.date
            )
            item.id = post.postID
            feed.insert(item, at: 0)
        case let .flash(flash):
            guard let from = contact else { return }
            var mediaID: UUID?
            if let media = flash.media {
                if flash.isVideo {
                    mediaID = try? MediaStore.shared.saveVideo(media)
                } else {
                    mediaID = try? MediaStore.shared.savePhoto(media)
                }
            }
            var item = Flash(
                from: from,
                image: nil,
                mediaID: mediaID,
                caption: flash.caption,
                duration: flash.duration,
                allowsReplay: flash.allowsReplay,
                sentAt: parcel.sentAt
            )
            item.isVideo = flash.isVideo
            receivedFlashs.insert(item, at: 0)
        case let .chat(text):
            guard let from = contact else { return }
            let message = Message(fromMe: false, text: text, date: parcel.sentAt)
            if let index = conversations.firstIndex(where: { $0.friend.publicID == sender }) {
                conversations[index].messages.append(message)
            } else {
                conversations.append(Conversation(friend: from, messages: [message]))
            }
        case .receipt:
            break
        }
        refreshStorage()
    }

    @discardableResult
    private func upsertContact(_ id: FlashaID, _ profile: Profile) -> Friend {
        if let index = friends.firstIndex(where: { $0.publicID == id }) {
            friends[index].name = profile.name
            friends[index].username = profile.username
            return friends[index]
        }
        var friend = Friend(name: profile.name, username: profile.username, color: Theme.violet)
        friend.publicID = id
        friends.append(friend)
        conversations.append(Conversation(friend: friend, messages: []))
        return friend
    }

    // MARK: Actions

    /// Demande à suivre quelqu'un, par son identifiant FLASHA. `false` si l'identifiant
    /// n'est pas valable.
    @discardableResult
    func follow(_ text: String) -> Bool {
        guard let id = FlashaID(text), id != myID else { return false }
        requestedIDs.insert(id)
        enqueue(.followRequest(myProfile), to: id)
        return true
    }

    func accept(_ request: Friend) {
        guard let id = request.publicID else { return }
        requests.removeAll { $0.publicID == id }
        followerIDs.insert(id)
        upsertContact(id, Profile(name: request.name, username: request.username))
        enqueue(.followAccepted(myProfile), to: id)
    }

    func decline(_ request: Friend) {
        requests.removeAll { $0.publicID == request.publicID }
    }

    func unfollow(_ friend: Friend) {
        guard let id = friend.publicID else { return }
        followingIDs.remove(id)
        requestedIDs.remove(id)
        enqueue(.unfollow, to: id)
    }

    /// Publie des photos dans le Fil : gardées chez moi, envoyées à chacun de mes abonnés.
    func publish(caption: String, photos: [EncodedPhoto]) {
        let slides = photos.compactMap { photo -> Slide? in
            guard let id = try? MediaStore.shared.save(photo, pinned: true) else { return nil }
            return Slide(colors: [Theme.violet, Theme.pink], symbol: "photo", mediaID: id)
        }
        let post = FeedPost(
            author: me,
            place: nil,
            caption: caption,
            slides: slides.isEmpty ? [Slide(colors: [Theme.violet, Theme.pink], symbol: "sparkles")] : slides,
            likes: 0,
            comments: [],
            date: .now
        )
        feed.insert(post, at: 0)
        refreshStorage()
        let payload = PostPayload(postID: post.id, caption: caption, place: nil, date: post.date, photos: photos.map(\.data))
        for follower in followerIDs {
            enqueue(.post(payload), to: follower)
        }
    }
}

import Foundation

// Saved playlists (`T3` in the web bundle). The list lives in the profile as
// `user.saved_playlists` (captured `[]` with the test account, 2026-10-09);
// the browser replaces it whole with `PUT /playlists/saved {playlists}`,
// which answers `{playlists}`. Five slots, ten with PRO.

struct SavedPlaylist: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let image: String?
    /// "spotify" or "youtube"
    let source: String

    private enum CodingKeys: String, CodingKey { case id, name, image, source }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(LooseValue.self, forKey: .id).text
        name = (try? c.decode(String.self, forKey: .name)) ?? "Playlist"
        image = try? c.decode(String.self, forKey: .image)
        source = (try? c.decode(String.self, forKey: .source)) ?? "spotify"
    }

    init(id: String, name: String, image: String?, source: String) {
        self.id = id
        self.name = name
        self.image = image
        self.source = source
    }

    /// The shape the server stores - `image` explicitly null when missing.
    var body: [String: Any] {
        ["id": id, "name": name, "image": image.map { $0 as Any } ?? NSNull(), "source": source]
    }

    /// `Tf`: one of eight cover gradients, picked by a 31-hash of the id.
    var paletteIndex: Int { SavedPlaylist.paletteIndex(id) }

    static func paletteIndex(_ id: String, count: Int = 8) -> Int {
        var hash: UInt64 = 0
        for unit in id.utf16 {
            hash = (hash &* 31 &+ UInt64(unit)) & 0xFFFF_FFFF
        }
        return Int(hash % UInt64(count))
    }

    static func slots(isPro: Bool) -> Int { isPro ? 10 : 5 }
}

/// `{user: {saved_playlists}}` from `/profile`, or `{playlists}` from the PUT.
struct SavedPlaylistList: Decodable {
    let items: [SavedPlaylist]

    private enum TopKeys: String, CodingKey { case user, playlists }
    private enum UserKeys: String, CodingKey { case saved_playlists }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: TopKeys.self)
        if let direct = try? c.decode(LenientArray<SavedPlaylist>.self, forKey: .playlists) {
            items = direct.items
        } else if let u = try? c.nestedContainer(keyedBy: UserKeys.self, forKey: .user) {
            items = (try? u.decode(LenientArray<SavedPlaylist>.self, forKey: .saved_playlists))?.items ?? []
        } else {
            items = []
        }
    }
}

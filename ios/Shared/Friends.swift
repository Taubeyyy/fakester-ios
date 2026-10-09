import Foundation

// Friends. The test account has none, so `GET /friends` was captured only as
// `{"friends":[]}` (2026-10-09). The entry fields come from the web bundle
// (`E3`): id, friendship_id, username, status ("accepted" / "pending"),
// direction ("received" / "sent"), online, avatar_url, equipped_icon_id,
// is_pro - decoded extra leniently for that reason. Requests:
// `POST /friends/request {username}`, `POST /friends/respond
// {friendshipId, accept}`, `DELETE /friends/<friendship_id>`.

struct FriendEntry: Decodable, Identifiable, Equatable {
    let id: String
    /// Kept as sent - a number goes back as a number.
    let friendshipID: LooseValue
    let username: String
    let status: String
    let direction: String
    let online: Bool
    let avatarURL: String?
    let iconID: String?
    let isPro: Bool

    private enum CodingKeys: String, CodingKey {
        case id, friendship_id, username, status, direction, online, avatar_url, equipped_icon_id, is_pro
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let friendship: LooseValue? = try? c.decode(LooseValue.self, forKey: .friendship_id)
        let own: LooseValue? = try? c.decode(LooseValue.self, forKey: .id)
        guard let key = friendship ?? own else {
            throw DecodingError.keyNotFound(CodingKeys.friendship_id, .init(codingPath: d.codingPath, debugDescription: "no id"))
        }
        friendshipID = key
        id = own?.text ?? key.text
        username = (try? c.decode(String.self, forKey: .username)) ?? "?"
        status = (try? c.decode(String.self, forKey: .status)) ?? "accepted"
        direction = (try? c.decode(String.self, forKey: .direction)) ?? ""
        online = (try? c.decode(Bool.self, forKey: .online)) ?? false
        avatarURL = try? c.decode(String.self, forKey: .avatar_url)
        iconID = (try? c.decode(LooseValue.self, forKey: .equipped_icon_id))?.text
        isPro = (try? c.decode(Bool.self, forKey: .is_pro)) ?? false
    }

    /// The value for `friendshipId` in a request body: a number when it is one.
    var friendshipValue: Any { friendshipID.numeric.map { $0 as Any } ?? friendshipID.text }
}

/// `GET /friends` split the way the browser shows it.
struct FriendList: Decodable {
    let all: [FriendEntry]

    private enum CodingKeys: String, CodingKey { case friends }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        all = (try? c.decode(LenientArray<FriendEntry>.self, forKey: .friends))?.items ?? []
    }

    init(all: [FriendEntry]) { self.all = all }

    var friends: [FriendEntry] { all.filter { $0.status == "accepted" } }
    var requests: [FriendEntry] { all.filter { $0.status == "pending" && $0.direction == "received" } }
    var waiting: [FriendEntry] { all.filter { $0.status == "pending" && $0.direction == "sent" } }
    var onlineCount: Int { friends.filter { $0.online }.count }
}

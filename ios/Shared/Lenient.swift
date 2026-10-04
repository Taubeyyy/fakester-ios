import Foundation

/// Lenient decoding helpers.
///
/// The server is written in JavaScript, where the type of a field is a whim of
/// the data source: a player ID comes from Postgres as a number, but as text
/// (`"guest-1712…"`) when the player is a guest. Same with the year - a round's
/// choices arrive as text for the title and as numbers for the year, in the
/// same object.
///
/// Swift is stricter, and that strictness is dangerous here: a decoding error
/// in the middle of a round means the message is dropped and the screen simply
/// freezes. So everything coming from outside goes through these two types
/// instead of relying on a shape the server never promised.

/// Number or text - always comes out as text.
struct LooseValue: Codable, Hashable {
    let text: String

    init(_ t: String) { text = t }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { text = s; return }
        if let i = try? c.decode(Int.self) { text = String(i); return }
        if let d = try? c.decode(Double.self) {
            // 1994.0 should become "1994", not "1994.0".
            text = d == d.rounded() ? String(Int(d)) : String(d)
            return
        }
        if let b = try? c.decode(Bool.self) { text = b ? "true" : "false"; return }
        throw DecodingError.typeMismatch(LooseValue.self, .init(
            codingPath: decoder.codingPath, debugDescription: "neither text nor number"))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(text)
    }

    var numeric: Int? { Int(text) }
}

extension LooseValue: CustomStringConvertible {
    var description: String { text }
}

/// A list where an unusable entry only costs itself.
///
/// Without this, `[Player]` throws on the first broken entry and the whole
/// player list is gone instead of just one entry shorter - in a lobby that
/// would mean an empty screen even though seven people are in it.
struct LenientArray<T: Decodable>: Decodable {
    let items: [T]

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        var kept: [T] = []
        while !c.isAtEnd {
            if let decoded = try? c.decode(T.self) {
                kept.append(decoded)
            } else if (try? c.decode(EmptyObject.self)) != nil {
                // The entry was an object, just not a usable one - skipped.
            } else {
                // Neither: a failed decode does NOT advance the index, so we
                // would never reach the end. Better to stop here than to hang
                // the app.
                break
            }
        }
        items = kept
    }

    /// Accepts any JSON object without requiring a field - which makes it
    /// exactly the tool for skipping a slot.
    private struct EmptyObject: Decodable {}
}

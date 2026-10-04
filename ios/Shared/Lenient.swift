import Foundation

/// Nachsichtige Dekodier-Hilfen.
///
/// Der Server ist in JavaScript geschrieben, und dort ist der Typ eines Feldes
/// eine Laune der Datenquelle: eine Spieler-ID kommt als Zahl aus Postgres,
/// aber als Text (`"guest-1712…"`), wenn der Spieler ein Gast ist. Beim Jahr
/// dasselbe - die Auswahlmoeglichkeiten einer Runde kommen fuer den Titel als
/// Text und fuer das Jahr als Zahl, im selben Objekt.
///
/// Swift ist da strenger, und diese Strenge ist hier gefaehrlich: ein
/// Dekodierfehler mitten in einer Runde heisst, dass die Nachricht verworfen
/// wird und der Bildschirm einfach stehen bleibt. Deshalb geht alles, was von
/// aussen kommt, durch diese zwei Typen, statt sich auf eine Form zu verlassen,
/// die der Server nie zugesagt hat.

/// Zahl oder Text - kommt immer als Text heraus.
struct LooseValue: Codable, Hashable {
    let text: String

    init(_ t: String) { text = t }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { text = s; return }
        if let i = try? c.decode(Int.self) { text = String(i); return }
        if let d = try? c.decode(Double.self) {
            // 1994.0 soll "1994" ergeben, nicht "1994.0".
            text = d == d.rounded() ? String(Int(d)) : String(d)
            return
        }
        if let b = try? c.decode(Bool.self) { text = b ? "true" : "false"; return }
        throw DecodingError.typeMismatch(LooseValue.self, .init(
            codingPath: decoder.codingPath, debugDescription: "weder Text noch Zahl"))
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

/// Eine Liste, bei der ein unbrauchbarer Eintrag nur sich selbst kostet.
///
/// Ohne das wirft `[Spieler]` beim ersten kaputten Eintrag, und die ganze
/// Spielerliste ist weg statt nur um einen Eintrag kuerzer - in einer Lobby
/// hiesse das: Bildschirm leer, obwohl sieben Leute drin sitzen.
struct LenientArray<T: Decodable>: Decodable {
    let items: [T]

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        var kept: [T] = []
        while !c.isAtEnd {
            if let decoded = try? c.decode(T.self) {
                kept.append(decoded)
            } else if (try? c.decode(EmptyObject.self)) != nil {
                // Eintrag war ein Objekt, nur kein brauchbares - uebersprungen.
            } else {
                // Weder das eine noch das andere: ein fehlgeschlagenes decode
                // rueckt den Index NICHT vor, wir kaemen also nie ans Ende.
                // Lieber hier abbrechen als die App haengen lassen.
                break
            }
        }
        items = kept
    }

    /// Nimmt jedes JSON-Objekt an, ohne ein Feld zu verlangen - damit ist es
    /// genau das Werkzeug, um einen Platz zu ueberspringen.
    private struct EmptyObject: Decodable {}
}

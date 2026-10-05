import Foundation

/// The lobby browser in the join dialog (`GET /lobbies/public`).
func checkPublicLobbies() {
    section("Public lobbies")
    // Captured 2026-10-05: nobody had a public lobby open.
    let empty = parse(PublicLobbies.self, #"{"lobbies":[]}"#)
    expectEqual("public lobbies: empty list", empty?.lobbies.count, 0)
    // Shape from the bundle (J3); the PIN as a number must still come out as text.
    let one = parse(PublicLobbies.self, #"""
    {"lobbies":[{"pin":3619,"mode":"quiz","playlistName":"Featured","hostName":"Taubey","lang":"Mixed","genre":"Rock","players":2,"maxPlayers":8},
                {"pin":"1234","mode":"timeline","hostName":"Eno","players":8,"maxPlayers":8}]}
    """#)
    expectEqual("public lobbies: two read", one?.lobbies.count, 2)
    expectEqual("public lobbies: pin as text", one?.lobbies.first?.pin, "3619")
    expectEqual("public lobbies: subtitle skips Mixed", one?.lobbies.first?.subtitle, "Taubey · Quiz · Rock")
    expect("public lobbies: full", one?.lobbies.last?.isFull == true)
    expect("public lobbies: timeline not playable in the app", one?.lobbies.last?.appCanPlay == false)
}

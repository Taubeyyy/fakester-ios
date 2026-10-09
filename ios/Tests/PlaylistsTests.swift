import Foundation

// Saved playlists: the test account's real (empty) list, a filled one shaped
// like the browser stores it, and the cover colour hash checked against the
// bundle's JavaScript (node, 2026-10-09).

func checkSavedPlaylists() {
    section("Saved playlists")
    let real: SavedPlaylistList? = parse(SavedPlaylistList.self, #"{"user":{"id":80,"saved_playlists":[]},"ownedItems":[]}"#)
    expectEqual("the test account has none", real?.items.count, 0)
    let put: SavedPlaylistList? = parse(SavedPlaylistList.self, """
    {"playlists":[{"id":"37i9dQZF1DXcBWIGoYBM5M","name":"Today's Top Hits","image":"https://i.scdn.co/x.jpg","source":"spotify"},
                  {"id":"PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG","name":"Mix","image":null,"source":"youtube"},
                  {"name":"no id"}]}
    """)
    expectEqual("PUT answer: two usable", put?.items.count, 2)
    expectEqual("missing image stays empty", put?.items.last?.image, nil)
    expect("null image is sent as null", put?.items.last?.body["image"] is NSNull)
    expectEqual("hash like the browser (1)", SavedPlaylist.paletteIndex("37i9dQZF1DXcBWIGoYBM5M"), 3)
    expectEqual("hash like the browser (2)", SavedPlaylist.paletteIndex("PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG"), 1)
    expectEqual("hash like the browser (3)", SavedPlaylist.paletteIndex("2Jc0amXy2IvLyTofJKgiYg"), 2)
    expectEqual("five slots", SavedPlaylist.slots(isPro: false), 5)
    expectEqual("ten with PRO", SavedPlaylist.slots(isPro: true), 10)
}

import Foundation

// The Daily: the test account's real `GET /daily` before playing (two of the
// five rounds kept), and the finished shapes the web bundle reads.

private let dailyJSON = #"{"day":277,"songs":5,"played":false,"result":null,"rounds":[{"preview":"https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/2d/87/dd/2d87ddae-c00f-8667-4921-eab6b1d04dc0/mzaf_15493910244771419848.plus.aac.p.m4a","cover":"https://i.scdn.co/image/ab67616d0000b273ff2057b7343d2233451ff8e7","options":["Stole the Show","Bring Me To Life","Dance with Me Tonight","Something Just Like This"]},{"preview":"https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/53/0f/d5/530fd571-c493-bb3f-0055-f8b893eff628/mzaf_3812397447544093866.plus.aac.p.m4a","cover":"https://i.scdn.co/image/ab67616d0000b273737b4ff7928f4569907fbd21","options":["CRIMINAL HEART.","T.N.T.","Mambo No. 5 (A Little Bit of...)","The Sweet Escape"]}],"board":{"top":[],"rank":null,"players":0}}"#

func checkDaily() {
    section("Daily")
    let today: DailyToday? = parse(DailyToday.self, dailyJSON)
    expectEqual("day number", today?.day, 277)
    expectEqual("five songs", today?.songs, 5)
    expect("not played yet", today?.played == false)
    expect("no result yet", today?.result == nil)
    expectEqual("rounds kept", today?.rounds.count, 2)
    expectEqual("four options", today?.rounds.first?.options.count, 4)
    expectEqual("first option", today?.rounds.first?.options.first, "Stole the Show")
    expectEqual("answer hidden before playing", today?.rounds.first?.correct, -1)
    expectEqual("nobody on the board", today?.board.players, 0)
    expect("no rank", today?.board.rank == nil)

    let done: DailyToday? = parse(DailyToday.self, """
    {"day":278,"songs":5,"played":true,"result":{"answers":[1,-1,2,0,3],"correct":3,"total":5,"elapsed_ms":41234},
     "rounds":[{"title":"A","artist":"B","correct":1,"options":["x","y"]}],
     "board":{"top":[{"id":5,"username":"Ana","correct":5,"total":5,"elapsed_ms":30100}],"rank":2,"players":9}}
    """)
    expectEqual("played answers", done?.result?.answers, [1, -1, 2, 0, 3])
    expectEqual("played time", done?.result?.elapsedMs, 41234)
    expectEqual("solution after playing", done?.rounds.first?.correct, 1)
    expectEqual("board row", done?.board.top.first?.username, "Ana")
    expectEqual("rank", done?.board.rank, 2)

    let finish: DailyFinish? = parse(DailyFinish.self, """
    {"day":278,"correct":4,"total":5,"elapsedMs":38000,"reward":{"spots":60,"goldSpots":0},
     "solution":[{"title":"A","artist":"B","cover":null,"correct":2}],"balance":{"spots":330}}
    """)
    expectEqual("finish: correct", finish?.correct, 4)
    expectEqual("finish: reward", finish?.rewardSpots, 60)
    expectEqual("finish: balance", finish?.balanceSpots, 330)
    expectEqual("finish: solution", finish?.solution.first?.correct, 2)
    expectEqual("finish without extras", parse(DailyFinish.self, #"{"correct":1,"total":5}"#)?.rewardSpots, 0)

    expectEqual("share text", DailyRules.shareText(day: 278, correct: 3, total: 5, answers: [1, -1, 2, 0, 3], solution: [1, 2, 2, 1, 3]),
                "Fakester #278 · 3/5\n🟩⬛🟩⬛🟩\nfakester.app")
}

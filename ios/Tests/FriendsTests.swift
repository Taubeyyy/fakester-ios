import Foundation

// Friends: the real (empty) answer of the test account, and entries shaped
// the way the web bundle reads them.

func checkFriends() {
    section("Friends")
    let empty: FriendList? = parse(FriendList.self, #"{"friends":[]}"#)
    expectEqual("the real answer: nobody", empty?.all.count, 0)
    let list: FriendList? = parse(FriendList.self, """
    {"friends":[
     {"id":7,"friendship_id":31,"username":"Ana","status":"accepted","online":true,"equipped_icon_id":9302,"is_pro":true},
     {"id":"8","friendship_id":"32","username":"Ben","status":"accepted","online":false,"avatar_url":null},
     {"id":9,"friendship_id":33,"username":"Cleo","status":"pending","direction":"received"},
     {"id":10,"friendship_id":34,"username":"Dan","status":"pending","direction":"sent"},
     {"username":"no ids"}
    ]}
    """)
    expectEqual("entries without any id are dropped", list?.all.count, 4)
    expectEqual("two friends", list?.friends.map { $0.username }, ["Ana", "Ben"])
    expectEqual("one online", list?.onlineCount, 1)
    expectEqual("one request", list?.requests.first?.username, "Cleo")
    expectEqual("one waiting", list?.waiting.first?.username, "Dan")
    expectEqual("icon id as text", list?.friends.first?.iconID, "9302")
    expect("pro flag", list?.friends.first?.isPro == true)
    expect("numeric friendship id goes back as a number", list?.friends.first?.friendshipValue as? Int == 31)
    expect("text friendship id stays numeric too", list?.friends.last?.friendshipValue as? Int == 32)
}

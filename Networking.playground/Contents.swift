//: To run this playground start a SimpleHTTPServer on the commandline like this:
//:
//: `cd current directory`
//: `python -m SimpleHTTPServer 8000`
//:
//: It will serve up the current directory, so make sure to be in the directory containing episodes.json

struct Episode: Decodable {
    let id: String
    let title: String
}

let configuration = Networking.Configuration(base: "http://localhost:8000", api: nil)!
let request = Networking.Request(method: .get,
                                 endpoint: "episodes.json")
let episodes = Networking.Resource<[Episode]>(request: request)

let task = try? Networking.Service(configuration).task(for: episodes) { print($0) }
task?.resume()

let testService = Networking.TestService(configuration: configuration,
                                         responses: [Networking.ResourceAndResponse(episodes,
                                                                                    response: Networking.Result(value: [Episode(id: "1", title: "Test")]))])

func displayEpisodes() {
    try? testService.task(for: episodes) { print($0) }
}

displayEpisodes()
testService.verify()

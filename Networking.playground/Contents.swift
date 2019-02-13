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

let request = Networking.Request(method: .get,
                                 endpoint: "episodes.json")
let resource = Networking.Resource<[Episode]>(request: request)
let configuration = Networking.Configuration(base: "http://localhost:8000", api: nil)!

let task = try? Networking.Service(configuration).task(for: resource) { print($0) }
task?.resume()

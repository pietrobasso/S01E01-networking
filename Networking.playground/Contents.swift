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

let request = RequestImplementation(method: RequestMethod.get(nil),
                                    endpoint: Path<Relative, Directory>(directoryComponents: ["episodes.json"]),
                                    parameters: nil,
                                    headers: nil)
let resource = Resource<[Episode]>(request: request)
let configuration = WebserviceConfiguration(base: "http://localhost:8000", api: nil)!
WebserviceImplementation(configuration).request(resource: resource) { (result) in
    print(result)
}

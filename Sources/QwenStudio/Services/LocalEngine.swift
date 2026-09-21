import Foundation

struct LocalEngine {
    let baseURL: URL
    var precision: ModelPrecision = .full
    private func request(_ path: String, body: [String: Any]? = nil) async throws -> Data {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.timeoutInterval = 30
        if let body {
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data,response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "Keine Antwort"
            throw StudioError.message("The local engine reported an error: \(detail.prefix(600))")
        }
        return data
    }
    func health() async throws {
        _ = try await request("system_stats")
    }
    func upload(_ file: URL) async throws -> String {
        let boundary = "Lichtbild-" + UUID().uuidString
        var req = URLRequest(url: baseURL.appendingPathComponent("upload/image"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let name = UUID().uuidString + ".png"
        var data = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"\(name)\"\r\nContent-Type: image/png\r\n\r\n".utf8)
        data.append(try Data(contentsOf: file))
        data.append(Data("\r\n--\(boundary)--\r\n".utf8))
        req.httpBody = data
        let (result,response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let obj = try JSONSerialization.jsonObject(with: result) as? [String: Any], let saved = obj["name"] as? String else {
            throw StudioError.message("The reference image could not be loaded.")
        }
        return saved
    }
    func submit(_ request: GenerationRequest, uploaded: [String], clientID: String) async throws -> String {
        let data = try await self.request("prompt", body: ["prompt": Workflow.make(request, uploaded: uploaded, precision: precision), "client_id": clientID])
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let id = object["prompt_id"] as? String else {
            throw StudioError.message("The image request was not accepted.")
        }
        return id
    }
    func result(id: String) async throws -> Data? {
        let data = try await request("history/\(id)")
        guard let all = try JSONSerialization.jsonObject(with: data) as? [String: Any], let job = all[id] as? [String: Any] else { return nil }
        if let status = job["status"] as? [String: Any], status["status_str"] as? String == "error" {
            let messages = status["messages"] as? [[Any]] ?? []
            let detail = messages.compactMap { $0.count > 1 ? ($0[1] as? [String: Any])?["exception_message"] as? String : nil }.first
            throw StudioError.message(detail ?? "Image generation was interrupted. Please try again.")
        }
        guard let outputs = job["outputs"] as? [String: Any], let output = outputs["8"] as? [String: Any],
              let images = output["images"] as? [[String: Any]], let image = images.first,
              let filename = image["filename"] as? String else { return nil }
        var url = URLComponents(url: baseURL.appendingPathComponent("view"), resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "filename", value: filename), URLQueryItem(name: "subfolder", value: image["subfolder"] as? String ?? ""), URLQueryItem(name: "type", value: "output")]
        let (bytes,response) = try await URLSession.shared.data(from: url.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw StudioError.message("The finished image could not be opened.") }
        return bytes
    }
    func cancel(id: String?) async throws {
        if let id { _ = try await request("queue", body: ["delete": [id]]) }
        _ = try await request("interrupt", body: [:])
    }
    func progressSocket(clientID: String) -> URLSessionWebSocketTask {
        var components = URLComponents(url: baseURL.appendingPathComponent("ws"), resolvingAgainstBaseURL: false)!
        components.scheme = "ws"
        components.queryItems = [URLQueryItem(name: "clientId", value: clientID)]
        let socket = URLSession.shared.webSocketTask(with: components.url!)
        socket.resume()
        return socket
    }
}

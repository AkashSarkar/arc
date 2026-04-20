import Foundation

protocol HTTPClient {
    func post<RequestBody: Encodable, ResponseBody: Decodable>(
        url: URL,
        headers: [String: String],
        body: RequestBody,
        timeout: TimeInterval
    ) async throws -> ResponseBody
}

struct URLSessionHTTPClient: HTTPClient {
    func post<RequestBody: Encodable, ResponseBody: Decodable>(
        url: URL,
        headers: [String: String],
        body: RequestBody,
        timeout: TimeInterval
    ) async throws -> ResponseBody {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try JSONDecoder().decode(ResponseBody.self, from: data)
        } catch {
            throw NetworkError.decodingFailure
        }
    }
}

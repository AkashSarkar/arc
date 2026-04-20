import Foundation

protocol HTTPClient {
    func get<ResponseBody: Decodable>(
        url: URL,
        headers: [String: String],
        queryItems: [URLQueryItem],
        timeout: TimeInterval
    ) async throws -> ResponseBody

    func post<RequestBody: Encodable, ResponseBody: Decodable>(
        url: URL,
        headers: [String: String],
        body: RequestBody,
        timeout: TimeInterval
    ) async throws -> ResponseBody
}

struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        session: URLSession? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.waitsForConnectivity = true
            self.session = URLSession(configuration: configuration)
        }

        self.encoder = encoder
        self.decoder = decoder
    }

    func get<ResponseBody: Decodable>(
        url: URL,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        timeout: TimeInterval
    ) async throws -> ResponseBody {
        try await send(
            method: "GET",
            url: url,
            headers: headers,
            queryItems: queryItems,
            body: nil,
            timeout: timeout
        )
    }

    func post<RequestBody: Encodable, ResponseBody: Decodable>(
        url: URL,
        headers: [String: String],
        body: RequestBody,
        timeout: TimeInterval
    ) async throws -> ResponseBody {
        let bodyData = try encoder.encode(body)

        return try await send(
            method: "POST",
            url: url,
            headers: headers,
            queryItems: [],
            body: bodyData,
            timeout: timeout
        )
    }

    private func send<ResponseBody: Decodable>(
        method: String,
        url: URL,
        headers: [String: String],
        queryItems: [URLQueryItem],
        body: Data?,
        timeout: TimeInterval
    ) async throws -> ResponseBody {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidRequest
        }

        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }

        guard let resolvedURL = components.url else {
            throw NetworkError.invalidRequest
        }

        var request = URLRequest(url: resolvedURL)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(ResponseBody.self, from: data)
        } catch {
            throw NetworkError.decodingFailure
        }
    }
}

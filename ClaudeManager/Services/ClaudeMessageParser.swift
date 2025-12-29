import Foundation

final class ClaudeMessageParser: Sendable {
    private let decoder: JSONDecoder

    init() {
        self.decoder = JSONDecoder()
    }

    func parse(line: String) -> ClaudeStreamMessage? {
        guard !line.isEmpty else { return nil }

        guard let data = line.data(using: .utf8) else { return nil }

        do {
            return try decoder.decode(ClaudeStreamMessage.self, from: data)
        } catch {
            print("[ClaudeMessageParser] Failed to parse line: \(error)")
            return nil
        }
    }
}

import Foundation

protocol GitServiceProtocol: Sendable {
    func commitAll(message: String, in directory: URL) async throws -> GitServiceResult
}

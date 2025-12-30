import Foundation

protocol BuildTestServiceProtocol: Sendable {
    func detectProjectType(in directory: URL) -> ProjectType
    func runBuild(in directory: URL, config: ProjectConfiguration) async throws -> BuildResult
    func runTests(in directory: URL, config: ProjectConfiguration) async throws -> TestResult
}

import Foundation

@MainActor
@Observable
final class UserPreferences {
    // MARK: - Constants

    private enum Keys {
        static let lastProjectPath = "lastProjectPath"
        static let recentProjects = "recentProjects"
        static let autonomousConfig = "autonomousConfig"
        static let claudeCLIPath = "claudeCLIPath"
    }

    static let maxRecentProjects = 10

    // MARK: - Private Properties

    private let defaults = UserDefaults.standard

    // MARK: - Public Properties

    var lastProjectPath: URL? {
        get {
            guard let path = defaults.string(forKey: Keys.lastProjectPath) else { return nil }
            return URL(filePath: path)
        }
        set {
            defaults.set(newValue?.path(), forKey: Keys.lastProjectPath)
            if let url = newValue {
                addToRecentProjects(url)
            }
        }
    }

    var recentProjects: [URL] {
        get {
            let paths = defaults.stringArray(forKey: Keys.recentProjects) ?? []
            return paths.compactMap { URL(filePath: $0) }
        }
        set {
            let paths = newValue.prefix(Self.maxRecentProjects).map { $0.path() }
            defaults.set(Array(paths), forKey: Keys.recentProjects)
        }
    }

    var autonomousConfig: AutonomousConfiguration {
        get {
            guard let data = defaults.data(forKey: Keys.autonomousConfig),
                  let config = try? JSONDecoder().decode(AutonomousConfiguration.self, from: data) else {
                return .default
            }
            return config
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.autonomousConfig)
            }
        }
    }

    /// Custom path to Claude CLI executable. If nil, auto-detection is used.
    var claudeCLIPath: String? {
        get {
            defaults.string(forKey: Keys.claudeCLIPath)
        }
        set {
            defaults.set(newValue, forKey: Keys.claudeCLIPath)
        }
    }

    // MARK: - Methods

    func addToRecentProjects(_ url: URL) {
        var projects = recentProjects
        projects.removeAll { $0.path() == url.path() }
        projects.insert(url, at: 0)
        recentProjects = Array(projects.prefix(Self.maxRecentProjects))
    }
}

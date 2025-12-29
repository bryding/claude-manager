import Foundation

@MainActor
@Observable
final class UserPreferences {
    // MARK: - Constants

    private enum Keys {
        static let lastProjectPath = "lastProjectPath"
        static let recentProjects = "recentProjects"
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

    // MARK: - Methods

    func addToRecentProjects(_ url: URL) {
        var projects = recentProjects
        projects.removeAll { $0.path() == url.path() }
        projects.insert(url, at: 0)
        recentProjects = Array(projects.prefix(Self.maxRecentProjects))
    }
}

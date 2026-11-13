import Foundation

struct TabSnapshot: Codable, Equatable, Sendable {
    var leftPath: String?
    var rightPath: String?
    /// Security-scoped bookmark used to restore sandbox access after relaunch.
    var leftBookmark: Data?
    var rightBookmark: Data?

    init(
        leftPath: String? = nil,
        rightPath: String? = nil,
        leftBookmark: Data? = nil,
        rightBookmark: Data? = nil
    ) {
        self.leftPath = leftPath
        self.rightPath = rightPath
        self.leftBookmark = leftBookmark
        self.rightBookmark = rightBookmark
    }
}

struct WindowSnapshot: Codable, Equatable, Sendable {
    var selectedTabIndex: Int
    var tabs: [TabSnapshot]
}

struct AppSessionSnapshot: Codable, Equatable, Sendable {
    var windows: [WindowSnapshot]
}

enum SessionPersistence {
    static let defaultsKey = "hommerge.sessionSnapshot"

    static func load(from defaults: UserDefaults = .standard) -> AppSessionSnapshot? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(AppSessionSnapshot.self, from: data)
    }

    static func save(_ snapshot: AppSessionSnapshot, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: defaultsKey)
    }
}

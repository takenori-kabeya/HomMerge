import Foundation

struct TabSnapshot: Codable, Equatable, Sendable {
    var leftPath: String?
    var rightPath: String?
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

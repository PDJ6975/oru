import Foundation

nonisolated enum PendingSessionStore {

    struct Session: Codable {
        let startDate: Date
        let endDate: Date
        let selectedMinutes: Int
        let habitName: String?
        let trackHabit: Bool
    }

    private static let key = "pendingTimerSession"

    static func save(_ session: Session) {
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> Session? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

import Foundation

/// Cuerpo del toggle de un hábito (`POST /habits/:habitId/toggle`).
struct ToggleHabitRequest: Encodable {
    let amount: Double
}

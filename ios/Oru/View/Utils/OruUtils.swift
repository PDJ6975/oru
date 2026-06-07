import Foundation

// Convierte el weekday del Calendar de Apple al modelo Habit.Weekday
// Calendar: 1=domingo, 2=lunes...7=sábado → Habit.Weekday: 1=lunes...7=domingo
func weekday(from date: Date) -> Habit.Weekday {
    let wd = Calendar.current.component(.weekday, from: date)
    let mapped = wd == 1 ? 7 : wd - 1
    return Habit.Weekday(rawValue: mapped) ?? .monday
}

// MARK: - Date Formatting

private let spanishLocale = Locale(identifier: "es_ES")

func todayDay() -> String {
    let formatter = DateFormatter()
    formatter.locale = spanishLocale
    formatter.dateFormat = "dd"
    return formatter.string(from: .now)
}

func todayWeekday() -> String {
    let formatter = DateFormatter()
    formatter.locale = spanishLocale
    formatter.dateFormat = "EEEE"
    return formatter.string(from: .now).capitalized
}

// MARK: - Weekday Short Label

extension Habit.Weekday {
    var shortLabel: String {
        switch self {
        case .monday: "L"
        case .tuesday: "M"
        case .wednesday: "X"
        case .thursday: "J"
        case .friday: "V"
        case .saturday: "S"
        case .sunday: "D"
        }
    }
}

extension WeekDay {
    var shortLabel: String {
        switch self {
        case .monday: "L"
        case .tuesday: "M"
        case .wednesday: "X"
        case .thursday: "J"
        case .friday: "V"
        case .saturday: "S"
        case .sunday: "D"
        }
    }
}

// MARK: - Double Formatting

extension Double {

    // Formatea sin decimales si es entero, con un decimal si no.
    // Ejemplo: 5.0 -> "5", 3.5 -> "3.5"
    var formatted: String {
        truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", self)
            : String(format: "%.1f", self)
    }

    // Formatea con unidad opcional: "5 km", "3.5 min", o solo "5".
    func formatted(unit: Unit?) -> String {
        unit.map { "\(formatted) \($0.name)" } ?? formatted
    }
}

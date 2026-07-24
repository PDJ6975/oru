import SwiftUI

/// Mapa de calor del año mostrado en las estadísticas.
struct YearHeatmapView: View {

    private let year: Int
    private let complianceRate: Double
    private let activity: [Int: DayActivityDTO]
    private let daysInMonth: [Int]

    private let cellRadius: CGFloat = 2
    private let cellSpacing: CGFloat = 2
    private let monthSpacing: CGFloat = 5

    private let firstColumn = 1...16
    private let secondColumn = 17...32

    init(year: Int, complianceRate: Double, activity: [DayActivityDTO]) {
        self.year = year
        self.complianceRate = complianceRate
        let calendar = Calendar.current
        self.activity = Dictionary(
            activity.map { (Self.key(for: $0.date, calendar: calendar), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.daysInMonth = (1...12).map { month in
            let firstDay = DateComponents(year: year, month: month, day: 1)
            guard let date = calendar.date(from: firstDay),
                  let range = calendar.range(of: .day, in: .month, for: date) else { return 31 }
            return range.count
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            rateHeader
            monthHeader
            grid
            legend
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    // MARK: - Subvistas

    /// La cifra que resume el mapa
    private var rateHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(rateText)
                .oruHeroValue()

            Text("de cumplimiento")
                .oruMetricLabel()

            Spacer(minLength: 0)
        }
    }

    private var rateText: String {
        if complianceRate == 0 { return "0 %" }
        if complianceRate.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(complianceRate)) %"
        }
        return String(format: "%.1f %%", complianceRate)
    }

    private var monthHeader: some View {
        HStack(spacing: monthSpacing) {
            ForEach(1...12, id: \.self) { month in
                Text("\(month)")
                    .oruExpandButton()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        HStack(alignment: .top, spacing: monthSpacing) {
            ForEach(1...12, id: \.self) { month in
                HStack(alignment: .top, spacing: cellSpacing) {
                    column(month: month, days: firstColumn)
                    column(month: month, days: secondColumn)
                }
            }
        }
    }

    private func column(month: Int, days: ClosedRange<Int>) -> some View {
        VStack(spacing: cellSpacing) {
            ForEach(days, id: \.self) { day in
                cell(month: month, day: day)
            }
        }
    }

    private func cell(month: Int, day: Int) -> some View {
        RoundedRectangle(cornerRadius: cellRadius, style: .continuous)
            .fill(level(month: month, day: day).color)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                // El día en curso se marca con un borde
                if isToday(month: month, day: day) {
                    RoundedRectangle(cornerRadius: cellRadius, style: .continuous)
                        .strokeBorder(Color.primary, lineWidth: 1.5)
                }
            }
    }

    private var legend: some View {
        HStack(spacing: 5) {
            legendSwatch(CellLevel.rest.color)

            Text("Descanso")
                .oruTextSecondary()

            Spacer(minLength: 12)

            HStack(spacing: 3) {
                ForEach(Array(CellLevel.completionScale.enumerated()), id: \.offset) { _, color in
                    legendSwatch(color)
                }
            }

            Text("Hábitos completados")
                .oruTextSecondary()
        }
    }

    private func legendSwatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: cellRadius, style: .continuous)
            .fill(color)
            .frame(width: 10, height: 10)
    }

    // MARK: - Lógica de celda

    private func level(month: Int, day: Int) -> CellLevel {
        guard day <= daysInMonth[month - 1] else { return .outOfMonth }
        guard let activity = activity[month * 100 + day] else { return .none }
        guard activity.scheduled > 0 else { return .rest }
        guard activity.completed > 0 else { return .none }
        return activity.completed >= activity.scheduled ? .complete : .partial
    }

    private func isToday(month: Int, day: Int) -> Bool {
        let today = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return today.year == year && today.month == month && today.day == day
    }

    private static func key(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.month, .day], from: date)
        return (components.month ?? 0) * 100 + (components.day ?? 0)
    }
}

// MARK: - Escala de color

private enum CellLevel {
    /// El día no existe en ese mes (por ejemplo, el 31 de febrero).
    case outOfMonth
    /// Sin hábitos programados: día de descanso.
    case rest
    /// Ningún hábito completado, o el día aún no ha llegado.
    case none
    /// Parte de los hábitos programados.
    case partial
    /// Todos los hábitos programados.
    case complete

    var color: Color {
        switch self {
        case .outOfMonth: .clear
        case .rest: Color.secondary.opacity(0.55)
        case .none: Color.secondary.opacity(0.15)
        case .partial: Color.oruPrimary.opacity(0.35)
        case .complete: Color.oruPrimary
        }
    }

    static let completionScale: [Color] = [
        CellLevel.none.color,
        CellLevel.partial.color,
        CellLevel.complete.color
    ]
}

#Preview {
    let year = Calendar.current.component(.year, from: .now)
    ScrollView {
        YearHeatmapView(year: year, complianceRate: 78.4, activity: [])
            .padding()
    }
}

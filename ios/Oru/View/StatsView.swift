import SwiftUI

struct StatsView: View {

    @Bindable var viewModel: StatsViewModel
    @State private var showAllHabits = false
    @State private var showRankingInfo = false
    @State private var showArchivedInfo = false
    @State private var selectedMetric: String?
    @State private var selectedOrigami: CompletedOrigamiDTO?

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let topCount = 3

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Tu Resumen General
                VStack(spacing: 18) {
                    Text("Tu Resumen General")
                        .oruSectionTitle()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    YearHeatmapView(
                        year: viewModel.selectedYear,
                        complianceRate: viewModel.complianceRate,
                        activity: viewModel.yearActivity
                    )

                    metricsGrid

                    Divider()
                }

                // MARK: - Tus Rutinas Principales
                habitsSection

                // MARK: - Hábitos Archivados
                if !viewModel.archivedHabitStats.isEmpty {
                    Divider()
                    archivedSection
                }

                // MARK: - Galería de Origamis
                if !viewModel.completedOrigamis.isEmpty {
                    Divider()
                    origamiSection
                }
            }
            .padding(.horizontal)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Button { changeYear(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .bold))
                            .oruAccentPrimary()
                    }
                    .disabled(!canGoBack)
                    .opacity(canGoBack ? 1 : 0) // se oculta y no se eliminan para que el título esté fijo

                    HStack(spacing: 0) {
                        Text("Seguimiento Anual ")
                            .oruAccent()
                        Text(String(viewModel.selectedYear))
                            .oruAccentPrimary()
                    }

                    Button { changeYear(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .oruAccentPrimary()
                    }
                    .disabled(!canGoForward)
                    .opacity(canGoForward ? 1 : 0)
                }
                .fixedSize()
            }
        }
        .task {
            await viewModel.loadStats()
        }
        .connectionErrorAlert(
            isPresented: $viewModel.connectionErrorPresented,
            onRetry: { Task { await viewModel.loadStats() } }
        )
    }

    // MARK: - Subvistas

    /// Métricas del año
    private var metricsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            metricCard(
                icon: "flame",
                value: "\(viewModel.currentStreak)",
                label: "Racha actual",
                help: "Días perfectos seguidos que llevas hasta hoy 🔥."
            )
            metricCard(
                icon: "trophy",
                value: "\(viewModel.bestStreak)",
                label: "Mejor racha",
                help: "La racha de días perfectos más larga que has logrado este año 🏆."
            )
            metricCard(
                icon: "checkmark.seal",
                value: "\(viewModel.habitsCompleted)",
                label: "Completados",
                help: "Todas las veces que has completado un hábito a lo largo del año ✅."
            )
            metricCard(
                icon: "star",
                value: "\(viewModel.perfectDays)",
                label: "Perfectos",
                help: "Días en los que completaste todos los hábitos que tenías programados 🌟."
            )
        }
    }

    private func metricCard(icon: String, value: String, label: String, help: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(Color.oruPrimary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .oruMetricValue()

                Text(label)
                    .oruTextSecondary()
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button { selectedMetric = label } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Qué mide \(label)")
            .popover(isPresented: metricPopover(for: label), arrowEdge: .top) {
                Text(help)
                    .oruTip()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 240)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private func metricPopover(for label: String) -> Binding<Bool> {
        Binding(
            get: { selectedMetric == label },
            set: { isPresented in if !isPresented { selectedMetric = nil } }
        )
    }

    private var canGoBack: Bool {
        viewModel.selectedYear > viewModel.minYear
    }

    private var canGoForward: Bool {
        viewModel.selectedYear < viewModel.maxYear
    }

    private func changeYear(by delta: Int) {
        viewModel.selectedYear += delta
    }

    private var visibleHabits: [HabitStatsDTO] {
        showAllHabits ? viewModel.habitStats : Array(viewModel.habitStats.prefix(topCount))
    }

    private var hasMoreHabits: Bool {
        viewModel.habitStats.count > topCount
    }

    private var habitsSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Text("Tus Rutinas Principales")
                    .oruSectionTitle()

                Button { showRankingInfo.toggle() } label: {
                    Image(systemName: "questionmark")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.oruPrimary)
                        .padding(4)
                }
                .glassEffect(.regular, in: .circle)
                .popover(isPresented: $showRankingInfo, arrowEdge: .top) {
                    Text("Tus hábitos se ordenan según constancia y racha actual."
                         + " Cuantos más días completes y mayor sea tu racha,"
                         + " más arriba aparecerán 🙌🏻.")
                        .oruTip()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 240)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.habitStats.isEmpty {
                statsEmptyRow
            } else {
                ForEach(visibleHabits) { stat in
                    habitRow(stat)
                }
            }

            if hasMoreHabits {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showAllHabits.toggle()
                        }
                    } label: {
                        Text(showAllHabits ? "Ver menos" : "Ver todos")
                            .oruExpandButton()
                            .foregroundStyle(Color.oruPrimary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 3)
                    }
                    .glassEffect(.regular, in: .capsule)
                }
            }
        }
    }

    private func habitRow(_ stat: HabitStatsDTO) -> some View {
        HStack(spacing: 12) {
            Text(stat.habitIcon)
                .font(.system(size: 24))
                .frame(width: 36)

            VStack(spacing: 6) {
                // Fila 1: nombre a la izquierda, métricas principales a la derecha
                HStack {
                    Text(stat.habitName)
                        .oruTextPrimary()
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        habitMetric(icon: "flame", value: "\(stat.currentStreak)")
                        habitMetric(icon: "trophy", value: "\(stat.bestStreak)")
                        habitMetric(icon: "checkmark.seal", value: "\(stat.totalCompletions)")
                    }
                }

                // Fila 2 (solo quantity): acumulado a la izquierda, media a la derecha
                if stat.habitType == .quantity {
                    HStack {
                        Text("Total: \(stat.totalAccumulation.formatted(unitName: stat.habitUnit))")
                            .oruTextSecondary()

                        Spacer(minLength: 0)

                        Text("Media: \(stat.dailyAverage.formatted(unitName: stat.habitUnit))")
                            .oruTextSecondary()
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var statsEmptyRow: some View {
        HStack(spacing: 10) {
            Text("😬")
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 4) {
                Text("Sin estadísticas aún")
                    .oruTextPrimary()

                Text("Registra hábitos para ver aquí tu progreso.")
                    .oruTextSecondary()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    // MARK: - Sección de hábitos archivados

    private var archivedSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Text("Hábitos que te Definen")
                    .oruSectionTitle()

                Button { showArchivedInfo.toggle() } label: {
                    Image(systemName: "questionmark")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.oruPrimary)
                        .padding(4)
                }
                .glassEffect(.regular, in: .circle)
                .popover(isPresented: $showArchivedInfo, arrowEdge: .top) {
                    Text("Aquí se almacenan los hábitos consolidados"
                         + " que has archivado y que definen tu identidad 🌟.")
                        .oruTip()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 240)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.archivedHabitStats.enumerated()), id: \.element.id) { idx, stat in
                    archivedRow(stat)

                    if idx < viewModel.archivedHabitStats.count - 1 {
                        Divider().padding(.horizontal, 14)
                    }
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
    }

    private func archivedRow(_ stat: HabitStatsDTO) -> some View {
        HStack(spacing: 12) {
            Text(stat.habitIcon)
                .font(.system(size: 22))
                .frame(width: 32)

            VStack(spacing: 6) {
                HStack {
                    Text(stat.habitName)
                        .oruTextPrimary()
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        habitMetric(icon: "trophy", value: "\(stat.bestStreak)")
                        habitMetric(icon: "checkmark.seal", value: "\(stat.totalCompletions)")
                    }
                }

                if stat.habitType == .quantity {
                    HStack {
                        Text("Total: \(stat.totalAccumulation.formatted(unitName: stat.habitUnit))")
                            .oruTextSecondary()

                        Spacer(minLength: 0)

                        Text("Media: \(stat.dailyAverage.formatted(unitName: stat.habitUnit))")
                            .oruTextSecondary()
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Galería de origamis completados

    private var origamiSection: some View {
        VStack(spacing: 14) {
            Text("Tu Colección de Origamis")
                .oruSectionTitle()
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.completedOrigamis, id: \.id) { uo in
                        origamiCard(uo)
                            .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                            .onTapGesture { selectedOrigami = uo }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .sheet(item: $selectedOrigami) { uo in
            origamiDetail(uo)
        }
    }

    private func origamiCard(_ uo: CompletedOrigamiDTO) -> some View {
        VStack(spacing: 8) {
            Image(uo.illustration)
                .resizable()
                .scaledToFit()
                .frame(height: 140)

            Text(uo.name.capitalized)
                .oruTextPrimary()
                .lineLimit(1)

            Text(uo.completedAt.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es_ES"))))
                .oruTextSecondary()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private func origamiDetail(_ uo: CompletedOrigamiDTO) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(uo.illustration)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 40)

            Text(uo.name.capitalized)
                .oruSectionTitle()

            Text("Completado el \(uo.completedAt.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "es_ES"))))")
                .oruTextSecondary()

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func habitMetric(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Color.oruPrimary)
            Text(value)
                .oruExpandButton()
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    let client = APIClient(tokenStore: TokenStore())
    NavigationStack {
        StatsView(viewModel: StatsViewModel(
            statsService: StatsService(client: client),
            origamiService: OrigamiService(client: client)
        ))
    }
}

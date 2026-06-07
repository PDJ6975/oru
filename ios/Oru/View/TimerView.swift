import SwiftData
import SwiftUI

struct TimerView: View {

    @Bindable var viewModel: TimerViewModel
    @State private var isEditing = false
    @State private var showCancelAlert = false
    @State private var showHabitInfo = false

    var body: some View {
        VStack(spacing: 0) {
            timerDisplay
                .padding(.top, 40)

            controls

            if viewModel.state == .idle {
                habitTrackingCard
                    .padding(.top, 35)
                    .padding(.horizontal, 24)

                Image("fondo_temporizador")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 190)
                    .padding(.top, 70)
            }
        }
        .frame(maxHeight: .infinity, alignment: viewModel.state == .running ? .center : .top)
        .padding(.top, viewModel.state == .idle ? 80 : 0)
        .background {
            if viewModel.state == .running {
                ButterflyOverlayView()
                    .transition(.opacity)
            }
        }
        .toolbarVisibility(viewModel.state == .running ? .hidden : .visible, for: .tabBar)
        .animation(.easeInOut(duration: 0.4), value: viewModel.state)
        .alert("¿Quieres acabar ya la sesión?", isPresented: $showCancelAlert) {
            Button("Finalizar", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.cancel()
                }
            }
            Button("Continuar", role: .cancel) { }
        }
        .task {
            viewModel.loadCompatibleHabits()
        }
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        HStack(spacing: 15) {
            stepButton(systemName: "minus", enabled: viewModel.canDecrease) {
                viewModel.selectedMinutes -= TimerViewModel.stepMinutes
            }

            timerText

            stepButton(systemName: "plus", enabled: viewModel.canIncrease) {
                viewModel.selectedMinutes += TimerViewModel.stepMinutes
            }
        }
    }

    private var timerText: some View {
        Group {
            if let interval = viewModel.timerInterval, viewModel.state == .running {
                Text(timerInterval: interval, countsDown: true, showsHours: false)
            } else {
                Text(formattedTime)
            }
        }
        .oruTimerDisplay()
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        if viewModel.state == .running {
            Button {
                showCancelAlert = true
            } label: {
                Image(systemName: "xmark")
                    .oruIconButton()
            }
            .padding(.top, 10)
            .transition(.opacity.combined(with: .scale))
        } else {
            HStack(spacing: 20) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = false
                        viewModel.start()
                    }
                } label: {
                    Image(systemName: "play")
                        .oruIconButton()
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing.toggle()
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                        .oruIconButton()
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding(.top, 10)
            .transition(.opacity)
        }
    }

    // MARK: - Habit Tracking Card

    private var habitTrackingCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Toggle(isOn: $viewModel.trackHabit) {
                Text("Registrar tiempo de la sesión:")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
            .tint(Color.oruPrimary)

            HStack(spacing: 10) {
                Menu {
                    Button {
                        viewModel.selectedHabit = nil
                    } label: {
                        Text("Ninguno")
                    }
                    ForEach(viewModel.compatibleHabits) { habit in
                        Button {
                            viewModel.selectedHabit = habit
                        } label: {
                            Text("\(habit.icon) \(habit.name)")
                        }
                    }
                } label: {
                    HStack {
                        if let habit = viewModel.selectedHabit {
                            Text("\(habit.icon) \(habit.name)")
                                .oruTextPrimary()
                        } else {
                            Text("Selecciona uno de tus hábitos")
                                .oruInputSmall()
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!viewModel.trackHabit)
                .opacity(viewModel.trackHabit ? 1 : 0.4)

                Divider()
                    .frame(height: 28)

                Button { showHabitInfo.toggle() } label: {
                    Image(systemName: "questionmark")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.oruPrimary)
                        .padding(4)
                }
                .glassEffect(.regular.tint(.white), in: .circle)
                .popover(isPresented: $showHabitInfo, arrowEdge: .top) {
                    Text("💡Solo aparecerán hábitos activos de cantidad"
                         + " con unidad de tiempo (min,h).")
                        .oruTip()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 260)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            .padding(10)
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    // MARK: - Step Buttons

    @ViewBuilder
    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        if isEditing && viewModel.state == .idle {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(enabled ? .secondary : .quaternary)
            }
            .disabled(!enabled)
            .transition(.opacity.combined(with: .scale))
        }
    }

    private var formattedTime: String {
        String(format: "%02d:%02d", viewModel.selectedMinutes, 0)
    }
}

// MARK: - Preview

#Preview(traits: .sampleData) {
    @Previewable @Environment(\.modelContext) var context
    let repo = HabitRepository(modelContext: context)
    let client = APIClient(tokenStore: TokenStore())
    TimerView(viewModel: TimerViewModel(repository: repo, habitVM:
        HabitViewModel(repository: repo, habitService: HabitService(client: client), unitService: UnitService(client: client))))
}

import SwiftUI

struct NameRegistrationView: View {
    @Bindable var viewModel: WelcomeViewModel
    var onRegistered: () -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {

            headerSection

            nameInputSection

            Spacer()

            continueButton
        }
        .padding(32)
        .onAppear {
            isNameFocused = true
        }
        .connectionErrorAlert(
            isPresented: $viewModel.connectionErrorPresented,
            onRetry: attemptRegistration
        )
    }
}

// MARK: - Sections

private extension NameRegistrationView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Todo empieza aquí")
                .oruTitle()

            Text("Cualquier proceso de transformación necesita un protagonista.")
                .oruBody()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var nameInputSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                Text("¿Cómo te gustaría que te llamemos?")
                    .oruLabel()

                TextField("Tu nombre", text: $viewModel.name)
                    .oruInputMedium()
                    .padding(14)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .focused($isNameFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(attemptRegistration)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))

            HStack(alignment: .top, spacing: 5) {
                Image(systemName: "heart")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.oruPrimary)

                Text("Elige con cariño. Este nombre será definitivo.")
                    .oruTip()
            }
            .frame(maxWidth: .infinity)
        }
    }

    var continueButton: some View {
        Button(action: attemptRegistration) {
            Group {
                if viewModel.isRegistering {
                    ProgressView()
                } else {
                    Text("Continuar")
                        .oruButton()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .tint(.oruPrimary)
        .disabled(!viewModel.isNameValid || viewModel.isRegistering)
    }}

// MARK: - Actions

private extension NameRegistrationView {
    func attemptRegistration() {
        isNameFocused = false
        Task {
            if await viewModel.register() {
                onRegistered()
            }
        }
    }
}

#Preview {
    NameRegistrationView(
        viewModel: WelcomeViewModel(authService: AppDependencies().authService),
        onRegistered: {}
    )
}

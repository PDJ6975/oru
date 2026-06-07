import SwiftUI

struct ContentView: View {
    let dependencies: AppDependencies

    /// Si hay sesión saltamos la bienvenida
    @State private var hasSession: Bool
    @State private var showNameRegistration = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _hasSession = State(initialValue: dependencies.authService.hasSession)
    }

    var body: some View {
        Group {
            if hasSession {
                MainTabView(dependencies: dependencies)
            } else if showNameRegistration {
                NameRegistrationView(
                    viewModel: WelcomeViewModel(authService: dependencies.authService),
                    onRegistered: {
                        withAnimation {
                            hasSession = true
                        }
                    }
                )
                .transition(.push(from: .trailing))
            } else {
                WelcomeView {
                    withAnimation {
                        showNameRegistration = true
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView(dependencies: AppDependencies())
}

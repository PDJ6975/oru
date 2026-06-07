import SwiftUI

@main
struct OruApp: App {
    @State private var dependencies = AppDependencies()

    init() {
        // Permite a los UI tests arrancar desde la bienvenida borrando la sesión.
        if CommandLine.arguments.contains("-resetOnboarding") {
            TokenStore().clear()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies)
        }
    }
}

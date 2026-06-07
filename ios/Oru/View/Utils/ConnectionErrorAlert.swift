import SwiftUI

extension View {
    /// Alert estándar de no conexión
    func connectionErrorAlert(
        isPresented: Binding<Bool>,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        alert("Sin conexión", isPresented: isPresented) {
            if let onRetry {
                Button("Reintentar", action: onRetry)
                Button("Cancelar", role: .cancel) {}
            } else {
                Button("Aceptar", role: .cancel) {}
            }
        } message: {
            Text("No se pudo conectar con el servidor. Comprueba tu conexión e inténtalo de nuevo.")
        }
    }
}

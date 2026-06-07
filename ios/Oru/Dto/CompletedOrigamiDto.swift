import Foundation

/// Figura del catálogo completada por el usuario, para la galería de estadísticas
/// (`GET /origami/completed?year=`).
struct CompletedOrigamiDto: Decodable, Identifiable {
    let id: Int
    let name: String
    let illustration: String
    let completedAt: Date
}

import SwiftUI

struct SyntheticPalette: Hashable {
    var deep: Color
    var mid: Color
    var highlight: Color
    var accent: Color
}

struct PuzzleTheme: Hashable, Identifiable {
    var id: String
    /// Optional bundle video: `forest_loop.mp4` in target resources.
    var bundleVideoName: String?
    var synthetic: SyntheticPalette
    var ambientHint: String

    static let all: [PuzzleTheme] = [
        PuzzleTheme(
            id: "forest",
            bundleVideoName: "forest_loop",
            synthetic: SyntheticPalette(
                deep: Color(red: 0.05, green: 0.12, blue: 0.08),
                mid: Color(red: 0.12, green: 0.42, blue: 0.22),
                highlight: Color(red: 0.45, green: 0.82, blue: 0.38),
                accent: Color(red: 0.2, green: 0.9, blue: 0.55)
            ),
            ambientHint: "forest"
        ),
        PuzzleTheme(
            id: "ocean",
            bundleVideoName: "ocean_loop",
            synthetic: SyntheticPalette(
                deep: Color(red: 0.02, green: 0.08, blue: 0.18),
                mid: Color(red: 0.08, green: 0.28, blue: 0.55),
                highlight: Color(red: 0.35, green: 0.75, blue: 0.95),
                accent: Color(red: 0.25, green: 0.55, blue: 1.0)
            ),
            ambientHint: "ocean"
        ),
        PuzzleTheme(
            id: "galaxy",
            bundleVideoName: "galaxy_loop",
            synthetic: SyntheticPalette(
                deep: Color(red: 0.06, green: 0.02, blue: 0.12),
                mid: Color(red: 0.22, green: 0.08, blue: 0.42),
                highlight: Color(red: 0.72, green: 0.45, blue: 0.95),
                accent: Color(red: 0.55, green: 0.25, blue: 0.98)
            ),
            ambientHint: "galaxy"
        )
    ]
}

extension PuzzleTheme {
    func localizedNameKey() -> String {
        switch id {
        case "forest": return "theme_forest_name"
        case "ocean": return "theme_ocean_name"
        case "galaxy": return "theme_galaxy_name"
        default: return "theme_forest_name"
        }
    }

    func localizedDescriptionKey() -> String {
        switch id {
        case "forest": return "theme_forest_desc"
        case "ocean": return "theme_ocean_desc"
        case "galaxy": return "theme_galaxy_desc"
        default: return "theme_forest_desc"
        }
    }

    func pieceDescriptionKey(index: Int) -> String {
        "piece_\(id)_\(index)"
    }
}

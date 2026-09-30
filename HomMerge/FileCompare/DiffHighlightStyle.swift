import AppKit

/// Shared accent styling for the currently selected diff hunk.
enum DiffHighlightStyle {
    static var currentHunkAccent: NSColor { .controlAccentColor }

    static var currentHunkBarFill: NSColor {
        currentHunkAccent.withAlphaComponent(0.85)
    }

    static var currentHunkBarStroke: NSColor {
        currentHunkAccent
    }

    /// Pane row wash: accent-forward so it matches the location bar hue.
    static var currentHunkPaneFill: NSColor {
        currentHunkAccent.withAlphaComponent(0.28)
    }
}

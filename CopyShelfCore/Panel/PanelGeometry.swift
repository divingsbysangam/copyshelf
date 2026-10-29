import Foundation

public enum PanelGeometry {
    /// Center a panel inside a display's visible area, shrinking it if needed.
    public static func frame(requested: CGSize, visible: CGRect) -> CGRect {
        let width = max(0, min(requested.width, visible.width))
        let height = max(0, min(requested.height, visible.height))
        return CGRect(x: visible.midX - width / 2, y: visible.midY - height / 2, width: width, height: height)
    }
}

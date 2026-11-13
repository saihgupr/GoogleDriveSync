import SwiftUI
import AppKit

extension View {
    /// Shows the pointing hand cursor while the pointer is over the view,
    /// so custom-styled buttons read as clickable.
    func pointingHandCursor() -> some View {
        onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

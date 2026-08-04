import SwiftUI

struct LiquidGlassView<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { content }
}

import SwiftUI

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 6
    var color: Color = .blue

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4), value: progress)
        }
    }
}

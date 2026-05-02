import SwiftUI

struct AudioWaveformView: View {
    let level: Float

    private var clamped: CGFloat {
        CGFloat(min(max(level, 0), 1))
    }

    var body: some View {
        ZStack {
            outerRing
            middleRing
            innerCore
        }
        .frame(width: 240, height: 240)
    }

    private var outerRing: some View {
        let radius: CGFloat = 110 + clamped * 20
        return Circle()
            .stroke(Theme.primary.opacity(0.25), lineWidth: 2)
            .frame(width: radius * 2, height: radius * 2)
            .animation(.easeOut(duration: 0.18), value: clamped)
    }

    private var middleRing: some View {
        let radius: CGFloat = 88 + clamped * 18
        return Circle()
            .stroke(Theme.primary.opacity(0.45), lineWidth: 3)
            .frame(width: radius * 2, height: radius * 2)
            .animation(.easeOut(duration: 0.14), value: clamped)
    }

    private var innerCore: some View {
        let size: CGFloat = 110 + clamped * 28
        return Circle()
            .fill(
                RadialGradient(
                    colors: [Theme.primary, Theme.primaryDeep],
                    center: .center,
                    startRadius: 4,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "mic.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: Theme.primary.opacity(0.5), radius: 24)
            .animation(.easeOut(duration: 0.1), value: clamped)
    }
}

#Preview {
    ZStack {
        Theme.warmDark.ignoresSafeArea()
        AudioWaveformView(level: 0.6)
    }
}

import SwiftUI
import AVFoundation
import Speech
import UIKit

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var page = 0
    @State private var micStatus: PermissionStatus = .notDetermined
    @State private var speechStatus: PermissionStatus = .notDetermined

    var body: some View {
        ZStack {
            Theme.warmDark.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    PitchScreen().tag(0)
                    PrivacyScreen().tag(1)
                    PermissionsScreen(
                        micStatus: $micStatus,
                        speechStatus: $speechStatus
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: page)

                pageDots
                    .padding(.top, 8)

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: refreshPermissionStatuses)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(i == page ? Theme.primary : Color.white.opacity(0.2))
                    .frame(width: 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: page)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Button(action: primaryAction) {
                Text(primaryLabel)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(primaryEnabled ? Theme.primary : Color.white.opacity(0.15))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(!primaryEnabled)
            .animation(.easeInOut(duration: 0.2), value: primaryEnabled)

            if page < 2 {
                Button("Skip") { withAnimation { page = 2 } }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            } else if !primaryEnabled {
                Text("Allow both permissions to continue.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Color.clear.frame(height: 18)
            }
        }
    }

    private var primaryLabel: String {
        page == 2 ? "Start Practicing" : "Continue"
    }

    private var primaryEnabled: Bool {
        if page < 2 { return true }
        return micStatus == .granted && speechStatus == .granted
    }

    private func primaryAction() {
        if page < 2 {
            withAnimation { page += 1 }
        } else {
            hasCompletedOnboarding = true
        }
    }

    private func refreshPermissionStatuses() {
        micStatus = PermissionStatus(AVAudioApplication.shared.recordPermission)
        speechStatus = PermissionStatus(SFSpeechRecognizer.authorizationStatus())
    }
}

// MARK: - Screen 1: Pitch

private struct PitchScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            AmbientWaveform()
                .frame(height: 280)
            Spacer().frame(height: 40)
            VStack(alignment: .leading, spacing: 12) {
                Text("Think faster on your feet.")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Random prompts, a sixty-second clock, and instant feedback from an AI coach. Built for interviews, presentations, and the moments you can't rehearse.")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

private struct AmbientWaveform: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t: Double = context.date.timeIntervalSinceReferenceDate
            let wave1: Double = 0.25 * sin(t * 1.6)
            let wave2: Double = 0.15 * sin(t * 0.7)
            let level: CGFloat = CGFloat(0.35 + wave1 + wave2)
            let clamped: CGFloat = min(max(level, 0), 1)
            ZStack {
                Circle()
                    .stroke(Theme.primary.opacity(0.18), lineWidth: 2)
                    .frame(width: 220 + clamped * 36, height: 220 + clamped * 36)
                Circle()
                    .stroke(Theme.primary.opacity(0.38), lineWidth: 3)
                    .frame(width: 176 + clamped * 32, height: 176 + clamped * 32)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.primary, Theme.primaryDeep],
                            center: .center,
                            startRadius: 4,
                            endRadius: 110
                        )
                    )
                    .frame(width: 120 + clamped * 28, height: 120 + clamped * 28)
                    .overlay(
                        Image(systemName: "mic.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: Theme.primary.opacity(0.5), radius: 28)
            }
        }
    }
}

// MARK: - Screen 2: Privacy

private struct PrivacyScreen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .padding(.bottom, 32)
            Text("No accounts. No tracking. No audio leaves your device.")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
                .lineSpacing(2)
                .padding(.bottom, 20)
            Text("Verba runs the speech recognition on your phone. The only thing that touches our server is the text of what you said, briefly, to generate feedback. Then it's gone.")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.75))
                .lineSpacing(4)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
}

// MARK: - Screen 3: Permissions

private struct PermissionsScreen: View {
    @Binding var micStatus: PermissionStatus
    @Binding var speechStatus: PermissionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 24)
            Text("Two quick permissions.")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
            Text("Both work entirely on your phone — no audio leaves your device.")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(3)
                .padding(.top, 12)

            VStack(spacing: 12) {
                PermissionRow(
                    systemImage: "mic.fill",
                    title: "Microphone",
                    subtitle: "So Verba can hear you practice.",
                    status: micStatus,
                    action: requestMic
                )
                PermissionRow(
                    systemImage: "waveform",
                    title: "Speech Recognition",
                    subtitle: "So Verba can transcribe what you say.",
                    status: speechStatus,
                    action: requestSpeech
                )
            }
            .padding(.top, 32)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func requestMic() {
        if micStatus == .denied {
            openSettings()
            return
        }
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                micStatus = granted ? .granted : .denied
            }
        }
    }

    private func requestSpeech() {
        if speechStatus == .denied {
            openSettings()
            return
        }
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                speechStatus = PermissionStatus(status)
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct PermissionRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let status: PermissionStatus
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 40, height: 40)
                .background(Theme.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            statusBadge
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .granted:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                Text("Allowed")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.success)
        case .denied:
            Button(action: action) {
                Text("Open Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.improve)
            }
        case .notDetermined:
            Button(action: action) {
                Text("Continue")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Theme.primary)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Permission status

private enum PermissionStatus {
    case notDetermined, granted, denied

    init(_ recordPermission: AVAudioApplication.recordPermission) {
        switch recordPermission {
        case .granted: self = .granted
        case .denied: self = .denied
        case .undetermined: self = .notDetermined
        @unknown default: self = .notDetermined
        }
    }

    init(_ status: SFSpeechRecognizerAuthorizationStatus) {
        switch status {
        case .authorized: self = .granted
        case .denied, .restricted: self = .denied
        case .notDetermined: self = .notDetermined
        @unknown default: self = .notDetermined
        }
    }
}

#Preview {
    OnboardingView()
}

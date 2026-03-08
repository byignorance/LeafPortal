import SwiftUI

struct SleepGuardMenuBarExtraContent: View {
    @ObservedObject var manager: SleepGuardManager
    let openPortal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("WakeUp Leaf")
                    .font(.system(size: 13, weight: .bold))
                Text(manager.activeSessionSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if manager.mode == .duration, !manager.remainingText.isEmpty {
                HStack {
                    Text("남은 시간")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text(manager.remainingText)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
            }

            Divider()

            Button("WakeUp Leaf 열기", action: openPortal)
            Button("WakeUp Leaf 중지") {
                manager.stop()
            }
        }
        .frame(width: 240, alignment: .leading)
        .padding(.vertical, 6)
    }
}

struct SleepGuardMenuBarLabel: View {
    @ObservedObject var manager: SleepGuardManager
    @State private var rotation = 0.0

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "moon.stars.fill")
                .rotationEffect(.degrees(rotation))

            Text(compactLabel)
                .font(.system(size: 12, weight: .bold).monospacedDigit())
        }
        .onAppear {
            if manager.isKeepingAwake {
                startAnimation()
            } else {
                rotation = 0
            }
        }
        .onChange(of: manager.isKeepingAwake) { _, isActive in
            if isActive {
                startAnimation()
            } else {
                rotation = 0
            }
        }
    }

    private var compactLabel: String {
        if manager.mode == .duration, !manager.remainingText.isEmpty {
            return manager.remainingText
        }

        switch manager.mode {
        case .duration:
            return "ON"
        case .unlimited:
            return "24H"
        case .appExit:
            return "APP"
        }
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            rotation = 10
        }
    }
}

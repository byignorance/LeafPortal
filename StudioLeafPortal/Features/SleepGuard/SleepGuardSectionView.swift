import SwiftUI

struct SleepGuardSectionView: View {
    @ObservedObject var manager: SleepGuardManager

    @State private var appCandidates: [SleepGuardManager.AppCandidate] = []
    @State private var durationInputText = ""
    @State private var glowScale: CGFloat = 0.92
    @FocusState private var isDurationFieldFocused: Bool

    private let durationPresets = [10, 30, 60, 120]
    private let themeColor = Color(red: 0.10, green: 0.18, blue: 0.14)
    private let accentColor = Color(red: 0.35, green: 0.80, blue: 0.52)
    private let softBackground = Color(red: 0.96, green: 0.97, blue: 0.97)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            statusCard

            VStack(spacing: 24) {
                modeCard
                preferencesCard
            }
        }
        .onAppear {
            if manager.mode == .appExit {
                refreshAppCandidates()
            }
            startGlowAnimationIfNeeded()
        }
        .onChange(of: manager.isKeepingAwake) { _, isActive in
            if isActive {
                startGlowAnimationIfNeeded()
            } else {
                glowScale = 0.92
            }
        }
        .onChange(of: manager.mode) { _, nextMode in
            if nextMode == .appExit {
                refreshAppCandidates()
            }
        }
    }

    private var statusCard: some View {
        softCard {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(manager.isKeepingAwake ? 0.14 : 0.08))
                        .frame(width: 72, height: 72)
                        .scaleEffect(manager.isKeepingAwake ? glowScale : 1)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 54, height: 54)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)

                    Image(systemName: manager.isKeepingAwake ? "moon.stars.fill" : "moon.zzz.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(manager.isKeepingAwake ? themeColor : Color.black.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        sectionBadge(icon: "moon.stars.fill", title: "WakeUp Leaf")
                        statusPill(
                            title: manager.isKeepingAwake ? "활성" : "대기",
                            tint: manager.isKeepingAwake ? accentColor : Color.black.opacity(0.45)
                        )
                    }

                    Text(manager.statusText)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.86))
                        .padding(.top, 2)

                    if manager.isKeepingAwake {
                        Text(manager.detailText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if manager.isKeepingAwake {
                            Text(manager.mode == .duration ? manager.remainingText : manager.menuBarLabelText)
                                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                .foregroundStyle(themeColor)
                        } else {
                            Text("준비됨")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.72))
                        }
                    }

                    HStack(spacing: 8) {
                        primaryButton(
                            title: manager.isKeepingAwake ? "재설정" : "감시 시작",
                            icon: manager.isKeepingAwake ? "arrow.clockwise" : "play.fill"
                        ) {
                            _ = manager.start()
                        }

                        secondaryButton(
                            title: "중지",
                            icon: "stop.fill",
                            disabled: !manager.isKeepingAwake
                        ) {
                            manager.stop()
                        }
                    }
                }
            }
        }
    }

    private var modeCard: some View {
        softCard {
            VStack(alignment: .leading, spacing: 18) {
                cardHeader(icon: "switch.2", title: "WakeUp Leaf 방식")

                HStack(spacing: 10) {
                    modeButton(.duration, icon: "timer")
                    modeButton(.unlimited, icon: "infinity")
                    modeButton(.appExit, icon: "app.badge.checkmark")
                }

                Group {
                    switch manager.mode {
                    case .duration:
                        durationConfiguration
                    case .unlimited:
                        notePanel(
                            icon: "sparkles",
                            title: "무제한 유지",
                            detail: "최대 24시간 동안 메뉴바에 상태를 유지하며 절전 방지를 이어갑니다."
                        )
                    case .appExit:
                        appExitConfiguration
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: manager.mode)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var durationConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ForEach(durationPresets, id: \.self) { preset in
                    Button {
                        manager.durationMinutes = preset
                        durationInputText = ""
                    } label: {
                        Text("\(preset)분")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(manager.durationMinutes == preset ? Color.white : Color.black.opacity(0.72))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(manager.durationMinutes == preset ? themeColor : Color.white)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.black.opacity(manager.durationMinutes == preset ? 0 : 0.06), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .clickableCursor()
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "hourglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeColor.opacity(0.7))

                TextField(
                    "직접 입력",
                    text: Binding(
                        get: { durationInputText },
                        set: { value in
                            let digits = value.filter(\.isNumber)
                            durationInputText = digits
                            if let parsed = Int(digits), !digits.isEmpty {
                                manager.durationMinutes = min(max(1, parsed), 24 * 60)
                            }
                        }
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .focused($isDurationFieldFocused)
                .frame(width: 88, alignment: .leading)

                Text("분 유지")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.56))

                Spacer()

                Text(manager.currentModeSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.48))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(softBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isDurationFieldFocused ? themeColor.opacity(0.18) : Color.black.opacity(0.04), lineWidth: 1)
                    )
            )
        }
    }

    private var appExitConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeColor.opacity(0.7))

                Picker("대상 앱", selection: $manager.selectedAppBundleId) {
                    Text("대상 앱 선택").tag("")
                    ForEach(appCandidates) { app in
                        Text(app.name).tag(app.bundleId)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clickableCursor()

                iconButton(icon: "arrow.clockwise") {
                    refreshAppCandidates()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(softBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.04), lineWidth: 1)
                    )
            )

            Text(manager.currentModeSummary)
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))
        }
    }

    private var preferencesCard: some View {
        softCard {
            VStack(alignment: .leading, spacing: 18) {
                cardHeader(icon: "slider.horizontal.3", title: "기능 설정")

                toggleRow(
                    title: "알림 수신",
                    subtitle: "시작과 종료 상태를 macOS 알림으로 보냅니다.",
                    isOn: Binding(
                        get: { manager.isNotificationEnabled },
                        set: { manager.toggleNotification(enabled: $0) }
                    )
                )

                Divider()
                    .overlay(Color.black.opacity(0.06))

                soundPickerRow(
                    title: "시작 사운드",
                    subtitle: "절전 방지가 시작될 때 재생됩니다.",
                    options: SoundOption.wakeUpLeafStartOptions,
                    selection: Binding(
                        get: { manager.startSoundName },
                        set: { manager.setStartSound($0) }
                    ),
                    importAction: manager.importStartSound
                )

                soundPickerRow(
                    title: "종료 사운드",
                    subtitle: "절전 방지가 중지될 때 재생됩니다.",
                    options: SoundOption.wakeUpLeafStopOptions,
                    selection: Binding(
                        get: { manager.stopSoundName },
                        set: { manager.setStopSound($0) }
                    ),
                    importAction: manager.importStopSound
                )

                Divider()
                    .overlay(Color.black.opacity(0.06))

                notePanel(
                    icon: "menubar.rectangle",
                    title: "메뉴바 동작",
                    detail: manager.isKeepingAwake
                        ? "지금은 메뉴바에서 남은 시간 또는 상태를 확인하고 바로 중지할 수 있습니다."
                        : "시작 시에만 메뉴바에 나타나고, 중지되면 자동으로 사라집니다."
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func refreshAppCandidates() {
        appCandidates = manager.candidateApps()
        manager.refreshSelectedAppName()
    }

    private func startGlowAnimationIfNeeded() {
        guard manager.isKeepingAwake else {
            return
        }

        glowScale = 0.92
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
            glowScale = 1.08
        }
    }

    private func modeButton(_ mode: SleepGuardManager.Mode, icon: String) -> some View {
        Button {
            manager.mode = mode
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeColor.opacity(manager.mode == mode ? 0.12 : 0.07))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(themeColor.opacity(manager.mode == mode ? 0.9 : 0.7))
                        )
                    Spacer()
                    if manager.mode == mode {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(mode.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(manager.mode == mode ? themeColor.opacity(0.18) : Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(manager.mode == mode ? 0.06 : 0.03), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
        .clickableCursor()
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.48))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private func soundPickerRow(
        title: String,
        subtitle: String,
        options: [SoundOption],
        selection: Binding<String>,
        importAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.46))
                if let localURL = SoundOption.localFileURL(from: selection.wrappedValue) {
                    Text("선택 파일: \(localURL.lastPathComponent)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(themeColor.opacity(0.72))
                }
            }

            Spacer()

            Picker(title, selection: selection) {
                if SoundOption.localFileURL(from: selection.wrappedValue) != nil {
                    Text(SoundOption.title(for: selection.wrappedValue, options: options)).tag(selection.wrappedValue)
                }
                ForEach(options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
            .clickableCursor()

            secondaryButton(title: "파일 선택") {
                importAction()
            }

            secondaryButton(title: "미리듣기") {
                manager.previewSound(named: selection.wrappedValue)
            }
        }
    }

    private func cardHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(themeColor.opacity(0.08))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeColor.opacity(0.78))
                )

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.84))
        }
    }

    private func notePanel(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(themeColor.opacity(0.78))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.8))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(softBackground)
        )
    }

    private func statusPill(title: String, tint: Color) -> some View {
        PortalTagPill(title: title, tint: tint, background: Color.white)
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
    }

    private func sectionBadge(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(themeColor.opacity(0.8))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(themeColor.opacity(0.08))
        )
    }

    private func primaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        PortalCapsuleActionButton(
            title: title,
            icon: icon,
            filled: true,
            tint: themeColor,
            action: action
        )
    }

    private func secondaryButton(title: String, icon: String? = nil, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        PortalSecondaryButton(title: title, icon: icon, disabled: disabled, action: action)
    }

    private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        secondaryButton(title: title, icon: nil, disabled: false, action: action)
    }

    private func iconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.6))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .clickableCursor()
    }

    private func softCard<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        PortalCard(padding: 24, content: content)
    }
}

import SwiftUI

struct PortalMemberManagementSectionView: View {
    @ObservedObject var authManager: PortalAuthManager
    @ObservedObject var manager: PortalMemberDirectoryManager

    @State private var searchText = ""
    @State private var sortOption: PortalMemberDirectoryManager.SortOption = .recentSignIn
    @State private var editingMember: PortalMemberDirectoryManager.MemberEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !authManager.isSignedIn {
                signedOutCard
            } else if !authManager.isAdmin {
                deniedCard
            } else {
                summaryCard
                memberListCard
            }
        }
        .sheet(item: $editingMember) { member in
            PortalMemberEditorSheet(member: member, manager: manager)
        }
        .task(id: authManager.currentUser?.id) {
            guard authManager.isAdmin, manager.members.isEmpty else { return }
            await manager.loadMembers()
        }
    }

    private var signedOutCard: some View {
        PortalCard(padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text("회원 관리")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.84))
                Text("회원 관리는 Firebase 로그인 후, 관리자 계정에서만 볼 수 있습니다.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.black.opacity(0.54))
                PortalSecondaryButton(title: "로그인") {
                    Task {
                        await authManager.signIn()
                    }
                }
            }
        }
    }

    private var deniedCard: some View {
        PortalCard(padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text("관리자 전용")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.84))
                Text("회원 관리는 관리자 권한이 부여된 계정으로 로그인했을 때만 노출됩니다.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.black.opacity(0.54))
            }
        }
    }

    private var summaryCard: some View {
        PortalCard(padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("앱 가입자")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.84))
                        Text("가입 정보, 최근 로그인, 관리 상태를 확인하고 간단한 메모를 남길 수 있습니다.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.black.opacity(0.54))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        PortalTagPill(
                            title: "\(filteredMembers.count)명 표시",
                            tint: Color(red: 0.10, green: 0.18, blue: 0.14),
                            background: Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.08)
                        )

                        PortalSecondaryButton(title: manager.isLoading ? "불러오는 중..." : "새로고침") {
                            Task {
                                await manager.loadMembers()
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    countPill(title: "활성", count: stateCount(.active), tint: Color(red: 0.17, green: 0.55, blue: 0.32))
                    countPill(title: "보류", count: stateCount(.paused), tint: Color(red: 0.75, green: 0.56, blue: 0.14))
                    countPill(title: "비활성", count: stateCount(.disabled), tint: Color(red: 0.78, green: 0.24, blue: 0.19))
                }

                HStack(alignment: .center, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.black.opacity(0.36))
                        TextField("이름 또는 이메일 검색", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )

                    Picker("정렬", selection: $sortOption) {
                        ForEach(PortalMemberDirectoryManager.SortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }

                if let errorMessage = manager.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.78, green: 0.24, blue: 0.19))
                }
            }
        }
    }

    private var memberListCard: some View {
        PortalCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if filteredMembers.isEmpty && !manager.isLoading {
                    Text(searchText.isEmpty ? "가입 정보가 아직 없습니다." : "검색 결과가 없습니다.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                } else {
                    ForEach(Array(filteredMembers.enumerated()), id: \.element.id) { index, member in
                        memberRow(member)

                        if index != filteredMembers.count - 1 {
                            Divider()
                                .overlay(Color.black.opacity(0.05))
                                .padding(.leading, 24)
                        }
                    }
                }
            }
        }
    }

    private var filteredMembers: [PortalMemberDirectoryManager.MemberEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = manager.members.filter { member in
            guard !query.isEmpty else { return true }
            return member.displayName.lowercased().contains(query)
                || member.email.lowercased().contains(query)
        }

        switch sortOption {
        case .recentSignIn:
            return base.sorted { lhs, rhs in
                (lhs.lastSignInAt ?? lhs.updatedAt ?? .distantPast) > (rhs.lastSignInAt ?? rhs.updatedAt ?? .distantPast)
            }
        case .joinedNewest:
            return base.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .name:
            return base.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .state:
            return base.sorted {
                if $0.memberState == $1.memberState {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return stateRank($0.memberState) < stateRank($1.memberState)
            }
        }
    }

    private func memberRow(_ member: PortalMemberDirectoryManager.MemberEntry) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(member.isAdmin ? Color(red: 0.10, green: 0.18, blue: 0.14) : Color.black.opacity(0.12))
                .frame(width: 38, height: 38)
                .overlay(
                    Text(String(member.displayName.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(member.isAdmin ? .white : Color.black.opacity(0.62))
                )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(member.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.84))

                    if member.isAdmin {
                        PortalTagPill(
                            title: "관리자",
                            tint: Color(red: 0.10, green: 0.18, blue: 0.14),
                            background: Color(red: 0.10, green: 0.18, blue: 0.14).opacity(0.08)
                        )
                    }

                    statePill(member.memberState)
                }

                Text(member.email)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.54))

                HStack(spacing: 12) {
                    memberMeta(title: "UID", value: String(member.id.prefix(8)))
                    memberMeta(title: "가입", value: formatted(member.createdAt))
                    memberMeta(title: "최근 로그인", value: formatted(member.lastSignInAt ?? member.updatedAt))
                }

                if !member.adminNote.isEmpty {
                    Text(member.adminNote)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.58))
                        .padding(.top, 2)
                }
            }

            Spacer()

            PortalSecondaryButton(title: "관리") {
                editingMember = member
            }
        }
        .padding(24)
    }

    private func countPill(title: String, count: Int, tint: Color) -> some View {
        PortalTagPill(title: "\(title) \(count)", tint: tint, background: tint.opacity(0.10))
    }

    private func statePill(_ state: PortalMemberDirectoryManager.MemberState) -> some View {
        PortalTagPill(
            title: state.title,
            tint: stateTint(state),
            background: stateTint(state).opacity(0.10)
        )
    }

    private func stateTint(_ state: PortalMemberDirectoryManager.MemberState) -> Color {
        switch state {
        case .active:
            return Color(red: 0.17, green: 0.55, blue: 0.32)
        case .paused:
            return Color(red: 0.75, green: 0.56, blue: 0.14)
        case .disabled:
            return Color(red: 0.78, green: 0.24, blue: 0.19)
        }
    }

    private func stateRank(_ state: PortalMemberDirectoryManager.MemberState) -> Int {
        switch state {
        case .active:
            return 0
        case .paused:
            return 1
        case .disabled:
            return 2
        }
    }

    private func stateCount(_ state: PortalMemberDirectoryManager.MemberState) -> Int {
        manager.members.filter { $0.memberState == state }.count
    }

    private func memberMeta(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.36))
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.74))
        }
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "없음" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct PortalMemberEditorSheet: View {
    let member: PortalMemberDirectoryManager.MemberEntry
    @ObservedObject var manager: PortalMemberDirectoryManager

    @Environment(\.dismiss) private var dismiss

    @State private var memberState: PortalMemberDirectoryManager.MemberState
    @State private var adminNote: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(member: PortalMemberDirectoryManager.MemberEntry, manager: PortalMemberDirectoryManager) {
        self.member = member
        self.manager = manager
        _memberState = State(initialValue: member.memberState)
        _adminNote = State(initialValue: member.adminNote)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("회원 관리")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.84))

            VStack(alignment: .leading, spacing: 4) {
                Text(member.displayName)
                    .font(.system(size: 15, weight: .semibold))
                Text(member.email)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("상태")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.46))
                Picker("상태", selection: $memberState) {
                    ForEach(PortalMemberDirectoryManager.MemberState.allCases) { state in
                        Text(state.title).tag(state)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("관리 메모")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.46))
                TextEditor(text: $adminNote)
                    .font(.system(size: 13, weight: .medium))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.78, green: 0.24, blue: 0.19))
            }

            HStack {
                Spacer()

                PortalSecondaryButton(title: "닫기") {
                    dismiss()
                }

                PortalPrimaryButton(title: isSaving ? "저장 중..." : "저장") {
                    Task {
                        await save()
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func save() async {
        guard !isSaving else { return }

        isSaving = true
        errorMessage = nil

        do {
            try await manager.updateMemberAdminMetadata(
                memberID: member.id,
                state: memberState,
                adminNote: adminNote
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

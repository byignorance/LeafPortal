import AppKit
import LucideIcons
import SwiftUI

struct PortalIconManagementSection: View {
    @ObservedObject var viewModel: PortalViewModel
    @State private var activeSymbolSearchRole: PortalIconRole?
    @State private var symbolSearchText = ""
    @State private var activeLucideSearchRole: PortalIconRole?
    @State private var lucideSearchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("아이콘 관리")
                        .font(.system(size: 28, weight: .black))
                    Text("추천 드롭다운, 전체 SF Symbols 검색, Lucide 선택, 커스텀 아이콘 업로드를 한 곳에서 관리합니다.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                actionButton(title: "기본값 복원", filled: false, disabled: false) {
                    viewModel.resetIconSelections()
                }
            }

            sectionCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text("주요 아이콘 구성")
                        .font(.system(size: 22, weight: .bold))

                    ForEach([PortalIconRole.Category.portal, .tool], id: \.title) { category in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(category.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.55))

                            let roles = PortalIconRole.allCases.filter { $0.category == category }
                            ForEach(Array(roles.enumerated()), id: \.element.id) { index, role in
                                iconSelectionRow(role: role)

                                if index < roles.count - 1 {
                                    Divider()
                                }
                            }
                        }

                        if category != .tool {
                            Divider()
                        }
                    }
                }
            }

            sectionCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("커스텀 아이콘")
                            .font(.system(size: 22, weight: .bold))
                        Spacer()
                        actionButton(title: "아이콘 가져오기", filled: true, disabled: false) {
                            viewModel.importCustomIcons()
                        }
                    }

                    Text("PNG, JPG, PDF 파일을 추가해서 주요 아이콘으로 직접 배정할 수 있습니다.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))

                    if let iconManagementMessage = viewModel.iconManagementMessage {
                        InlineAlert(text: iconManagementMessage)
                    }

                    if viewModel.customIconAssets.isEmpty {
                        Text("아직 추가된 커스텀 아이콘이 없습니다.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                            ForEach(viewModel.customIconAssets) { asset in
                                customIconCard(asset: asset)
                            }
                        }
                    }
                }
            }

            sectionCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("운영 기준")
                        .font(.system(size: 22, weight: .bold))
                    Text("추천 드롭다운은 빠른 선택용이고, 검색을 시작하면 SF Symbols와 Lucide 전체 카탈로그를 대상으로 찾습니다. 커스텀 아이콘은 업로드 후 각 역할에 바로 배정할 수 있습니다.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))
                    HStack(spacing: 14) {
                        serviceTile(title: "추천 선택", subtitle: "빠른 적용", icon: "checkmark.seal")
                        serviceTile(title: "전체 검색", subtitle: "SF Symbols", icon: "magnifyingglass")
                        serviceTile(title: "Lucide", subtitle: "라이브러리 선택", icon: "sparkles")
                        serviceTile(title: "커스텀 업로드", subtitle: "PDF / PNG / JPG", icon: "square.and.arrow.down")
                    }
                }
            }
        }
        .sheet(item: $activeSymbolSearchRole) { role in
            symbolSearchSheet(for: role)
        }
        .sheet(item: $activeLucideSearchRole) { role in
            lucideSearchSheet(for: role)
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        PortalCard(padding: 24, content: content)
    }

    private func iconSelectionRow(role: PortalIconRole) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.94, green: 0.96, blue: 0.98))
                    .frame(width: 60, height: 60)
                    .overlay(
                        roleIcon(role: role, size: 24, tint: Color(red: 0.16, green: 0.41, blue: 0.24))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(role.title)
                            .font(.system(size: 16, weight: .semibold))
                        Text(iconSourceLabel(for: role))
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Capsule())
                    }

                    Text(role.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.34, green: 0.41, blue: 0.53))
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Picker("추천 아이콘", selection: Binding(
                    get: {
                        let current = viewModel.symbol(for: role)
                        return role.options.contains(where: { $0.symbol == current })
                            ? current
                            : (role.options.first?.symbol ?? "leaf")
                    },
                    set: { newValue in
                        let fallback = role.options.first?.symbol ?? "leaf"
                        let resolved = role.options.contains(where: { $0.symbol == newValue }) ? newValue : fallback
                        viewModel.updateSymbol(resolved, for: role)
                    }
                )) {
                    ForEach(role.options) { option in
                        Label(option.title, systemImage: option.symbol)
                            .tag(option.symbol)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)
                .clickableCursor()

                secondaryButton(title: "전체 검색") {
                    symbolSearchText = viewModel.symbol(for: role)
                    activeSymbolSearchRole = role
                }

                secondaryButton(title: "Lucide 검색") {
                    switch viewModel.selection(for: role) {
                    case .lucide(let lucideID):
                        lucideSearchText = lucideID
                    default:
                        lucideSearchText = role.lucideOptions.first ?? ""
                    }
                    activeLucideSearchRole = role
                }

                if !viewModel.customIconAssets.isEmpty {
                    Menu {
                        ForEach(viewModel.customIconAssets) { asset in
                            Button(asset.name) {
                                viewModel.updateSelection(.custom(asset.id), for: role)
                            }
                        }
                    } label: {
                        secondaryButtonLabel(title: "커스텀 선택")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .clickableCursor()
                }

                secondaryButton(title: "기본값") {
                    viewModel.setDefaultIcon(for: role)
                }
            }
        }
    }

    private func roleIcon(role: PortalIconRole, size: CGFloat, tint: Color) -> some View {
        Group {
            switch viewModel.selection(for: role) {
            case .custom:
                if let asset = viewModel.customIcon(for: role),
                   let image = NSImage(contentsOf: asset.fileURL) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: role.defaultSymbol)
                }
            case .lucide(let lucideID):
                if let image = lucideImage(named: lucideID) {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: role.defaultSymbol)
                }
            case .system:
                Image(systemName: viewModel.symbol(for: role))
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(tint)
    }

    private func iconSourceLabel(for role: PortalIconRole) -> String {
        switch viewModel.selection(for: role) {
        case .system(let symbol):
            return role.options.contains(where: { $0.symbol == symbol }) ? "추천" : "검색"
        case .custom:
            return "커스텀"
        case .lucide:
            return "Lucide"
        }
    }

    private func lucideImage(named lucideID: String) -> NSImage? {
        guard let image = NSImage.image(lucideId: lucideID)?.copy() as? NSImage else { return nil }
        image.isTemplate = true
        return image
    }

    private func customIconCard(asset: CustomIconAsset) -> some View {
        PortalCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.95, green: 0.96, blue: 0.98))
                    .frame(height: 96)
                    .overlay(
                        Group {
                            if let image = NSImage(contentsOf: asset.fileURL) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 42, height: 42)
                            } else {
                                Image(systemName: "questionmark.square.dashed")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.35))
                            }
                        }
                    )

                Text(asset.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(asset.fileURL.lastPathComponent)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                secondaryButton(title: "삭제") {
                    viewModel.removeCustomIcon(asset)
                }
            }
        }
    }

    private func symbolSearchSheet(for role: PortalIconRole) -> some View {
        let filtered = PortalSymbolCatalog.filteredSymbols(matching: symbolSearchText)
        let directInput = symbolSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return PortalSearchSheetScaffold(
            title: "\(role.title) 아이콘 검색",
            subtitle: "기본 상태에서는 추천 목록만 보이고, 검색을 시작하면 전체 SF Symbols 카탈로그에서 찾거나 심볼 이름을 직접 입력해 적용할 수 있습니다.",
            onClose: {
                activeSymbolSearchRole = nil
            }
        ) {
            TextField("심볼 이름 검색 또는 직접 입력", text: $symbolSearchText)
                .textFieldStyle(.roundedBorder)

            if !directInput.isEmpty {
                secondaryButton(title: "\"\(directInput)\" 직접 적용") {
                    viewModel.updateSymbol(directInput, for: role)
                    activeSymbolSearchRole = nil
                }
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(filtered, id: \.self) { symbol in
                        Button {
                            viewModel.updateSymbol(symbol, for: role)
                            activeSymbolSearchRole = nil
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: symbol)
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(Color(red: 0.16, green: 0.41, blue: 0.24))
                                    .frame(height: 32)
                                Text(symbol)
                                    .font(.system(size: 11, weight: .medium))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Color.black.opacity(0.78))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.97, green: 0.98, blue: 0.99))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                    )
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .clickableCursor()
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .onAppear {
            switch viewModel.selection(for: role) {
            case .system(let symbol):
                symbolSearchText = symbol
            case .custom, .lucide:
                symbolSearchText = ""
            }
        }
    }

    private func lucideSearchSheet(for role: PortalIconRole) -> some View {
        let filtered = PortalLucideCatalog.filteredIcons(matching: lucideSearchText)
        let directInput = lucideSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return PortalSearchSheetScaffold(
            title: "\(role.title) Lucide 검색",
            subtitle: "기본 상태에서는 추천 Lucide만 보이고, 검색을 시작하면 전체 Lucide 카탈로그에서 찾거나 아이콘 이름을 직접 입력해 바로 적용할 수 있습니다.",
            onClose: {
                activeLucideSearchRole = nil
            }
        ) {
            if !role.lucideOptions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("추천 Lucide")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.75))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(role.lucideOptions, id: \.self) { lucideID in
                                Button {
                                    viewModel.updateLucide(lucideID, for: role)
                                    activeLucideSearchRole = nil
                                } label: {
                                    HStack(spacing: 8) {
                                        if let image = lucideImage(named: lucideID) {
                                            Image(nsImage: image)
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 18, height: 18)
                                        }
                                        Text(lucideID)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(Color.black.opacity(0.8))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .clickableCursor()
                            }
                        }
                    }
                }
            }

            TextField("Lucide 아이콘 이름 검색 또는 직접 입력", text: $lucideSearchText)
                .textFieldStyle(.roundedBorder)

            if !directInput.isEmpty {
                secondaryButton(title: "\"\(directInput)\" 직접 적용") {
                    viewModel.updateLucide(directInput, for: role)
                    activeLucideSearchRole = nil
                }
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(filtered, id: \.self) { lucideID in
                        Button {
                            viewModel.updateLucide(lucideID, for: role)
                            activeLucideSearchRole = nil
                        } label: {
                            VStack(spacing: 10) {
                                Group {
                                    if let image = lucideImage(named: lucideID) {
                                        Image(nsImage: image)
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                    } else {
                                        Image(systemName: "questionmark.square.dashed")
                                            .font(.system(size: 22, weight: .medium))
                                    }
                                }
                                .foregroundStyle(Color(red: 0.16, green: 0.41, blue: 0.24))
                                .frame(width: 30, height: 30)

                                Text(lucideID)
                                    .font(.system(size: 11, weight: .medium))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Color.black.opacity(0.78))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.97, green: 0.98, blue: 0.99))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                    )
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .clickableCursor()
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .onAppear {
            switch viewModel.selection(for: role) {
            case .lucide(let lucideID):
                lucideSearchText = lucideID
            default:
                lucideSearchText = role.lucideOptions.first ?? ""
            }
        }
    }

    private func serviceTile(title: String, subtitle: String, icon: String) -> some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.95, green: 0.96, blue: 0.98))
                .frame(height: 120)
                .overlay(
                    VStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color(red: 0.16, green: 0.41, blue: 0.24))
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(title: String, filled: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Group {
            if filled {
                PortalCapsuleActionButton(
                    title: title,
                    filled: true,
                    disabled: disabled,
                    tint: Color(red: 0.10, green: 0.18, blue: 0.14),
                    action: action
                )
            } else {
                PortalSecondaryButton(title: title, disabled: disabled, action: action)
            }
        }
    }

    private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        PortalSecondaryButton(title: title, action: action)
    }

    private func secondaryButtonLabel(title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.76))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}

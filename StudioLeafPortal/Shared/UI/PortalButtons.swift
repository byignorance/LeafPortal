import SwiftUI

struct PortalPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var disabled = false
    var tint = Color(red: 0.10, green: 0.18, blue: 0.14)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                }
                Text(title)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(disabled ? Color.white.opacity(0.52) : Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(disabled ? tint.opacity(0.28) : tint)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .clickableCursor(enabled: !disabled)
    }
}

struct PortalSecondaryButton: View {
    let title: String
    var icon: String?
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                }
                Text(title)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(disabled ? Color.black.opacity(0.34) : Color.black.opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .clickableCursor(enabled: !disabled)
    }
}

struct PortalCapsuleActionButton: View {
    let title: String
    var icon: String? = nil
    var filled = false
    var destructive = false
    var disabled = false
    var tint = Color(red: 0.10, green: 0.18, blue: 0.14)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(backgroundColor)
                    .overlay(
                        Capsule()
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .clickableCursor(enabled: !disabled)
    }

    private var foregroundColor: Color {
        if destructive {
            return .red
        }
        if filled {
            return disabled ? Color.black.opacity(0.25) : .white
        }
        return disabled ? Color.black.opacity(0.34) : Color.black.opacity(0.76)
    }

    private var backgroundColor: Color {
        if destructive {
            return Color.red.opacity(0.08)
        }
        if filled {
            return disabled ? Color.clear : tint
        }
        return .clear
    }

    private var borderColor: Color {
        if filled {
            return disabled ? Color.black.opacity(0.12) : .clear
        }
        return Color.black.opacity(0.08)
    }

    private var borderWidth: CGFloat {
        if filled {
            return disabled ? 1 : 0
        }
        return 1
    }
}

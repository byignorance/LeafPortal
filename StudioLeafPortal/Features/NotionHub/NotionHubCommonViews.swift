import SwiftUI

struct NotionAvatarView: View {
    let member: NotionPersonChip
    let size: CGFloat

    init(member: NotionPersonChip, size: CGFloat = 24) {
        self.member = member
        self.size = size
    }

    var body: some View {
        Group {
            if let photoURL = member.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        initialsFallback
                    @unknown default:
                        initialsFallback
                    }
                }
            } else {
                initialsFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }

    private var initialsFallback: some View {
        ZStack {
            Circle()
                .fill(hashColor(member.name))
            Text(member.initials)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func hashColor(_ name: String) -> Color {
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint
        ]
        let index = abs(name.hashValue) % colors.count
        return colors[index].opacity(0.8)
    }
}

extension View {
    func notionCardStyle(isSelected: Bool, themeColor: Color) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isSelected ? themeColor.opacity(0.06) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(isSelected ? themeColor.opacity(0.25) : Color.black.opacity(0.04), lineWidth: 1.2)
                    )
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.04 : 0.02), radius: 8, y: 2)
    }
}

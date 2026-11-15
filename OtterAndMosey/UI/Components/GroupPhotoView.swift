import LostIslandsCore
import SwiftUI

// The group photo from the finale: everyone together on the beach. Once every crystal fragment
// is home it can be looked at again from the map, the trophy cabinet and Treasures.
// Mirrors web/src/ui/photo.ts.

enum GroupPhoto {
    /// The words under the photo. It is a photo for the player, who is not in the picture.
    static func caption(for name: String) -> String { "A special photo for \(name)" }

    static func isUnlocked(_ profile: Profile?, catalog: Catalog) -> Bool {
        guard let profile else { return false }
        return profile.crystals.count == catalog.islands.count
    }
}

/// A button with a little copy of the photo on it.
struct GroupPhotoButton: View {
    var size: CGFloat
    var showsTitle = true
    var action: () -> Void

    var body: some View {
        Button(action: tapped(action)) {
            HStack(spacing: size * 0.32) {
                Image("bg_ending").resizable().aspectRatio(1.5, contentMode: .fill)
                    .frame(width: size * 1.6, height: size * 1.6 / 1.5).clipped()
                    .padding(2).padding(.bottom, 2).background(.white)
                    .rotationEffect(.degrees(-4))
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .padding(.vertical, -size * 0.2)
                if showsTitle { Text("Photo") }
            }
        }
        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: size))
        .accessibilityLabel("Group photo")
    }
}

/// The photo, large, over whatever screen opened it.
struct GroupPhotoViewer: View {
    @Environment(AppModel.self) private var model
    var onClose: () -> Void
    @State private var shown = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            let width = min(geometry.size.width * 0.74, geometry.size.height * (compact ? 0.9 : 0.95))
            ZStack {
                Color(red: 0.03, green: 0.1, blue: 0.12).opacity(0.6).ignoresSafeArea()
                    .onTapGesture { onClose() }
                VStack(spacing: compact ? 8 : 16) {
                    VStack(spacing: 0) {
                        Image("bg_ending").resizable().aspectRatio(1.5, contentMode: .fill)
                            .frame(width: width, height: width / 1.5).clipped()
                            .accessibilityLabel("Otter, Mosey and all six guardians celebrating on the beach")
                        Text(GroupPhoto.caption(for: model.profile?.nickname ?? "you"))
                            .font(.custom("Bradley Hand", size: compact ? 17 : 28).weight(.bold))
                            .foregroundStyle(Palette.ink)
                            .padding(.vertical, compact ? 6 : 12)
                    }
                    .padding([.top, .horizontal], compact ? 8 : 12)
                    .background(.white)
                    .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
                    .rotationEffect(.degrees(shown ? -2 : 10))
                    .offset(y: shown ? 0 : -geometry.size.height * 0.3)
                    .opacity(shown ? 1 : 0)
                    HStack(spacing: 14) {
                        RoundButton(symbol: "xmark", label: "Close") { onClose() }
                        Button(action: tapped {
                            onClose()
                            model.route = .ending
                        }) { IconLabel("Watch the ending", emoji: "🌈", size: compact ? 16 : 22) }
                            .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 16 : 22))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(model.settings.reducedMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.6, bounce: 0.3)) { shown = true }
        }
    }
}

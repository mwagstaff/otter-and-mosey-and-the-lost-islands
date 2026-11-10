import SwiftUI

@main
struct OtterAndMoseyApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                // Progress is flushed to disk whenever the app leaves the foreground.
                model.persistNow()
                AudioManager.shared.pauseForBackground()
                Narrator.shared.stop()
            case .active:
                AudioManager.shared.resumeFromBackground()
            @unknown default:
                break
            }
        }
    }
}

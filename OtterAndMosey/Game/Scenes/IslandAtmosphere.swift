import SpriteKit
import SwiftUI

enum IslandAtmosphere {
    static func shader(for art: String, strength: Float = 1) -> SKShader? {
        let paintings = ["bg_woods", "bg_bay", "bg_dragon", "bg_cloud", "bg_candy",
                         "bg_star", "bg_hollow", "bg_meadow", "bg_map"]
        guard let index = paintings.firstIndex(of: art) else { return nil }
        let shader = SKShader(fileNamed: "IslandAtmosphere.fsh")
        shader.uniforms = [SKUniform(name: "u_theme", float: Float(index)),
                           SKUniform(name: "u_strength", float: strength)]
        return shader
    }
}

struct IslandScenery: View {
    let art: String
    let calmerMotion: Bool
    @Environment(\.accessibilityReduceMotion) private var reduced
    @Environment(\.scenePhase) private var phase

    var body: some View {
        GeometryReader { geometry in
            if reduced || calmerMotion {
                Image(art).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } else {
                IslandCanvas(art: art, paused: phase != .active).id(art)
            }
        }
        .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct IslandCanvas: UIViewRepresentable {
    let art: String
    let paused: Bool
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.preferredFramesPerSecond = 24
        let sprite = SKSpriteNode(imageNamed: art)
        sprite.shader = IslandAtmosphere.shader(for: art)
        let scene = SKScene(size: sprite.size)
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scene.scaleMode = .aspectFill
        scene.addChild(sprite)
        view.presentScene(scene)
        return view
    }
    func updateUIView(_ view: SKView, context: Context) { view.isPaused = paused }
    static func dismantleUIView(_ view: SKView, coordinator: ()) { view.presentScene(nil) }
}

import SpriteKit
import SwiftUI

struct RainbowIslandBackdrop: View {
    let saturation: Double
    let calmerMotion: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase

    static func shader(saturation: Float) -> SKShader {
        let shader = SKShader(fileNamed: "RainbowIslandWater.fsh")
        shader.uniforms = [SKUniform(name: "u_saturation", float: saturation)]
        return shader
    }

    var body: some View {
        if !calmerMotion && !reduceMotion {
            IslandPainting(saturation: Float(saturation), paused: phase != .active)
        } else {
            GeometryReader { geometry in
                Image("bg_title").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .saturation(saturation)
            }
        }
    }
}

// SpriteKit owns the animation clock so scenery updates don't redraw the island controls.
private struct IslandPainting: UIViewRepresentable {
    let saturation: Float
    let paused: Bool

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.preferredFramesPerSecond = 30
        let scene = WildlifePaintingScene(size: CGSize(width: 900, height: 600))
        scene.scaleMode = .aspectFill
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        let painting = SKSpriteNode(imageNamed: "bg_title")
        painting.size = scene.size
        painting.shader = RainbowIslandBackdrop.shader(saturation: saturation)
        painting.name = "painting"
        scene.addChild(painting)
        let wildlife = IslandWildlife()
        wildlife.zPosition = 1
        painting.addChild(wildlife)
        wildlife.fit(to: painting)
        scene.wildlife = wildlife
        wildlife.start()
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        view.isPaused = paused
        let painting = view.scene?.childNode(withName: "painting") as? SKSpriteNode
        painting?.shader?.uniformNamed("u_saturation")?.floatValue = saturation
    }

    static func dismantleUIView(_ view: SKView, coordinator: ()) {
        view.isPaused = true
        view.presentScene(nil)
    }
}

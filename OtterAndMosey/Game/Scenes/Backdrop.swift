import SpriteKit
import UIKit

/// The layered scenery behind a level: a painted far layer, a foreground strip and drifting
/// particles. Each layer has a grey twin on top whose opacity shows how much colour the
/// island has lost, so restoring the world is a simple, cheap cross-fade.
final class Backdrop: SKNode {
    private struct Tile {
        let node: SKNode
        let grey: SKSpriteNode
    }

    private let theme: IslandTheme
    private let scrolling: Bool
    private var farTiles: [Tile] = []
    private var nearTiles: [Tile] = []
    private var farWidth: CGFloat = 1
    private var nearWidth: CGFloat = 1
    private var farOffset: CGFloat = 0
    private var nearOffset: CGFloat = 0
    private var ambient: SKEmitterNode?
    private var sceneSize = CGSize.zero
    private var groundY: CGFloat = 0
    private(set) var restoration: CGFloat = 0
    /// Height of the foreground strip, so scenes can stand characters on it.
    private(set) var foregroundHeight: CGFloat = 0
    var showsForeground = true { didSet { if showsForeground != oldValue { sceneSize = .zero } } }

    init(theme: IslandTheme, scrolling: Bool) {
        self.theme = theme
        self.scrolling = scrolling
        super.init()
        zPosition = -100
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func makeTile(_ name: String, size: CGSize, anchor: CGPoint, mirrored: Bool) -> Tile {
        let node = SKNode()
        let colour = SKSpriteNode(texture: Art.texture(name), size: size)
        let grey = SKSpriteNode(texture: Art.greyTexture(name), size: size)
        colour.anchorPoint = anchor
        grey.anchorPoint = anchor
        grey.zPosition = 0.5
        grey.alpha = 1 - restoration
        node.addChild(colour)
        node.addChild(grey)
        node.xScale = mirrored ? -1 : 1
        addChild(node)
        return Tile(node: node, grey: grey)
    }

    /// Rebuilds the layers for a scene size. `groundY` is where the foreground strip sits.
    func resize(to size: CGSize, groundY: CGFloat) {
        guard size.width > 10, size != sceneSize || groundY != self.groundY else { return }
        sceneSize = size
        self.groundY = groundY
        (farTiles + nearTiles).forEach { $0.node.removeFromParent() }
        farTiles = []
        nearTiles = []

        let farTexture = Art.texture(theme.background).size()
        let scale = scrolling ? size.height / farTexture.height : max(size.width / farTexture.width, size.height / farTexture.height)
        let farSize = CGSize(width: farTexture.width * scale, height: farTexture.height * scale)
        farWidth = farSize.width - 1
        let farCount = scrolling ? evenCount(covering: size.width, tile: farWidth) : 1
        for index in 0..<farCount {
            let tile = makeTile(theme.background, size: farSize, anchor: CGPoint(x: 0.5, y: 0.5), mirrored: index % 2 == 1)
            tile.node.zPosition = 0
            farTiles.append(tile)
        }

        if showsForeground {
            let nearTexture = Art.texture(theme.foreground).size()
            foregroundHeight = min(size.height * 0.2, 130)
            let nearSize = CGSize(width: nearTexture.width * foregroundHeight / nearTexture.height, height: foregroundHeight)
            nearWidth = nearSize.width - 1
            for index in 0..<evenCount(covering: size.width, tile: nearWidth) {
                let tile = makeTile(theme.foreground, size: nearSize, anchor: CGPoint(x: 0.5, y: 0), mirrored: index % 2 == 1)
                tile.node.zPosition = 30
                nearTiles.append(tile)
            }
        } else {
            foregroundHeight = 0
        }

        ambient?.removeFromParent()
        let emitter = Effects.ambient(theme.ambient, size: size)
        addChild(emitter)
        ambient = emitter
        applyRestoration()
        place()
    }

    private func evenCount(covering width: CGFloat, tile: CGFloat) -> Int {
        let needed = Int(ceil((width + 2 * tile) / tile))
        return needed + needed % 2
    }

    private func place() {
        if scrolling {
            for (index, tile) in farTiles.enumerated() {
                tile.node.position = CGPoint(x: CGFloat(index) * farWidth - farOffset + farWidth / 2, y: sceneSize.height / 2)
            }
        } else {
            farTiles.first?.node.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        }
        let start = scrolling ? -nearOffset : -(CGFloat(nearTiles.count) * nearWidth - sceneSize.width) / 2
        for (index, tile) in nearTiles.enumerated() {
            tile.node.position = CGPoint(x: start + CGFloat(index) * nearWidth + nearWidth / 2, y: groundY)
        }
    }

    /// Moves the world left by `distance` points; the far layer follows more slowly.
    func scroll(by distance: CGFloat) {
        guard scrolling else { return }
        farOffset = (farOffset + distance * 0.35).truncatingRemainder(dividingBy: farWidth * 2)
        nearOffset = (nearOffset + distance).truncatingRemainder(dividingBy: nearWidth * 2)
        place()
    }

    func setRestoration(_ value: CGFloat, duration: TimeInterval = 0.9) {
        restoration = min(max(value, 0), 1)
        for tile in farTiles + nearTiles {
            tile.grey.removeAllActions()
            tile.grey.run(.fadeAlpha(to: 1 - restoration, duration: duration))
        }
        ambient?.particleBirthRate = 0.6 + 9 * restoration
    }

    private func applyRestoration() {
        (farTiles + nearTiles).forEach { $0.grey.alpha = 1 - restoration }
        ambient?.particleBirthRate = 0.6 + 9 * restoration
    }
}

import type { GameScene } from "../game/gameScene";
// Read-only diagnostics, included only in the dedicated playtest build.
export function observe(scene: GameScene): void {
  const s = scene as any;
  (window as any).__playtest = () => {
    const point = (node: any) => node && !node.destroyed && node.parent && node.visible ? node.getGlobalPosition() : undefined;
    return {
      question: s.current, completed: scene.bridge.completed, total: scene.bridge.total,
      result: scene.bridge.result, caption: scene.bridge.caption,
      targets: (s.tiles ?? s.gates ?? s.orbs ?? []).map(point),
      slot: point(s.slot), power: point(s.powerButton), crystal: point(s.crystal),
      ready: !s.busy && !s.locked && (s.acceptingAnswers ?? true) && (s.phase !== "dashing"),
    };
  };
}

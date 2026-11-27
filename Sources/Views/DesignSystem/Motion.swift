import SwiftUI

// MARK: - Motion
//
// Shared animation curves that respect the Reduce Motion setting. With Reduce
// Motion on, movement is replaced by a short cross-fade (or nothing).
//
// In a view:
//     @Environment(\.accessibilityReduceMotion) private var reduceMotion
//     .animation(Motion.standard.resolved(reduceMotion), value: x)
//     .transition(Motion.slide(reduceMotion))
//     Motion.perform(.snappy, reduceMotion: reduceMotion) { state.toggle() }
// Or let the modifier read the setting for you:
//     .motion(.standard, value: x)

enum Motion {
    /// Short state changes: toggles, button presses, pill swaps.
    case quick
    /// Default for most UI movement.
    case standard
    /// Cards being dealt, chips moving: a gentle spring.
    case spring
    /// Slower emphasis (result reveal).
    case emphasized

    /// The full-motion animation.
    var animation: Animation {
        switch self {
        case .quick: return .easeOut(duration: 0.15)
        case .standard: return .easeInOut(duration: 0.25)
        case .spring: return .spring(response: 0.4, dampingFraction: 0.8)
        case .emphasized: return .easeInOut(duration: 0.45)
        }
    }

    /// The animation to use given the Reduce Motion setting: the full curve
    /// normally; a brief fade-length ease with Reduce Motion (quick changes
    /// return nil, i.e. no animation).
    func resolved(_ reduceMotion: Bool) -> Animation? {
        guard reduceMotion else { return animation }
        switch self {
        case .quick: return nil
        case .standard, .spring, .emphasized: return .easeInOut(duration: 0.2)
        }
    }

    /// Runs `body` inside `withAnimation`, honoring Reduce Motion.
    static func perform<Result>(_ motion: Motion, reduceMotion: Bool,
                                _ body: () throws -> Result) rethrows -> Result {
        try withAnimation(motion.resolved(reduceMotion), body)
    }

    /// A slide-up-and-fade insertion that becomes a plain fade with Reduce Motion.
    static func slide(_ reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    /// A scale-and-fade pop that becomes a plain fade with Reduce Motion.
    static func pop(_ reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity)
    }
}

private struct MotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let motion: Motion
    let value: Value

    func body(content: Content) -> some View {
        content.animation(motion.resolved(reduceMotion), value: value)
    }
}

extension View {
    /// `.animation(_:value:)` with a shared curve that honors Reduce Motion.
    func motion<Value: Equatable>(_ motion: Motion, value: Value) -> some View {
        modifier(MotionModifier(motion: motion, value: value))
    }
}

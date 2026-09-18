import Metal
import OSLog
import SwiftUI

/// The disintegration shader: loading, probing and parameters.
///
/// It lives apart from the modifier because of one property of `ShaderLibrary`:
/// it is `@dynamicMemberLookup`, so `ShaderLibrary.bundle(.module).disintegrate(...)`
/// always compiles — whether the function exists or not. Failure arrives not as
/// a Swift error but as a Metal crash at first draw, with nothing to catch. So
/// resolvability has to be probed up front and exactly once, which is what
/// `isAvailable` does.
enum DisintegrateShader {
    private static let log = Logger(subsystem: "Cadence", category: "motion")

    /// The function name in `Disintegrate.metal`. A string, not a symbol: the
    /// link between Swift and Metal is by name and is not checked at compile time.
    static let functionName = "disintegrate"

    /// Upper bound on how far a shard travels, in points.
    static let maxOffset: CGFloat = 90

    /// Frame headroom for the scatter. Larger than `maxOffset` because a shard
    /// also spins about its own centre: a point on its edge travels further than
    /// the centre does. Too little headroom and the outermost pieces are clipped
    /// at the view's bounds, with neither an error nor a warning to show for it.
    static func sampleOffset(for drift: Double) -> CGSize {
        let side = 130 * max(drift, 1)
        return CGSize(width: side, height: side)
    }

    /// Whether the shader function resolves in this target's Metal library.
    ///
    /// Probed lazily and exactly once (`static let`). The library comes from
    /// `Bundle.module`: a `.metal` file in an SPM target compiles into a
    /// `default.metallib` inside that target's bundle, not into the host app's
    /// library, so `MTLDevice.makeDefaultLibrary()` without a bundle would never
    /// find it.
    static let isAvailable: Bool = resolveFunction()

    private static func resolveFunction() -> Bool {
        guard let device = MTLCreateSystemDefaultDevice() else {
            // Not a code defect: a device with no Metal available. Nothing here
            // deserves a loud failure — degrading is enough.
            log.notice("Metal device unavailable, disintegrate degrades to a cross-fade")
            return false
        }

        let library: any MTLLibrary
        do {
            library = try device.makeDefaultLibrary(bundle: .module)
        } catch {
            assertionFailure(
                "Cadence: no default.metallib in the CadenceMotion bundle — "
                    + "\(functionName) cannot load (\(error.localizedDescription))"
            )
            log.error(
                "No default.metallib in the CadenceMotion bundle: \(functionName, privacy: .public) cannot load, degrading to a cross-fade"
            )
            return false
        }

        guard library.makeFunction(name: functionName) != nil else {
            // This is the branch that catches reaching for
            // `ShaderLibrary.default` instead of `.bundle(.module)`: with that
            // mistake the effect works in the catalog and silently disappears in
            // every other project.
            assertionFailure(
                "Cadence: Metal function \(functionName) is missing from the CadenceMotion shader library"
            )
            log.error(
                "Metal function \(functionName, privacy: .public) is missing from the CadenceMotion shader library, degrading to a cross-fade"
            )
            return false
        }

        return true
    }
}

/// A single frame of the break-up at a given progress.
///
/// A `layerEffect` rather than a `colorEffect`: a pixel samples the layer away
/// from itself, and `colorEffect` cannot see neighbouring pixels at all. Nor a
/// `distortionEffect`: that returns a source position rather than a colour, and
/// an alpha fade cannot be expressed through it.
/// The visual character of the break-up.
///
/// These numbers do NOT come from research — in the corpus the effect itself is
/// grade D, an admitted aesthetic decision. That is exactly why they live in a
/// tunable struct while the duration does not: duration comes from the resolver
/// and is governed by perception thresholds.
///
/// `drift` is not "animation speed": the resolver sets how long the break-up
/// takes. It is how far a shard travels in that same time.
public struct DisintegrationTuning: Sendable, Equatable {
    /// Nominal shard size in points. Smaller means more pieces.
    public var shardSize: Double
    /// Size spread, 0...1. At zero every piece is identical and reads as an
    /// algorithm rather than as something breaking.
    public var sizeVariation: Double
    /// How far pieces travel. 1.0 is the baseline.
    public var drift: Double
    /// How random a shard's direction is, 0...1. At zero everything flies
    /// straight outwards from the centre.
    public var scatter: Double
    /// How much each shard rotates about its own centre.
    public var spin: Double
    /// 1 means the break-up travels as a clean wave across the card; 0 means
    /// every shard picks its own moment and the card simply crumbles.
    public var sweep: Double

    public init(
        shardSize: Double = 22,
        sizeVariation: Double = 0.45,
        drift: Double = 1,
        scatter: Double = 0.45,
        spin: Double = 2.4,
        sweep: Double = 0.6
    ) {
        self.shardSize = shardSize
        self.sizeVariation = sizeVariation
        self.drift = drift
        self.scatter = scatter
        self.spin = spin
        self.sweep = sweep
    }

    /// The values the effect was accepted into the toolkit with.
    public static let standard = DisintegrationTuning()
}

struct DisintegrateFrame: ViewModifier {
    let progress: Double
    var tuning: DisintegrationTuning = .standard

    func body(content: Content) -> some View {
        if DisintegrateShader.isAvailable {
            // `visualEffect` is here only for the size: the shader derives the
            // scatter direction (outwards from the view's centre) and the
            // left-to-right break-up wave from it. Without the size both would
            // have to be given in absolute points, and the effect would read
            // differently on a card than on a list row.
            content.visualEffect { view, proxy in
                view.layerEffect(
                    ShaderLibrary.bundle(.module).disintegrate(
                        .float2(proxy.size),
                        .float(Float(progress)),
                        .float(Float(DisintegrateShader.maxOffset)),
                        .float(Float(tuning.shardSize)),
                        .float(Float(tuning.sizeVariation)),
                        .float(Float(tuning.drift)),
                        .float(Float(tuning.scatter)),
                        .float(Float(tuning.spin)),
                        .float(Float(tuning.sweep))
                    ),
                    // Frame headroom grows with drift: set it too low and the
                    // shards are clipped at the view's bounds, without a single
                    // warning.
                    maxSampleOffset: DisintegrateShader.sampleOffset(for: tuning.drift),
                    // At rest the effect is removed entirely: `layerEffect`
                    // forces SwiftUI to render the subtree into a separate
                    // buffer, and there is no reason to pay for that while
                    // nothing is happening.
                    isEnabled: progress > 0
                )
            }
        } else {
            // Quiet degradation in release: a cross-fade instead of a break-up.
            content.opacity(1 - progress)
        }
    }
}

/// The break-up as one run of the timeline per `pulse` change.
///
/// The same device as `ScalePulseModifier`: `keyframeAnimator(trigger:)` plays
/// 0 → 1 exactly once and stays at the end point. Here the end point is a fully
/// scattered view, which is correct — the event is called `destroyed` and there
/// is nothing to return to.
///
/// A concrete type for the same reason as the other `*PulseModifier` types in
/// `CadenceMotionModifier.swift`: under Swift 6 the `keyframeAnimator` closures
/// drag in the enclosing type's generic metatype.
struct DisintegratePulseModifier: ViewModifier {
    let duration: TimeInterval
    let pulse: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: pulse) { view, progress in
            view.modifier(DisintegrateFrame(progress: progress))
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                // Progress runs strictly linearly, and that is not an oversight:
                // all the softness lives inside the shader, where every shard has
                // its own ease-out on displacement and its own lagging one on
                // alpha. A curve applied out here would compose with those a
                // second time and break the break-up wave, which has to travel
                // across the card at a constant rate.
                LinearKeyframe(1.0, duration: duration)
            }
        }
    }
}

/// Reassembly as a pulse: the same frame, with progress running 1 -> 0.
///
/// It works because the shader is a pure function of progress: it keeps no state
/// between frames and has no idea which way it is being driven.
///
/// Careful: like any pulse it starts from its own initial value, which here is
/// the scattered state. Apply it only to a view that has already broken up. For
/// the break-up/reassembly pair the right entry point is
/// `cadenceDisintegration(isDestroyed:)`, which is state-driven and correct at
/// rest in both directions.
struct ReassemblePulseModifier: ViewModifier {
    let duration: TimeInterval
    let pulse: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 1.0, trigger: pulse) { view, progress in
            view.modifier(DisintegrateFrame(progress: progress))
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                LinearKeyframe(0.0, duration: duration)
            }
        }
    }
}

/// The break-up driven by state rather than by a pulse.
///
/// The `@preconcurrency` on the conformance is not decoration: `ViewModifier` is
/// main-actor isolated while SwiftUI calls `Animatable.animatableData` outside
/// it, and Swift 6 counts that as crossing isolation. There is no race here: the
/// value is a single `Double` that SwiftUI itself reads and writes while
/// interpolating.
///
/// `Animatable` does all the work: SwiftUI interpolates `progress` frame by
/// frame, so one piece of code serves both directions — 0 -> 1 on deletion and
/// 1 -> 0 on the way back. A pulse cannot express this: a pulse has a beginning
/// and an end, while the break-up/reassembly pair has two resting states with
/// travel in both directions.
public struct DisintegrationState: ViewModifier, @preconcurrency Animatable {
    public var progress: Double
    public var tuning: DisintegrationTuning

    public init(progress: Double, tuning: DisintegrationTuning = .standard) {
        self.progress = progress
        self.tuning = tuning
    }

    public var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    public func body(content: Content) -> some View {
        content.modifier(DisintegrateFrame(progress: progress, tuning: tuning))
    }
}

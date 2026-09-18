# Cadence

A personal iOS toolkit of animations, microinteractions and haptics — where every
duration traces back to a source.

Most animation advice is folklore. Numbers get copied between projects until nobody
remembers why a transition lasts 300 ms rather than 500. Cadence takes the opposite
approach: each timing comes from research that is cited in the repository, graded by
how strong the evidence actually is, and — where it matters — enforced by the type
system rather than by a paragraph in a style guide.

**Requirements:** iOS 26.0+, Swift 6.3, Xcode 26.

---

## The idea in one screen

You describe *what happened*, not *what should move*:

```swift
Button("Save") { taps += 1 }
    .cadence(.pressed, trigger: taps)
```

A resolver turns that event, plus the current accessibility environment, into a plan:
a motion spec and a haptic spec. The plan decides the duration, the curve and the
tactile pattern. You never pick a number.

```swift
public func resolve(_ event: RoutineInteraction, in ctx: CadenceContext) -> FeedbackPlan
```

This function is pure — no side effects, no access to the clock, no SwiftUI import.
That is what makes the research rules checkable by a unit test instead of merely
declared in a README.

---

## Two axes, deliberately separate

An early draft merged frequency and duration into one concept and immediately
contradicted itself: content arrival had to be under 100 ms because it happens
constantly, and 200–300 ms because it is a screen change. These are different
measurements.

**`Tier` — how often the effect is appropriate.** Governs how hard it is to reach for.

| Tier | Frequency | Opt-in |
|---|---|---|
| `workhorse` | hundreds of times per session | plain call |
| `accent` | a handful of times per session | plain call |
| `signature` | once a session or less | separate type, separate modifier |

**`ChangeClass` — what kind of change it is.** Governs the duration budget.

| Class | Budget | Source |
|---|---|---|
| `direct` | 100 ms | threshold of perceived instantaneity |
| `screen` | 300 ms | vendor guideline |
| `journey` | 400 ms | vendor guideline |
| `persistent` | none | a skeleton lasts as long as the work does |

A frequent effect is allowed to be a slow screen change. A rare effect is allowed to
be quick. Conflating the two is what produced the contradiction above.

---

## Rules the compiler enforces

Signature effects live in their own event type with their own modifier:

```swift
row.cadence(.pressed, trigger: taps)                  // RoutineInteraction
row.cadenceSignature(.destroyed, trigger: isDeleted)  // SignatureInteraction
```

Applying the disintegration effect to a Save button is not discouraged by
documentation — it does not compile. A boolean flag such as `allowSignature: true`
would have been shorter and would have been ticked without thinking.

---

## The eight effects

```swift
public enum RoutineInteraction {
    case pressed
    case selectionChanged
    case contentArrived(staggerIndex: Int)
    case waiting(elapsed: Duration)     // caller computes "now": the resolver stays pure
    case validationFailed
    case taskSucceeded
}

public enum SignatureInteraction {
    case destroyed
    case restored      // shards fly back and reform
}
```

| Effect | Tier | Class | Notes |
|---|---|---|---|
| `pressResponse` | workhorse | direct | spring scale, light impact |
| `selectionShift` | workhorse | direct | timing and haptic only; your view moves its own indicator |
| `contentArrival` | workhorse | screen | ease-out with a capped stagger cascade |
| `waitingState` | accent | persistent | nothing, then skeleton, then determinate progress |
| `validationFailure` | accent | screen | decaying shake, error haptic |
| `taskSuccess` | accent | screen | checkmark draws on, success haptic |
| `disintegrate` | signature | journey | Metal shader; card breaks into irregular shards, and reassembles on the way back |

### The waiting rule

This is the one place the toolkit forbids something outright:

| Elapsed | Shown |
|---|---|
| under 1 s | **nothing at all** — not a spinner, not a placeholder reserving space |
| 1–10 s | skeleton |
| over 10 s | determinate progress, cancellable |

A loading indicator that lives for 300 ms reads as a flicker and makes the interface
feel slower, not faster.

---

## Usage

Add the package:

```swift
.package(url: "https://github.com/danilmvv/cadence", from: "0.1.0")
```

Event-driven effects:

```swift
import Cadence

TextField("Code", text: $code)
    .cadence(.validationFailed, trigger: failedAttempts)

ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
    RowView(row)
        .cadence(.contentArrived(staggerIndex: index), trigger: isLoaded)
}
```

Views Cadence draws itself:

```swift
CadenceWaitingIndicator(elapsed: elapsed, progress: fraction)

CadenceTaskSuccessIndicator(trigger: didComplete)

```

The signature effect, driven by state so it runs in both directions:

```swift
CardView(item)
    .cadenceDisintegration(isDestroyed: isDeleted)
```

Destroying flies the shards out; setting the flag back reassembles them. The same
shader runs both ways — it is a pure function of progress, so reversing it costs
nothing.

`collapsesLayout` (on by default) also reflows the neighbours, and the ordering is
deliberate: the space closes **after** the shards have gone, and opens **before** they
fly back. The reverse would make the surrounding elements twitch for no visible
reason. That reflow is a screen-class change, so it takes the 300 ms budget rather
than the effect's own 1200 ms.

For a one-shot destruction with nothing to return to, the pulse API still applies:

```swift
CardView(item)
    .cadenceSignature(.destroyed, trigger: deleteCount)
```

---

## Accessibility

Degradation substitutes, it never simply removes — the person still has to understand
that something changed.

| Condition | Behaviour |
|---|---|
| Reduce Motion | motion becomes a cross-fade |
| Reduce Transparency | glass becomes an opaque fill |
| No Taptic Engine | haptics are a silent no-op; motion is unaffected |
| Scene inactive | haptics suppressed |

Haptics are throttled per pattern. Without that, a selection haptic during a fast
scroll becomes continuous buzzing — the usual reason people switch haptics off
entirely. A haptic is never the sole carrier of information: the resolver drops it
when there is no accompanying visual change.

---

## Designing your own haptics

`CadenceHapticLab()` is a workbench for building a haptic by hand and feeling it
before it goes into the code. Compose transients and continuous phases, set
intensity, sharpness and timing, play it, and copy the result out as Swift:

```swift
HapticComposition(name: "unlock", events: [
    .transient(at: 0.00, intensity: 0.55, sharpness: 0.70),
    .continuous(at: 0.10, duration: 0.25, intensity: 0.40, sharpness: 0.20),
])
```

Play it through the same path as everything else:

```swift
HapticSpec(pattern: .custom(composition), minimumInterval: .milliseconds(500))
```

The lab plays through `CadenceRuntime.shared.scheduler`, exactly like every
built-in effect — there is no separate preview channel, because a pattern
auditioned on a side channel would prove nothing about how it lands in the app.

Two caveats worth stating plainly. Haptics cannot be felt in the simulator, and
the lab says so rather than letting you tune by eye. And the system patterns —
`success`, `warning`, `selection` — already mean something to anyone who uses
iOS; a custom rhythm carries no such shared meaning, so it is worth reserving for
something the system vocabulary genuinely cannot say.

The lab is a development tool that happens to ship in the library, so that it can
be dropped behind a debug menu in any project. Gate it behind a build flag if
that bothers you.

## The catalog

A demo app lives in `Catalog/`. The Xcode project is generated, not committed:

```bash
cd Catalog && xcodegen generate && open Catalog.xcodeproj
```

Environment toggles inside the app override the whole context, so degradation can be
inspected without touching system settings. To run on a physical device, put your
development team in `Catalog/Local.xcconfig` — that file is deliberately not tracked.

---

## Documentation

- **`docs/research/`** — the corpus. Every claim carries an evidence grade: **A**
  reproduced across decades, **B** vendor guideline, **C** single studies, **D**
  taste, admitted as taste. A `workhorse` effect may not rest on anything weaker
  than B.
- **`docs/research/sources.md`** — includes an *unverified* section listing
  widely-circulated statistics about microanimations for which no primary source
  could be found. None of them is used anywhere in this codebase.
- **`docs/technique/`** — implementation notes on Metal shaders in SwiftUI: the three
  shader modifiers and when each applies, `maxSampleOffset`, and the trap where a
  shader in a Swift package resolves through the package's own bundle rather than the
  app's.

Grades are load-bearing, not decorative. Three constants in the resolver — two haptic
throttle intervals and the shimmer cycle — are recorded as grade **D**: chosen by
engineering judgement with no evidence behind them. The disintegration effect is
grade **D** as well. Saying so is more useful than inventing a justification.

---

## Status

Working: all eight effects build and run, with a demo catalog.

Not done yet, stated plainly:

- **The rule tests are not written.** The resolver is pure specifically so that the
  research rules can be asserted — no workhorse motion longer than 100 ms, no plan
  emptied by Reduce Motion, no haptic without a visual. Until those exist, the rules
  are prose. This is the next task and the project's premise rests on it.
- **Reduce Motion loses information past ten seconds.** Degradation currently collapses
  the motion kind, so a wait longer than ten seconds shows a still skeleton instead of
  a still progress bar — cancelling a research requirement rather than cancelling
  motion. Known, documented, unfixed.

## License

MIT

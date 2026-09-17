import SwiftUI
import CadenceCore

/// Применяет к вью виды движения модификаторного семейства.
///
/// Первая версия сводила всё к единому `phase: Bool`, и это дало два
/// видимых бага: `.scale` навсегда оставлял кнопку сжатой после первого
/// нажатия (тумблер один раз перевернулся в `true` и застрял), а `.fade`
/// держал контент невидимым, потому что `onChange` не срабатывает на
/// только что вставленной вью — событию неоткуда взяться. У каждого вида
/// свой характер, и семантика прописана по видам, а не одним тумблером:
/// `.scale`/`.shake` — разовый импульс на смену `trigger`, `.fade` —
/// проявление, обязанное случиться и на первом появлении, и повторно.
public struct CadenceMotionModifier<Trigger: Equatable>: ViewModifier {
    public let spec: MotionSpec?
    public let trigger: Trigger

    public init(spec: MotionSpec?, trigger: Trigger) {
        self.spec = spec
        self.trigger = trigger
    }

    // Произвольный `Trigger: Equatable` вызывающей стороны (например,
    // кастомный enum состояния) не гарантированно Sendable, а тела ниже
    // строятся через keyframeAnimator, чьи внутренние замыкания Swift 6 в
    // строгом режиме конкурентности хочет видеть Sendable-совместимыми.
    // Протаскивать `Sendable` через весь публичный API `.cadence` ради
    // этого не стоит: вместо самого `trigger` в дочерние модификаторы ниже
    // уходит собственный Int-счётчик, растущий на каждую его смену — Int
    // уже Sendable, и generic-параметр наружу из этого файла не просачивается.
    @State private var pulse = 0

    public func body(content: Content) -> some View {
        Group {
            if let spec {
                bodyWithSpec(content: content, spec: spec)
            } else {
                content
            }
        }
        .onChange(of: trigger) { pulse += 1 }
    }

    @ViewBuilder
    private func bodyWithSpec(content: Content, spec: MotionSpec) -> some View {
        switch spec.kind {
        case .scale(let target):
            // Транзиентный импульс: доехать до цели и вернуться к 1.0 за
            // один прогон таймлайна. `keyframeAnimator(trigger:)` для того
            // и существует — прогоняет таймлайн ровно один раз на смену
            // триггера, в отличие от переключаемого состояния, которое
            // остаётся в конечной точке до следующего переключения.
            content.modifier(ScalePulseModifier(target: target, duration: spec.duration.timeInterval, pulse: pulse))

        case .shake(let amplitude):
            // Тот же принцип, что у `.scale`: один прогон на смену pulse.
            // `shakes` идёт 0 → 3; при shakes == 3 `ShakeEffect.horizontalDisplacement`
            // обнуляется (затухание дошло до нуля), и конечная точка
            // таймлайна визуально совпадает с состоянием покоя.
            content.modifier(ShakePulseModifier(amplitude: amplitude, duration: spec.duration.timeInterval, pulse: pulse))

        case .fade:
            // Проявление, а не тумблер: обязано случиться при появлении
            // вью (когда никакого `onChange` ещё не было и не будет) и
            // повторно — при смене триггера.
            content.modifier(FadeInModifier(spec: spec, pulse: pulse))

        case .timingOnly:
            // Cadence даёт только тайминг и хаптик; геометрию знает и
            // анимирует сама вызывающая сторона — визуально ничего не трогаем.
            content

        case .disintegrate:
            // Тот же разовый прогон, что у `.scale` и `.shake`, только
            // прогресс уходит в Metal-шейдер. Ветка выбирается по виду
            // движения из уже разрешённого плана, а не по среде: решение о
            // том, каким движение будет, целиком принадлежит резолверу.
            content.modifier(DisintegratePulseModifier(duration: spec.duration.timeInterval, pulse: pulse))

        case .shimmer, .progress, .drawOn, .cornerReveal:
            // Видовое семейство: рисует сам Cadence, модификатором не
            // выражается — см. `MotionKind.isModifierFamily`. Игнорируем
            // явно, а не через `default`, чтобы новый вид не провалился
            // сюда молча.
            content
        }
    }
}

/// Импульс масштаба: до цели и обратно к 1.0 за один прогон таймлайна.
///
/// Не-generic тип, а не метод `CadenceMotionModifier<Trigger>`: замыкание
/// `content:` у `keyframeAnimator` объявлено так, что компилятор в Swift 6
/// пытается захватить метатип generic-параметра окружающего типа целиком,
/// даже если внутри замыкания он не используется — отсюда ложное
/// предупреждение о Sendable. Вынос в конкретный тип, принимающий уже
/// обычный `Int`, убирает generic-контекст вместе с предупреждением.
private struct ScalePulseModifier: ViewModifier {
    let target: Double
    let duration: TimeInterval
    let pulse: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 1.0, trigger: pulse) { view, scale in
            view.scaleEffect(CGFloat(scale))
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(target, duration: duration / 2)
                CubicKeyframe(1.0, duration: duration / 2)
            }
        }
    }
}

/// Затухающее потряхивание: `ShakeEffect.shakes` идёт 0 → 3 за один прогон
/// таймлайна. См. `ScalePulseModifier` — та же причина не-generic типа.
private struct ShakePulseModifier: ViewModifier {
    let amplitude: Double
    let duration: TimeInterval
    let pulse: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat.zero, trigger: pulse) { view, shakes in
            view.modifier(ShakeEffect(amplitude: CGFloat(amplitude), shakes: shakes))
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                LinearKeyframe(CGFloat(3), duration: duration)
            }
        }
    }
}

/// Проявление контента: 0 → 1 при появлении вью и повторно на каждую смену
/// `pulse`. Сброс перед повторным проигрыванием не оборачивается в
/// анимацию: SwiftUI фиксирует значение `@State` в момент присваивания, и
/// последующий анимированный переход считается от него, даже если кадр с
/// промежуточным значением ни разу не был отрисован.
private struct FadeInModifier: ViewModifier {
    let spec: MotionSpec
    let pulse: Int

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear { reveal() }
            .onChange(of: pulse) {
                isVisible = false
                reveal()
            }
    }

    private func reveal() {
        withAnimation(spec.animation) {
            isVisible = true
        }
    }
}

import Metal
import OSLog
import SwiftUI

/// Шейдер распада: загрузка, проверка и параметры.
///
/// Существует отдельно от модификатора ровно из-за одной особенности
/// `ShaderLibrary`: это `@dynamicMemberLookup`, поэтому
/// `ShaderLibrary.bundle(.module).disintegrate(...)` компилируется всегда —
/// и когда функция есть, и когда её нет. Отказ приходит не ошибкой Swift, а
/// обвалом Metal в момент первой отрисовки, и перехватить его нечем.
/// Значит, резолвимость нужно проверить заранее и один раз — это и делает
/// `isAvailable`.
enum DisintegrateShader {
    private static let log = Logger(subsystem: "Cadence", category: "motion")

    /// Имя функции в `Disintegrate.metal`. Строка, а не символ: связь между
    /// Swift и Metal здесь именная и ничем на этапе компиляции не проверяется.
    static let functionName = "disintegrate"

    /// Верхняя граница разлёта осколка в точках.
    static let maxOffset: CGFloat = 90

    /// Запас кадра под разлёт. Больше `maxOffset`, потому что осколок ещё и
    /// вращается вокруг своего центра: точка на его краю уезжает дальше, чем
    /// сам центр. Не хватит запаса — дальние куски обрежет по границе вью,
    /// и это не даст ни ошибки, ни предупреждения.
    static func sampleOffset(for drift: Double) -> CGSize {
        let side = 130 * max(drift, 1)
        return CGSize(width: side, height: side)
    }

    /// Резолвится ли функция шейдера в Metal-библиотеке этого таргета.
    ///
    /// Проверяется лениво и ровно один раз (`static let`). Библиотека берётся
    /// из `Bundle.module`: `.metal` в SPM-таргете компилируется в
    /// `default.metallib` внутри бандла таргета, а не в библиотеку главного
    /// бандла приложения, поэтому `MTLDevice.makeDefaultLibrary()` без
    /// бандла её не нашёл бы.
    static let isAvailable: Bool = resolveFunction()

    private static func resolveFunction() -> Bool {
        guard let device = MTLCreateSystemDefaultDevice() else {
            // Не ошибка кода: устройство без доступного Metal. Громко падать
            // тут не за что, деградации достаточно.
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
            // Именно этот случай ловит ошибку обращения через
            // `ShaderLibrary.default` вместо `.bundle(.module)`: с ней эффект
            // работает в каталоге и молча исчезает в любом другом проекте.
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

/// Один кадр распада при заданном прогрессе.
///
/// Шейдер — `layerEffect`, а не `colorEffect`: пиксель сэмплирует слой в
/// стороне от себя, а `colorEffect` соседних пикселей не видит в принципе.
/// И не `distortionEffect`: тот возвращает позицию источника, а не цвет, и
/// затухание альфы через него не выражается.
/// Визуальный характер распада.
///
/// Эти числа НЕ выводятся из ресерча — в корпусе сам эффект стоит на грейде D,
/// то есть признан эстетическим решением. Именно поэтому они вынесены в
/// настраиваемую структуру, а длительность — нет: длительность приходит из
/// резолвера и governed порогами восприятия.
///
/// `drift` не «скорость анимации»: время распада задаёт резолвер. Это
/// дальность разлёта осколка за то же самое время.
public struct DisintegrationTuning: Sendable, Equatable {
    /// Номинальный размер осколка в точках. Меньше — больше кусков.
    public var shardSize: Double
    /// Разброс размеров, 0...1. На нуле все куски одинаковые и читаются
    /// как алгоритм, а не как разрушение.
    public var sizeVariation: Double
    /// Дальность разлёта. 1.0 — базовая.
    public var drift: Double
    /// Насколько направление осколка случайно, 0...1. На нуле все летят
    /// строго от центра наружу.
    public var scatter: Double
    /// Величина поворота осколка вокруг своей оси.
    public var spin: Double
    /// 1 — отрыв идёт чистой волной по карточке; 0 — каждый осколок
    /// выбирает момент сам, и карточка просто осыпается.
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

    /// Значения, с которыми эффект принимался в тулкит.
    public static let standard = DisintegrationTuning()
}

struct DisintegrateFrame: ViewModifier {
    let progress: Double
    var tuning: DisintegrationTuning = .standard

    func body(content: Content) -> some View {
        if DisintegrateShader.isAvailable {
            // `visualEffect` нужен только ради размера: по нему шейдер
            // считает направление разлёта (наружу от центра вью) и волну
            // отрыва слева направо. Без размера обе величины пришлось бы
            // задать в абсолютных точках, и эффект по-разному читался бы на
            // карточке и на строке списка.
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
                    // Запас кадра растёт вместе с дальностью: занизить его —
                    // получить осколки, обрезанные по границе вью, без
                    // единого предупреждения.
                    maxSampleOffset: DisintegrateShader.sampleOffset(for: tuning.drift),
                    // В покое эффект снят целиком: `layerEffect` заставляет
                    // SwiftUI рисовать поддерево в отдельный буфер, и платить
                    // за это, пока ничего не происходит, незачем.
                    isEnabled: progress > 0
                )
            }
        } else {
            // Тихая деградация в релизе: кросс-фейд вместо распада.
            content.opacity(1 - progress)
        }
    }
}

/// Распад за один прогон таймлайна на смену `pulse`.
///
/// Тот же приём, что у `ScalePulseModifier`: `keyframeAnimator(trigger:)`
/// проигрывает 0 → 1 ровно один раз и остаётся в конечной точке. Конечная
/// точка здесь — полностью рассыпавшаяся вью, и это правильно: событие
/// называется `destroyed`, возвращаться не к чему.
///
/// Не-generic тип по той же причине, что и остальные `*PulseModifier` в
/// `CadenceMotionModifier.swift`: замыкания `keyframeAnimator` в Swift 6
/// тянут за собой метатип generic-параметра окружающего типа.
struct DisintegratePulseModifier: ViewModifier {
    let duration: TimeInterval
    let pulse: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: pulse) { view, progress in
            view.modifier(DisintegrateFrame(progress: progress))
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                // Прогресс идёт строго линейно, и это не упущение: вся
                // мягкость живёт внутри шейдера, где у каждого осколка своя
                // ease-out на смещении и своя, отстающая, на альфе. Кривая
                // снаружи наложилась бы на них второй раз и сбила бы волну
                // отрыва — та обязана идти по карточке с постоянной скоростью.
                LinearKeyframe(1.0, duration: duration)
            }
        }
    }
}

/// Обратная сборка импульсом: тот же кадр, прогресс идёт 1 -> 0.
///
/// Работает потому, что шейдер — чистая функция прогресса: состояния между
/// кадрами он не держит и не знает, в какую сторону его гонят.
///
/// Осторожно: как и всякий импульс, стартует со своего начального значения,
/// то есть с распавшегося состояния. Применять к вью, которая уже распалась.
/// Для пары «распад — сборка» правильный вход — `cadenceDisintegration(isDestroyed:)`,
/// он управляется состоянием и в покое корректен в обе стороны.
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

/// Распад, управляемый состоянием, а не импульсом.
///
/// `@preconcurrency` на соответствии — не украшение: `ViewModifier` изолирован
/// главным актором, а `Animatable.animatableData` SwiftUI дёргает вне его,
/// и Swift 6 считает это пересечением изоляции. Гонки тут нет: значение —
/// одно `Double`, которое читает и пишет сама SwiftUI во время интерполяции.
///
/// `Animatable` здесь несёт всю работу: SwiftUI интерполирует `progress`
/// покадрово, поэтому одно и то же место кода обслуживает оба направления —
/// 0 -> 1 при удалении и 1 -> 0 при возврате. Импульсом это не выражается:
/// у импульса есть начало и конец, а у пары «распад — сборка» есть два
/// устойчивых состояния, между которыми ходят в обе стороны.
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

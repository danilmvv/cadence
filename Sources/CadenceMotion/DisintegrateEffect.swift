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
    static let sampleOffset = CGSize(width: 130, height: 130)

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
private struct DisintegrateFrame: ViewModifier {
    let progress: Double

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
                        .float(Float(DisintegrateShader.maxOffset))
                    ),
                    maxSampleOffset: DisintegrateShader.sampleOffset,
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

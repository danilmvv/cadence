import OSLog
import SwiftUI
import CadenceCore

/// Геометрия физического угла экрана.
///
/// Существует отдельно от вью по той же причине, что `DisintegrateShader`:
/// у эффекта есть предусловие, которое ничем на этапе компиляции не
/// проверяется. Там это резолвимость Metal-функции, здесь — то, что
/// контейнер, относительно которого SwiftUI считает concentric-кривизну,
/// действительно окно устройства, а не вложенный `ScrollView`. Если это
/// не так, эффект не падает и ничего не сообщает: он просто рисует
/// скруглённый прямоугольник со случайным радиусом, и отличить его от
/// правильного глазом почти невозможно. Значит, отсутствие скругления у
/// контейнера нужно заметить и записать.
enum ScreenCornerGeometry {
    static let log = Logger(subsystem: "Cadence", category: "motion")

    /// Отступ угла контейнера в точках — то, насколько содержимое надо
    /// увести внутрь, чтобы не попасть под скругление.
    ///
    /// Это **не** радиус: из `RectangleCornerInsets` радиус выводится
    /// только через константу формы скругления, а какая там форма —
    /// внутреннее дело SwiftUI. Поэтому величина используется как есть, в
    /// виде расстояния, на которое элемент утоплен в угол, и нигде не
    /// пересчитывается в радиус. Сам радиус берёт на себя
    /// `ConcentricRectangle`, которому число снаружи не нужно.
    static func inset(_ insets: RectangleCornerInsets, at corner: ScreenCorner) -> CGSize {
        switch corner {
        case .topLeading: insets.topLeading
        case .topTrailing: insets.topTrailing
        case .bottomLeading: insets.bottomLeading
        case .bottomTrailing: insets.bottomTrailing
        }
    }

    /// Скруглён ли угол контейнера, из которого мы собираемся вытекать.
    ///
    /// Ноль означает ровно одно: вью не занимает окно устройства, и всё,
    /// что она нарисует, будет концентрично не экрану, а чему-то другому.
    /// Это не `assertionFailure`: в превью и в тестовых хостах ноль —
    /// нормальное значение, и падать на нём значило бы запретить превью.
    static func reportIfSquare(_ insets: RectangleCornerInsets, at corner: ScreenCorner) {
        let size = inset(insets, at: corner)
        guard size.width == 0, size.height == 0 else { return }
        log.notice(
            "cornerEmergence: container has no corner rounding at \(String(describing: corner), privacy: .public) — the shape will be concentric with its container, not with the display"
        )
    }
}

/// Раскладка угла: куда прижимать, куда уводить, вокруг чего масштабировать.
extension ScreenCorner {
    var alignment: Alignment {
        switch self {
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }

    /// Точка, из которой элемент растёт. Совпадает с самим углом, поэтому
    /// маленький масштаб не отрывает элемент от угла, а прижимает к нему.
    var unitPoint: UnitPoint {
        switch self {
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }

    /// Знаки смещения «наружу», в сторону угла.
    var outward: CGSize {
        switch self {
        case .topLeading: CGSize(width: -1, height: -1)
        case .topTrailing: CGSize(width: 1, height: -1)
        case .bottomLeading: CGSize(width: -1, height: 1)
        case .bottomTrailing: CGSize(width: 1, height: 1)
        }
    }
}

/// Числа эффекта в одном месте. Ни одно из них не длительность: тайминг
/// приходит из `MotionSpec`, здесь только геометрия.
enum CornerEmergenceMetrics {
    /// Радиус слияния стекла в `GlassEffectContainer`. Пока капля и
    /// элемент ближе этого расстояния, они читаются как одна материя;
    /// дальше стекло растягивается и рвётся. Ради этого разрыва эффект и
    /// существует.
    static let mergeSpacing: CGFloat = 26

    /// Сторона капли в углу, если контейнер не дал скругления.
    static let minimumSeedSide: CGFloat = 26

    /// Отступ элемента от края экрана в покое.
    static let restingPadding: CGFloat = 12

    /// Масштаб элемента в тот момент, когда он ещё внутри угла.
    static let hiddenScale: CGFloat = 0.28

    static let seedID = "cadence.cornerEmergence.seed"
    static let elementID = "cadence.cornerEmergence.element"
}

/// Материал элемента: стекло или, при `reduceTransparency`, плотная заливка.
///
/// Для этого эффекта подмена принципиальнее, чем где-либо ещё в тулките:
/// всё остальное построено на движении и переживает потерю прозрачности,
/// а здесь стекло — сам предмет. Заливка берётся системная и непрозрачная
/// (`.background`), а не `.regularMaterial`: материал остаётся полупрозрачным
/// и нарушает ровно ту настройку, ради которой мы сюда попали.
private struct CornerMaterial: ViewModifier {
    let isOpaque: Bool

    func body(content: Content) -> some View {
        if isOpaque {
            content
                .background(.background, in: ConcentricRectangle())
                // Граница нужна именно в непрозрачном режиме: у стекла край
                // рисует само стекло, у плоской заливки — ничего, и элемент
                // сливается с фоном того же системного цвета.
                .overlay {
                    ConcentricRectangle().stroke(.primary.opacity(0.18), lineWidth: 1)
                }
        } else {
            content.glassEffect(.regular, in: ConcentricRectangle())
        }
    }
}

/// Один кадр выхода из угла.
///
/// `Animatable` на самой вью, а не набор `.offset`/`.opacity` от булева
/// состояния. Причина конкретная: капля в углу обязана быть видна в
/// середине анимации и невидима на обоих её концах, то есть её прозрачность —
/// функция от прогресса, а не от конечного значения. SwiftUI же
/// интерполирует анимируемые атрибуты, а тело вью вычисляет один раз, с
/// уже конечным значением, — и такая функция схлопнулась бы в «ноль в
/// ноль». `Animatable` заставляет пересчитывать тело на каждом кадре.
///
/// Соответствие `Animatable` изолировано главным актором: `View` в Swift 6
/// изолирована им целиком, а требование `animatableData` — нет, и без
/// `@MainActor` перед протоколом компилятор считает такое соответствие
/// выходом за границу актора.
private struct CornerEmergenceStage<Content: View>: View, @MainActor Animatable {
    var progress: Double
    let corner: ScreenCorner
    let cornerInset: CGSize
    let isOpaque: Bool
    let namespace: Namespace.ID
    let content: Content

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        // Пружина из спеки перелетает через единицу и возвращается; всё,
        // что считается от прогресса как от доли, должно это пережить.
        let clamped = min(max(progress, 0), 1)

        GlassEffectContainer(spacing: CornerEmergenceMetrics.mergeSpacing) {
            ZStack(alignment: corner.alignment) {
                seed(clamped: clamped)
                element(clamped: clamped)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: corner.alignment)
            .padding(CornerEmergenceMetrics.restingPadding)
        }
    }

    /// Капля, приклеенная к углу: та материя, из которой вытекает элемент.
    ///
    /// Видна только пока идёт выход — в покое её нет ни до, ни после.
    /// Постоянно висящее в углу пятно было бы не эффектом, а артефактом.
    private func seed(clamped: Double) -> some View {
        let side = max(
            max(cornerInset.width, cornerInset.height),
            CornerEmergenceMetrics.minimumSeedSide
        )

        return Color.clear
            .frame(width: side, height: side)
            .modifier(CornerMaterial(isOpaque: isOpaque))
            .glassEffectID(CornerEmergenceMetrics.seedID, in: namespace)
            // Треугольник: 0 на концах, 1 в середине.
            .opacity(1 - abs(2 * clamped - 1))
    }

    private func element(clamped: Double) -> some View {
        // В спрятанном состоянии элемент стоит ровно в углу — настолько
        // внутри скругления, насколько контейнер сам сообщил про своё
        // скругление, плюс собственный отступ от края.
        let travelX = cornerInset.width + CornerEmergenceMetrics.restingPadding
        let travelY = cornerInset.height + CornerEmergenceMetrics.restingPadding
        let remaining = 1 - progress

        return content
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .modifier(CornerMaterial(isOpaque: isOpaque))
            .glassEffectID(CornerEmergenceMetrics.elementID, in: namespace)
            .scaleEffect(
                CornerEmergenceMetrics.hiddenScale
                    + (1 - CornerEmergenceMetrics.hiddenScale) * progress,
                anchor: corner.unitPoint
            )
            .offset(
                x: corner.outward.width * travelX * remaining,
                y: corner.outward.height * travelY * remaining
            )
            // Содержимое проявляется быстрее геометрии: пока элемент ещё
            // капля, текст в нём нечитаем и только мешает.
            .opacity(min(1, clamped * 2.5))
    }
}

/// Выход элемента из физического угла экрана.
///
/// Видовое семейство: Cadence рисует обрамление сам, модификатором это не
/// выражается — см. `MotionKind.isModifierFamily`. Поведение целиком
/// читается из уже разрешённого `spec.kind`, а не из среды: решение о том,
/// каким движение будет, принадлежит резолверу.
///
/// Три опоры эффекта — `GeometryProxy.containerCornerInsets` (реальная
/// геометрия угла устройства), `ConcentricRectangle` (кривизна, оставшаяся
/// концентричной контейнеру) и `GlassEffectContainer` с `glassEffectID` в
/// общем `@Namespace` (слияние и разрыв стекла вместо кроссфейда).
public struct CadenceCornerReveal<Content: View>: View {
    public var spec: MotionSpec
    public var isPresented: Bool
    public var isOpaque: Bool
    private let content: Content

    @Namespace private var glass
    @State private var cornerInsets = RectangleCornerInsets()
    @State private var progress: Double = 0

    /// - Parameters:
    ///   - spec: движение, уже прошедшее `resolve(.summoned(from:), in:)`.
    ///   - isPresented: показан ли элемент.
    ///   - isOpaque: подменять ли стекло плотной заливкой
    ///     (`accessibilityReduceTransparency`). Передаётся снаружи, а не
    ///     читается из среды: тумблеры каталога подменяют контекст целиком,
    ///     а контекст живёт в зонтичном таргете.
    public init(
        spec: MotionSpec,
        isPresented: Bool,
        isOpaque: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.spec = spec
        self.isPresented = isPresented
        self.isOpaque = isOpaque
        self.content = content()
    }

    public var body: some View {
        switch spec.kind {
        case .cornerReveal(let corner):
            emergence(from: corner)

        case .fade:
            // Среда уже понизила вид: Reduce Motion или Low Power Mode.
            // Стеклянный путь не запускается вовсе — ни контейнера, ни
            // покадрового пересчёта, только проявление.
            plainFade

        case .timingOnly, .scale, .shake, .shimmer, .progress, .drawOn, .disintegrate:
            // `resolve(.summoned)` таких видов не возвращает: сюда можно
            // попасть только чужим планом, вставленным по ошибке. Это тот
            // же класс отказа, что и неразрешившаяся функция шейдера, —
            // молчаливый и незаметный, поэтому громко в дебаге и в лог
            // в релизе.
            misroutedFade
        }
    }

    // MARK: - Стеклянный путь

    private func emergence(from corner: ScreenCorner) -> some View {
        CornerEmergenceStage(
            progress: progress,
            corner: corner,
            cornerInset: ScreenCornerGeometry.inset(cornerInsets, at: corner),
            isOpaque: isOpaque,
            namespace: glass,
            content: content
        )
        .onGeometryChange(for: RectangleCornerInsets.self) { proxy in
            proxy.containerCornerInsets
        } action: { newValue in
            cornerInsets = newValue
            ScreenCornerGeometry.reportIfSquare(newValue, at: corner)
        }
        .onAppear {
            // Без анимации: элемент, уже показанный на момент вставки вью,
            // не «выезжает» — выезжать ему неоткуда, события ещё не было.
            progress = isPresented ? 1 : 0
        }
        .onChange(of: isPresented) {
            withAnimation(spec.animation) {
                progress = isPresented ? 1 : 0
            }
        }
        // В покое вью занимает весь экран и перехватывала бы касания
        // насквозь, хотя показывать ей нечего.
        .allowsHitTesting(isPresented)
    }

    // MARK: - Деградация

    private var plainFade: some View {
        content
            .opacity(isPresented ? 1 : 0)
            .animation(spec.animation, value: isPresented)
            .allowsHitTesting(isPresented)
    }

    private var misroutedFade: some View {
        plainFade.onAppear { Self.reportMisroute(spec.kind) }
    }

    private static func reportMisroute(_ kind: MotionKind) {
        assertionFailure(
            "Cadence: CadenceCornerReveal was given \(kind) — only .cornerReveal and its degraded .fade belong here"
        )
        ScreenCornerGeometry.log.error(
            "CadenceCornerReveal was given \(String(describing: kind), privacy: .public) instead of .cornerReveal, degrading to a cross-fade"
        )
    }
}

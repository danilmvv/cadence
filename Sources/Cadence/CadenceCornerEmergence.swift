import SwiftUI
import CadenceCore
import CadenceMotion

/// Публичный вход в эффект `cornerEmergence`: элемент вытекает из
/// физического угла экрана.
///
/// Симметрична `CadenceWaitingIndicator` и `CadenceTaskSuccessIndicator` —
/// собирает контекст из среды и отдаёт решение
/// `resolve(.summoned(from:), in:)`, не принимая его сама. Отличие одно:
/// событие здесь из `SignatureInteraction`, то есть применить эффект
/// случайно нельзя — тип события заперт за отдельным перечислением.
///
/// Вью обязана занимать окно целиком, иначе «угол экрана» окажется углом
/// ближайшего контейнера. Типовое использование — оверлей на корневой вью:
///
/// ```swift
/// content.overlay {
///     CadenceCornerEmergence(from: .topTrailing, isPresented: isSyncing) {
///         Label("Syncing", systemImage: "arrow.triangle.2.circlepath")
///     }
///     .ignoresSafeArea()
/// }
/// ```
///
/// Уместно: статусные уведомления системного вида, индикаторы фоновых
/// процессов. Неуместно: основная навигация и модальные экраны с
/// контентом — см. секцию 6 спеки. Основание приёма — [C] в части
/// соответствия системному языку iOS 26 и [D] в части самого приёма:
/// решение эстетическое, эмпирической базы под ним нет.
public struct CadenceCornerEmergence<Content: View>: View {
    private let corner: ScreenCorner
    private let isPresented: Bool
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cadenceContextOverride) private var override

    /// - Parameters:
    ///   - corner: угол устройства, из которого выходит элемент.
    ///   - isPresented: показан ли элемент. Хаптик играет на переход в
    ///     `true`: уход элемента — не событие, о котором надо сообщать
    ///     тактильно.
    ///   - content: содержимое элемента. Обрамление рисует Cadence.
    public init(
        from corner: ScreenCorner,
        isPresented: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.corner = corner
        self.isPresented = isPresented
        self.content = content()
    }

    public var body: some View {
        let context = override ?? CadenceContext.make(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            lowPower: PowerState.shared.isLowPower,
            scenePhase: scenePhase,
            hapticsAvailable: CadenceRuntime.shared.hapticsAvailable
        )
        let plan = resolve(.summoned(from: corner), in: context)

        Group {
            if let motion = plan.motion {
                CadenceCornerReveal(
                    spec: motion,
                    isPresented: isPresented,
                    // Единственное место, где деградация зависит не от вида
                    // движения, а от контекста напрямую: прозрачность —
                    // свойство материала, и резолвер о материалах не знает.
                    isOpaque: context.reduceTransparency
                ) {
                    content
                }
            } else {
                EmptyView()
            }
        }
        .onChange(of: isPresented) {
            guard isPresented, let haptic = plan.haptic else { return }
            CadenceRuntime.shared.scheduler.fire(haptic)
        }
    }
}

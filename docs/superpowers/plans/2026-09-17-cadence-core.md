# Cadence Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Построить работающее ядро тулкита Cadence — словарь, хаптик-движок, чистый резолвер «событие → план обратной связи», три workhorse-эффекта и каталог-приложение, на котором тактильная часть проверяется руками.

**Architecture:** Четыре SPM-модуля деревом без циклов. `CadenceCore` — чистый Swift без SwiftUI: словарь плюс резолвер, принимающий решения. `CadenceHaptics` и `CadenceMotion` — исполнители, каждый зависит только от Core. `Cadence` — тонкая SwiftUI-склейка, читающая среду и применяющая план. Правила ресерча живут в резолвере и проверяются юнит-тестами.

**Tech Stack:** Swift 6.3.2, SwiftUI, iOS 26.0+, Swift Testing, CoreHaptics, SPM.

**Spec:** `docs/superpowers/specs/2026-09-17-cadence-design.md`

## Global Constraints

- `swift-tools-version: 6.3`, `platforms: [.iOS(.v26)]`.
- Тесты и сборка: `xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`. Проверено на этой машине; `swift test` не работает, потому что пакет iOS-only.
- `CadenceCore` **не импортирует SwiftUI и UIKit**. Нарушение этого — провал задачи.
- Код, имена символов, DocC — английский. Комментарии, объясняющие «почему», — русский. Спека и ресерч — русский.
- Никаких голых `try?` на путях отказа. Логирование через `OSLog`, категории `motion`, `haptics`, `resolver`.
- Числа длительностей берутся только из `MotionBudget` либо из значений, записанных в `docs/research/01-timing.md`. Литерал длительности, которого нет в ресерче, — провал ревью.
- Каждый коммит: `git add <конкретные файлы>`, никаких `git add -A`.

## Отклонения от спеки, принятые при планировании

1. **Резолвер переезжает из `Cadence` в `CadenceCore`.** Он чистый и зависит только от словаря, который уже живёт в Core. Так правила тестируются без SwiftUI, а `Cadence` остаётся тонкой склейкой. Тесты правил — в `CadenceCoreTests`, а не в `CadenceTests`.
2. **`MotionSpec` получает поле `delay`.** Без него нельзя выразить каскад `contentArrival`, который спека требует ограничивать.
3. **Правило «план не пуст при reduceMotion» переформулировано.** В исходной формулировке оно противоречило `waiting` короче секунды, который обязан быть пустым. Корректная формулировка: *reduce motion не опустошает план, который был непуст в стандартном контексте.*

## File Structure

| Файл | Ответственность |
|---|---|
| `Package.swift` | четыре таргета, три тест-таргета |
| `Sources/CadenceCore/Tier.swift` | ось частоты |
| `Sources/CadenceCore/ChangeClass.swift` | ось характера изменения |
| `Sources/CadenceCore/MotionBudget.swift` | бюджеты и `limit(for:)` |
| `Sources/CadenceCore/MotionSpec.swift` | описание движения, `Curve`, `MotionKind`, `ScreenCorner` |
| `Sources/CadenceCore/HapticSpec.swift` | `HapticPattern`, `HapticSpec` |
| `Sources/CadenceCore/FeedbackPlan.swift` | результат резолвера |
| `Sources/CadenceCore/CadenceContext.swift` | снимок среды |
| `Sources/CadenceCore/Interactions.swift` | `RoutineInteraction`, `SignatureInteraction` |
| `Sources/CadenceCore/Resolver.swift` | таблица соответствий и деградация |
| `Sources/CadenceCore/Duration+Seconds.swift` | перевод в `Double` |
| `Sources/CadenceHaptics/HapticOutput.swift` | протокол вывода |
| `Sources/CadenceHaptics/HapticScheduler.swift` | троттлинг |
| `Sources/CadenceHaptics/CoreHapticsOutput.swift` | движок, жизненный цикл, fallback |
| `Sources/CadenceMotion/MotionSpec+Animation.swift` | `MotionSpec` → SwiftUI `Animation` |
| `Sources/CadenceMotion/MotionKindModifiers.swift` | `MotionKind` → визуальный эффект |
| `Sources/Cadence/EnvironmentBridge.swift` | среда → `CadenceContext` |
| `Sources/Cadence/CadenceModifier.swift` | публичные `.cadence(_:trigger:)` |
| `Catalog/` | демо-приложение |

---

### Task 1: Ресерч-корпус

Первым, потому что задача 3 берёт из него числа. Без него константы в `MotionBudget` будут взяты с потолка, а это ровно то, чего проект избегает.

**Files:**
- Create: `docs/research/00-method.md`
- Create: `docs/research/01-timing.md`
- Create: `docs/research/02-feedback.md`
- Create: `docs/research/03-haptics.md`
- Create: `docs/research/04-accessibility.md`
- Create: `docs/research/05-novelty.md`
- Create: `docs/research/sources.md`

**Interfaces:**
- Consumes: ничего.
- Produces: числовые значения и грейды, на которые ссылаются задачи 3, 5, 6 и 7. Конкретно `01-timing.md` обязан содержать строки «100 мс», «300 мс», «400 мс», «1 с», «10 с» с указанием источника и грейда.

- [ ] **Step 1: Написать `00-method.md`**

Содержит таблицу грейдов A/B/C/D дословно из спеки, правило приёмки («workhorse не принимается слабее B; signature может стоять на C и D, но тогда это написано прямым текстом») и правило разрешения противоречий: при конфликте источников выигрывает более высокий грейд; при равных грейдах побеждает Apple HIG, потому что тулкит живёт внутри iOS и консистентность с системой важнее локального оптимума.

- [ ] **Step 2: Написать `01-timing.md`**

Обязательное содержание, каждое утверждение с грейдом и источником:

```
Порог 0.1 с — отклик воспринимается мгновенным, отдельная обратная связь не нужна. [A]
  Miller 1968; Card et al. 1991; Nielsen, Response Times: The 3 Important Limits.
  → MotionBudget.immediate = 100 мс, класс .direct

Порог 1 с — поток мысли не прерывается, но задержка заметна, нужен отклик. [A]
  Те же источники.
  → waitingState: до 1 с не показывать индикатор

Порог 10 с — предел удержания внимания, нужен детерминированный прогресс с отменой. [A]
  Те же источники.
  → waitingState: свыше 10 с прогресс вместо скелетона

Диапазон 100–500 мс для большинства анимаций; анимации чаще слишком длинные. [B]
  NN/g, Executing UX Animations: Duration and Motion Characteristics.

Заметная смена экрана — 200–300 мс. [B] → MotionBudget.transition = 300 мс, класс .screen
Крупное перемещение — до 400 мс. [B] → MotionBudget.journey = 400 мс, класс .journey
На 500 мс анимация начинает восприниматься как затянутая. [B]
Уход быстрее прихода: 200–250 мс против 300 мс. [B]
Линейное движение выглядит неестественно; вход — ease-out, выход — ease-in. [B]
```

- [ ] **Step 3: Написать `02-feedback.md`, `03-haptics.md`, `04-accessibility.md`, `05-novelty.md`**

`02-feedback.md`: определение микроинтеракции как пары «триггер — отклик» [B]; обратная связь должна сообщать статус, успех либо неуспех, предупреждение о последствиях, возможность исправить ошибку [B].

`03-haptics.md`: хаптика достоверно помогает там, где визуальная обратная связь запаздывает или недоступна, и не даёт выигрыша в простом вводе цифр и тапе по мишени [C]; системные хаптики следует использовать консистентно с системой [B]; многие полагаются на хаптику, когда не видят экран, поэтому она дополняет визуал, а не заменяет его [B]. Вывод для кода: хаптик только вместе с визуальным изменением, троттлинг обязателен.

`04-accessibility.md`: WCAG 2.3.3 требует механизма отключения неосновной анимации, запускаемой взаимодействием [B]; вестибулярные реакции — тошнота, головокружение, дезориентация [B]. Вывод: reduce motion подменяет движение кросс-фейдом, а не удаляет обратную связь.

`05-novelty.md`: зависимость «число показов → симпатия» имеет форму перевёрнутой U, привыкание сменяется пресыщением [C]; частота показа — ключевой фактор решения, анимировать ли вообще [C]. Вывод: `Tier` как ось и запертость signature за отдельным типом.

- [ ] **Step 4: Написать `sources.md`**

Библиография со ссылками и грейдами. Обязателен раздел «Не подтверждено», куда попадают ходовые цифры без прослеживаемого первоисточника, как минимум: «рост удовлетворённости на 30% по данным NN/g», «на 12% быстрее выполнение задач», «92% пользователей считают автоанимации раздражающими», «скелетоны воспринимаются на 30% быстрее». Для каждой — строка о том, что первоисточник не найден.

- [ ] **Step 5: Проверить самому себе**

Прогнать глазами по списку из восьми эффектов спеки: у каждого есть грейд и раздел, откуда он берётся. Проверить, что `01-timing.md` содержит все пять числовых порогов из шага 2.

- [ ] **Step 6: Commit**

```bash
git add docs/research
git commit -m "Ресерч-корпус: пороги, хаптика, доступность, новизна

Числа с грейдами силы доказательства и разделом неподтверждённых цифр,
чтобы они не вернулись позже как аргумент."
```

---

### Task 2: Скелет пакета и зелёный конвейер тестов

Отдельной задачей, потому что тулчейн надо проверить до того, как в него поедет настоящий код. Проверено на этой машине: схема называется как пакет, `swift test` не применим.

**Files:**
- Create: `Package.swift`
- Create: `Sources/CadenceCore/Tier.swift`
- Create: `Sources/CadenceHaptics/Placeholder.swift`
- Create: `Sources/CadenceMotion/Placeholder.swift`
- Create: `Sources/Cadence/Placeholder.swift`
- Test: `Tests/CadenceCoreTests/TierTests.swift`

**Interfaces:**
- Consumes: ничего.
- Produces: `public enum Tier: Sendable, CaseIterable { case workhorse, accent, signature }` — используется задачами 3, 5, 6.

- [ ] **Step 1: Написать падающий тест**

```swift
// Tests/CadenceCoreTests/TierTests.swift
import Testing
@testable import CadenceCore

@Test func tierCoversThreeFrequencyClasses() {
    #expect(Tier.allCases.count == 3)
}
```

- [ ] **Step 2: Убедиться, что тест не собирается**

Выполнить:
```bash
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: провал — нет `Package.swift`, схема `Cadence` не найдена.

- [ ] **Step 3: Написать `Package.swift`**

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Cadence",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "Cadence", targets: ["Cadence"]),
        .library(name: "CadenceHaptics", targets: ["CadenceHaptics"]),
    ],
    targets: [
        .target(name: "CadenceCore"),
        .target(name: "CadenceHaptics", dependencies: ["CadenceCore"]),
        .target(name: "CadenceMotion", dependencies: ["CadenceCore"]),
        .target(name: "Cadence", dependencies: ["CadenceCore", "CadenceHaptics", "CadenceMotion"]),
        .testTarget(name: "CadenceCoreTests", dependencies: ["CadenceCore"]),
        .testTarget(name: "CadenceMotionTests", dependencies: ["CadenceMotion"]),
        .testTarget(name: "CadenceTests", dependencies: ["Cadence"]),
    ]
)
```

- [ ] **Step 4: Написать минимальное содержимое таргетов**

```swift
// Sources/CadenceCore/Tier.swift

/// Частота, с которой эффект уместен. Управляет строгостью опт-ина,
/// но НЕ длительностью — за длительность отвечает `ChangeClass`.
public enum Tier: Sendable, CaseIterable, Equatable {
    /// Сотни раз за сессию.
    case workhorse
    /// Единицы раз за сессию.
    case accent
    /// Раз в сессию и реже. Только по явному опт-ину.
    case signature
}
```

Три файла-заглушки, чтобы таргеты собрались:
```swift
// Sources/CadenceHaptics/Placeholder.swift
// Удаляется в задаче 4.
enum CadenceHapticsPlaceholder {}
```
```swift
// Sources/CadenceMotion/Placeholder.swift
// Удаляется в задаче 7.
enum CadenceMotionPlaceholder {}
```
```swift
// Sources/Cadence/Placeholder.swift
// Удаляется в задаче 8.
enum CadencePlaceholder {}
```

Тест-таргеты `CadenceMotionTests` и `CadenceTests` должны содержать по файлу, иначе сборка ругается:
```swift
// Tests/CadenceMotionTests/SmokeTests.swift
import Testing
@testable import CadenceMotion

@Test func moduleLinks() { #expect(true) }
```
```swift
// Tests/CadenceTests/SmokeTests.swift
import Testing
@testable import Cadence

@Test func moduleLinks() { #expect(true) }
```

- [ ] **Step 5: Прогнать тесты**

```bash
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: `** TEST SUCCEEDED **`, три теста прошли.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "Скелет пакета: четыре модуля, зелёный прогон на iOS 26.5"
```

---

### Task 3: Словарь CadenceCore

**Files:**
- Create: `Sources/CadenceCore/ChangeClass.swift`
- Create: `Sources/CadenceCore/MotionBudget.swift`
- Create: `Sources/CadenceCore/MotionSpec.swift`
- Create: `Sources/CadenceCore/HapticSpec.swift`
- Create: `Sources/CadenceCore/FeedbackPlan.swift`
- Create: `Sources/CadenceCore/CadenceContext.swift`
- Create: `Sources/CadenceCore/Duration+Seconds.swift`
- Test: `Tests/CadenceCoreTests/BudgetTests.swift`

**Interfaces:**
- Consumes: `Tier` из задачи 2.
- Produces: типы, которыми пользуются все последующие задачи —
  `ChangeClass`, `MotionBudget.limit(for:) -> Duration?`,
  `MotionSpec(duration:delay:curve:change:kind:)` с `var fitsBudget: Bool`,
  `Curve`, `MotionKind`, `ScreenCorner`,
  `HapticPattern`, `HapticSpec(pattern:minimumInterval:)`,
  `FeedbackPlan(motion:haptic:tier:)` с `var isEmpty: Bool`,
  `CadenceContext` с полями `reduceMotion`, `reduceTransparency`, `lowPower`, `hapticsAvailable`, `sceneActive` и `static let standard`,
  `Duration.timeInterval -> Double`.

- [ ] **Step 1: Написать падающие тесты**

```swift
// Tests/CadenceCoreTests/BudgetTests.swift
import Testing
@testable import CadenceCore

@Test func budgetsMatchResearchNumbers() {
    #expect(MotionBudget.immediate == .milliseconds(100))
    #expect(MotionBudget.transition == .milliseconds(300))
    #expect(MotionBudget.journey == .milliseconds(400))
}

@Test func persistentChangeHasNoBudget() {
    #expect(MotionBudget.limit(for: .persistent) == nil)
}

@Test(arguments: [
    (ChangeClass.direct, Duration.milliseconds(100)),
    (ChangeClass.screen, Duration.milliseconds(300)),
    (ChangeClass.journey, Duration.milliseconds(400)),
])
func transientChangesHaveBudget(change: ChangeClass, expected: Duration) {
    #expect(MotionBudget.limit(for: change) == expected)
}

@Test func directMotionLongerThanImmediateDoesNotFit() {
    let spec = MotionSpec(
        duration: .milliseconds(150), curve: .easeOut,
        change: .direct, kind: .scale(to: 0.96)
    )
    #expect(spec.fitsBudget == false)
}

@Test func persistentMotionAlwaysFits() {
    let spec = MotionSpec(
        duration: .seconds(30), curve: .easeInOut,
        change: .persistent, kind: .shimmer
    )
    #expect(spec.fitsBudget)
}

@Test func durationConvertsToSeconds() {
    #expect(abs(Duration.milliseconds(250).timeInterval - 0.25) < 0.0001)
}
```

- [ ] **Step 2: Прогнать, убедиться в провале компиляции**

```bash
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: `cannot find 'MotionBudget' in scope` и аналогичные.

- [ ] **Step 3: Написать типы**

```swift
// Sources/CadenceCore/ChangeClass.swift

/// Характер изменения. Определяет бюджет длительности.
/// Ортогонален `Tier`: частый эффект может быть медленным изменением экрана.
public enum ChangeClass: Sendable, CaseIterable, Equatable {
    /// Прямое манипулирование объектом: нажатие, перетаскивание.
    case direct
    /// Заметное изменение на экране: появление контента, модалка.
    case screen
    /// Крупное перемещение через экран.
    case journey
    /// Длящееся состояние, а не переход: скелетон загрузки.
    case persistent
}
```

```swift
// Sources/CadenceCore/MotionBudget.swift

/// Бюджеты длительности. Значения и источники — docs/research/01-timing.md.
public enum MotionBudget {
    /// Порог мгновенности: ниже него отклик неотличим от прямого манипулирования. [A]
    public static let immediate: Duration = .milliseconds(100)
    /// Заметная смена экрана. [B]
    public static let transition: Duration = .milliseconds(300)
    /// Верхняя граница для крупных перемещений. [B]
    public static let journey: Duration = .milliseconds(400)

    /// Предел для класса изменения. `nil` означает, что бюджет неприменим:
    /// длящееся состояние живёт столько, сколько идёт работа.
    public static func limit(for change: ChangeClass) -> Duration? {
        switch change {
        case .direct: immediate
        case .screen: transition
        case .journey: journey
        case .persistent: nil
        }
    }
}
```

```swift
// Sources/CadenceCore/MotionSpec.swift

public enum Curve: Sendable, Equatable, Hashable {
    case easeIn
    case easeOut
    case easeInOut
    case spring(response: Double, damping: Double)
}

/// Угол экрана. Свой тип, а не SwiftUI `Edge`: эффект привязан к радиусу угла,
/// и Core не должен зависеть от SwiftUI.
public enum ScreenCorner: Sendable, Equatable, Hashable, CaseIterable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
}

/// Декларативное описание движения. Не содержит вью — благодаря этому
/// резолвер остаётся чистым и тестируется без SwiftUI.
public enum MotionKind: Sendable, Equatable, Hashable {
    // Модификаторное семейство: накладывается поверх вью вызывающей стороны.

    /// Cadence даёт только тайминг, кривую и хаптик; что именно движется,
    /// решает приложение. Нужен там, где геометрию знает только оно —
    /// например, индикатор выбранного сегмента.
    case timingOnly
    case scale(to: Double)
    case fade
    case shake(amplitude: Double)

    // Видовое семейство: Cadence обязан нарисовать вью сам.
    case shimmer
    case progress
    case drawOn

    // Требуют шейдера или стекла. Реализуются вторым планом.
    case disintegrate
    case cornerReveal(corner: ScreenCorner)
}

public struct MotionSpec: Sendable, Equatable, Hashable {
    public var duration: Duration
    public var delay: Duration
    public var curve: Curve
    public var change: ChangeClass
    public var kind: MotionKind

    public init(
        duration: Duration,
        delay: Duration = .zero,
        curve: Curve,
        change: ChangeClass,
        kind: MotionKind
    ) {
        self.duration = duration
        self.delay = delay
        self.curve = curve
        self.change = change
        self.kind = kind
    }

    /// Укладывается ли длительность в бюджет своего класса изменения.
    public var fitsBudget: Bool {
        guard let limit = MotionBudget.limit(for: change) else { return true }
        return duration <= limit
    }
}
```

```swift
// Sources/CadenceCore/HapticSpec.swift

public enum HapticPattern: Sendable, Equatable, Hashable {
    case impactLight
    case impactMedium
    case selection
    case success
    case warning
    case error
    /// Затухающая continuous-фаза. Используется signature-эффектами.
    case decayingRumble(duration: Duration)
}

public struct HapticSpec: Sendable, Equatable, Hashable {
    public var pattern: HapticPattern
    /// Минимальный интервал между повторами одного паттерна.
    /// Без него selection на скролле даёт непрерывное жужжание.
    public var minimumInterval: Duration

    public init(pattern: HapticPattern, minimumInterval: Duration) {
        self.pattern = pattern
        self.minimumInterval = minimumInterval
    }
}
```

```swift
// Sources/CadenceCore/FeedbackPlan.swift

/// Результат резолвера: что показать и что дать почувствовать.
public struct FeedbackPlan: Sendable, Equatable {
    public var motion: MotionSpec?
    public var haptic: HapticSpec?
    public var tier: Tier

    public init(motion: MotionSpec?, haptic: HapticSpec?, tier: Tier) {
        self.motion = motion
        self.haptic = haptic
        self.tier = tier
    }

    public var isEmpty: Bool { motion == nil && haptic == nil }
}
```

```swift
// Sources/CadenceCore/CadenceContext.swift

/// Снимок среды, в которой принимается решение. Значение, а не ссылка:
/// резолвер обязан быть чистым.
public struct CadenceContext: Sendable, Equatable {
    public var reduceMotion: Bool
    public var reduceTransparency: Bool
    public var lowPower: Bool
    public var hapticsAvailable: Bool
    public var sceneActive: Bool

    public init(
        reduceMotion: Bool = false,
        reduceTransparency: Bool = false,
        lowPower: Bool = false,
        hapticsAvailable: Bool = true,
        sceneActive: Bool = true
    ) {
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
        self.lowPower = lowPower
        self.hapticsAvailable = hapticsAvailable
        self.sceneActive = sceneActive
    }

    /// Обычное устройство без ограничений.
    public static let standard = CadenceContext()
}
```

```swift
// Sources/CadenceCore/Duration+Seconds.swift

public extension Duration {
    /// Секунды как `Double`. Нужно на границе со SwiftUI `Animation`.
    var timeInterval: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
```

- [ ] **Step 4: Прогнать тесты**

```bash
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: `** TEST SUCCEEDED **`, все тесты из шага 1 зелёные.

- [ ] **Step 5: Commit**

```bash
git add Sources/CadenceCore Tests/CadenceCoreTests
git commit -m "Словарь Core: две оси, бюджеты, спеки движения и хаптика

Бюджеты берут числа из docs/research/01-timing.md. ChangeClass отделён
от Tier, чтобы частота и длительность не склеивались."
```

---

### Task 4: Хаптик-движок и троттлинг

**Files:**
- Create: `Sources/CadenceHaptics/HapticOutput.swift`
- Create: `Sources/CadenceHaptics/HapticScheduler.swift`
- Create: `Sources/CadenceHaptics/CoreHapticsOutput.swift`
- Delete: `Sources/CadenceHaptics/Placeholder.swift`
- Create: `Tests/CadenceHapticsTests/HapticSchedulerTests.swift`
- Modify: `Package.swift` — добавить тест-таргет `CadenceHapticsTests`

**Interfaces:**
- Consumes: `HapticPattern`, `HapticSpec`, `Duration.timeInterval` из задачи 3.
- Produces:
  `@MainActor protocol HapticOutput: AnyObject { func play(_ pattern: HapticPattern) }`;
  `@MainActor final class HapticScheduler` с `init(output:now:)` и `@discardableResult func fire(_ spec: HapticSpec) -> Bool`;
  `@MainActor final class CoreHapticsOutput: HapticOutput` с `let isAvailable: Bool`.

- [ ] **Step 1: Написать падающие тесты планировщика**

```swift
// Tests/CadenceHapticsTests/HapticSchedulerTests.swift
import Testing
import CadenceCore
@testable import CadenceHaptics

@MainActor
private final class SpyOutput: HapticOutput {
    private(set) var played: [HapticPattern] = []
    func play(_ pattern: HapticPattern) { played.append(pattern) }
}

@MainActor
@Test func throttleCollapsesRapidRepeats() {
    let spy = SpyOutput()
    var moment = ContinuousClock.now
    let scheduler = HapticScheduler(output: spy, now: { moment })
    let spec = HapticSpec(pattern: .selection, minimumInterval: .milliseconds(80))

    #expect(scheduler.fire(spec) == true)

    moment = moment.advanced(by: .milliseconds(10))
    #expect(scheduler.fire(spec) == false, "повтор внутри интервала обязан быть проглочен")

    moment = moment.advanced(by: .milliseconds(100))
    #expect(scheduler.fire(spec) == true)

    #expect(spy.played == [.selection, .selection])
}

@MainActor
@Test func patternsAreThrottledIndependently() {
    let spy = SpyOutput()
    var moment = ContinuousClock.now
    let scheduler = HapticScheduler(output: spy, now: { moment })

    #expect(scheduler.fire(HapticSpec(pattern: .selection, minimumInterval: .milliseconds(80))))
    moment = moment.advanced(by: .milliseconds(5))
    #expect(scheduler.fire(HapticSpec(pattern: .success, minimumInterval: .milliseconds(80))))

    #expect(spy.played == [.selection, .success])
}

@MainActor
@Test func firstFireOfAPatternAlwaysPasses() {
    let spy = SpyOutput()
    let scheduler = HapticScheduler(output: spy)
    #expect(scheduler.fire(HapticSpec(pattern: .error, minimumInterval: .seconds(10))))
    #expect(spy.played == [.error])
}
```

- [ ] **Step 2: Прогнать, убедиться в провале**

```bash
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: `cannot find 'HapticScheduler' in scope`.

- [ ] **Step 3: Добавить тест-таргет в `Package.swift`**

В массив `targets` добавить:
```swift
        .testTarget(name: "CadenceHapticsTests", dependencies: ["CadenceHaptics"]),
```

- [ ] **Step 4: Написать протокол и планировщик**

```swift
// Sources/CadenceHaptics/HapticOutput.swift
import CadenceCore

/// Куда уходит команда воспроизведения. Протокол существует ради тестов:
/// планировщик проверяется без железа, которого нет в симуляторе.
@MainActor
public protocol HapticOutput: AnyObject {
    func play(_ pattern: HapticPattern)
}
```

```swift
// Sources/CadenceHaptics/HapticScheduler.swift
import CadenceCore

/// Пропускает хаптики не чаще, чем разрешает спека.
///
/// Троттлинг не украшение: `selectionChanged` на скролле без ограничения
/// частоты даёт непрерывное жужжание — типовая причина, по которой люди
/// отключают тактильную обратную связь целиком.
@MainActor
public final class HapticScheduler {
    private let output: HapticOutput
    private let now: () -> ContinuousClock.Instant
    private var lastFired: [HapticPattern: ContinuousClock.Instant] = [:]

    public init(
        output: HapticOutput,
        now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.output = output
        self.now = now
    }

    /// Возвращает `true`, если хаптик действительно сыграл.
    /// Каждый паттерн троттлится независимо от остальных.
    @discardableResult
    public func fire(_ spec: HapticSpec) -> Bool {
        let moment = now()
        if let last = lastFired[spec.pattern], moment - last < spec.minimumInterval {
            return false
        }
        lastFired[spec.pattern] = moment
        output.play(spec.pattern)
        return true
    }
}
```

- [ ] **Step 5: Прогнать тесты планировщика**

```bash
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: три теста планировщика зелёные.

- [ ] **Step 6: Написать тест живучести на железе без Taptic Engine**

Симулятор не имеет Taptic Engine, поэтому этот тест реально проверяет ветку отказа — ту самую, которая роняет приложения на iPad.

```swift
// Tests/CadenceHapticsTests/CoreHapticsOutputTests.swift
import Testing
import CadenceCore
@testable import CadenceHaptics

@MainActor
@Test func outputSurvivesHardwareWithoutHaptics() {
    let output = CoreHapticsOutput()
    // В симуляторе Taptic Engine отсутствует.
    #expect(output.isAvailable == false)
    // Главное: не падает и не бросает.
    output.play(.selection)
    output.play(.success)
    output.play(.decayingRumble(duration: .milliseconds(900)))
}
```

- [ ] **Step 7: Написать `CoreHapticsOutput`**

```swift
// Sources/CadenceHaptics/CoreHapticsOutput.swift
import CoreHaptics
import OSLog
import UIKit
import CadenceCore

/// Воспроизведение через CoreHaptics с падением на `UIFeedbackGenerator`.
@MainActor
public final class CoreHapticsOutput: HapticOutput {
    private static let log = Logger(subsystem: "Cadence", category: "haptics")

    /// Есть ли на устройстве Taptic Engine. Если нет — хаптик тихо не играет,
    /// а движение сохраняется: обратная связь не должна исчезать целиком.
    public let isAvailable: Bool
    private var engine: CHHapticEngine?

    public init() {
        isAvailable = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard isAvailable else {
            Self.log.notice("Нет Taptic Engine: хаптик отключён, движение сохраняется")
            return
        }
        do {
            let engine = try CHHapticEngine()
            // Движок глохнет при уходе в фон и после системного reset.
            // Без обработчиков вибрация однажды пропадает до перезапуска.
            engine.resetHandler = { [weak self] in
                Task { @MainActor in self?.restart(after: "reset") }
            }
            engine.stoppedHandler = { [weak self] reason in
                Self.log.notice("Движок остановлен, причина \(reason.rawValue)")
                Task { @MainActor in self?.restart(after: "stopped") }
            }
            try engine.start()
            self.engine = engine
        } catch {
            Self.log.error("CHHapticEngine не поднялся: \(error.localizedDescription)")
            engine = nil
        }
    }

    public func play(_ pattern: HapticPattern) {
        guard isAvailable, let engine else {
            fallback(pattern)
            return
        }
        do {
            let player = try engine.makePlayer(with: try Self.corePattern(for: pattern))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            Self.log.error("Воспроизведение не удалось: \(error.localizedDescription)")
            fallback(pattern)
        }
    }

    private func restart(after reason: String) {
        do {
            try engine?.start()
        } catch {
            Self.log.error("Перезапуск после \(reason) не удался: \(error.localizedDescription)")
        }
    }

    // MARK: - Паттерны

    private static func corePattern(for pattern: HapticPattern) throws -> CHHapticPattern {
        switch pattern {
        case .impactLight:
            try CHHapticPattern(events: [transient(at: 0, intensity: 0.4, sharpness: 0.7)], parameters: [])
        case .impactMedium:
            try CHHapticPattern(events: [transient(at: 0, intensity: 0.7, sharpness: 0.5)], parameters: [])
        case .selection:
            try CHHapticPattern(events: [transient(at: 0, intensity: 0.35, sharpness: 0.8)], parameters: [])
        case .success:
            try CHHapticPattern(events: [
                transient(at: 0, intensity: 0.5, sharpness: 0.6),
                transient(at: 0.11, intensity: 0.8, sharpness: 0.8),
            ], parameters: [])
        case .warning:
            try CHHapticPattern(events: [
                transient(at: 0, intensity: 0.7, sharpness: 0.9),
                transient(at: 0.13, intensity: 0.7, sharpness: 0.9),
            ], parameters: [])
        case .error:
            try CHHapticPattern(events: (0..<3).map {
                transient(at: Double($0) * 0.11, intensity: 0.85, sharpness: 0.95)
            }, parameters: [])
        case .decayingRumble(let duration):
            let seconds = duration.timeInterval
            return try CHHapticPattern(
                events: [continuous(at: 0, duration: seconds, intensity: 0.8, sharpness: 0.25)],
                parameterCurves: [
                    CHHapticParameterCurve(
                        parameterID: .hapticIntensityControl,
                        controlPoints: [
                            .init(relativeTime: 0, value: 1.0),
                            .init(relativeTime: seconds, value: 0.0),
                        ],
                        relativeTime: 0
                    )
                ]
            )
        }
    }

    private static func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time)
    }

    private static func continuous(
        at time: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float
    ) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time, duration: duration)
    }

    private func fallback(_ pattern: HapticPattern) {
        guard isAvailable else { return }
        switch pattern {
        case .impactLight:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .impactMedium, .decayingRumble:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
```

- [ ] **Step 8: Удалить заглушку и прогнать всё**

```bash
rm Sources/CadenceHaptics/Placeholder.swift
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: `** TEST SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add Package.swift Sources/CadenceHaptics Tests/CadenceHapticsTests
git rm --cached Sources/CadenceHaptics/Placeholder.swift 2>/dev/null || true
git commit -m "Хаптики: троттлинг, жизненный цикл движка, деградация без железа

Планировщик тестируется через подставной вывод и подставные часы.
Тест на устройстве без Taptic Engine реально исполняется в симуляторе."
```

---

### Task 5: Резолвер повседневных событий и правила ресерча как тесты

Сердце проекта. Здесь ресерч превращается из текста в исполняемые ограничения.

**Files:**
- Create: `Sources/CadenceCore/Interactions.swift`
- Create: `Sources/CadenceCore/Resolver.swift`
- Test: `Tests/CadenceCoreTests/ResolverRuleTests.swift`

**Interfaces:**
- Consumes: весь словарь из задачи 3.
- Produces:
  `enum RoutineInteraction: Sendable, Equatable` со случаями `pressed`, `selectionChanged`, `contentArrived(staggerIndex: Int)`, `waiting(elapsed: Duration)`, `validationFailed`, `taskSucceeded`;
  `enum SignatureInteraction: Sendable, Equatable` со случаями `destroyed`, `summoned(from: ScreenCorner)` (наполняется в задаче 6);
  `public func resolve(_ event: RoutineInteraction, in context: CadenceContext) -> FeedbackPlan`;
  внутренние `baseline(for:)`, `degrade(_:in:)`, `staggerDelay(for:)`, `waitingPlan(elapsed:)`.

- [ ] **Step 1: Написать падающие тесты правил**

```swift
// Tests/CadenceCoreTests/ResolverRuleTests.swift
import Testing
@testable import CadenceCore

/// Один представитель каждого случая. Свитч ниже исчерпывающий и без `default`:
/// новый случай в enum не скомпилируется, пока его не добавят сюда.
/// Это защита от правила, которое молча перестало проверять часть событий.
let routineCoverage: [RoutineInteraction] = {
    let all: [RoutineInteraction] = [
        .pressed,
        .selectionChanged,
        .contentArrived(staggerIndex: 3),
        .waiting(elapsed: .seconds(2)),
        .validationFailed,
        .taskSucceeded,
    ]
    for event in all {
        switch event {
        case .pressed, .selectionChanged, .contentArrived,
             .waiting, .validationFailed, .taskSucceeded:
            break
        }
    }
    return all
}()

// MARK: - Бюджеты

@Test func everyRoutineMotionFitsItsBudget() {
    for event in routineCoverage {
        guard let motion = resolve(event, in: .standard).motion else { continue }
        #expect(motion.fitsBudget, "\(event): \(motion.duration) не влезает в \(motion.change)")
    }
}

@Test func directMotionNeverExceedsImmediate() {
    for event in routineCoverage {
        guard let motion = resolve(event, in: .standard).motion, motion.change == .direct else { continue }
        #expect(motion.duration <= MotionBudget.immediate)
    }
}

@Test func routineTransitionsNeverExceedJourney() {
    for event in routineCoverage {
        guard let motion = resolve(event, in: .standard).motion else { continue }
        guard motion.change != .persistent else { continue }
        #expect(motion.duration <= MotionBudget.journey, "\(event) длиннее крупного перемещения")
    }
}

// MARK: - Доступность

@Test func reduceMotionSubstitutesRatherThanRemoves() {
    for event in routineCoverage {
        let normal = resolve(event, in: .standard)
        guard !normal.isEmpty else { continue }
        let reduced = resolve(event, in: CadenceContext(reduceMotion: true))
        #expect(!reduced.isEmpty, "\(event): reduce motion опустошил непустой план")
        #expect(reduced.motion != nil, "\(event): движение удалено вместо подмены на кросс-фейд")
        #expect(reduced.motion?.kind == .fade)
    }
}

@Test func motionSurvivesWhenHapticsUnavailable() {
    for event in routineCoverage {
        guard resolve(event, in: .standard).motion != nil else { continue }
        let plan = resolve(event, in: CadenceContext(hapticsAvailable: false))
        #expect(plan.motion != nil, "\(event): без хаптика пропало и движение")
        #expect(plan.haptic == nil)
    }
}

@Test func inactiveSceneSuppressesHapticsOnly() {
    for event in routineCoverage {
        guard resolve(event, in: .standard).motion != nil else { continue }
        let plan = resolve(event, in: CadenceContext(sceneActive: false))
        #expect(plan.haptic == nil)
        #expect(plan.motion != nil)
    }
}

@Test func hapticNeverTravelsWithoutMotion() {
    let contexts: [CadenceContext] = [
        .standard,
        CadenceContext(reduceMotion: true),
        CadenceContext(lowPower: true),
        CadenceContext(hapticsAvailable: false),
        CadenceContext(sceneActive: false),
    ]
    for event in routineCoverage {
        for context in contexts {
            let plan = resolve(event, in: context)
            if plan.haptic != nil {
                #expect(plan.motion != nil, "\(event): хаптик остался единственным носителем")
            }
        }
    }
}

// MARK: - Пороги ожидания

@Test func waitUnderOneSecondShowsNothing() {
    #expect(resolve(.waiting(elapsed: .milliseconds(900)), in: .standard).isEmpty)
}

@Test func waitPastOneSecondShowsSkeleton() {
    let plan = resolve(.waiting(elapsed: .seconds(3)), in: .standard)
    #expect(plan.motion?.kind == .shimmer)
    #expect(plan.motion?.change == .persistent)
}

@Test func waitPastTenSecondsShowsDeterminateProgress() {
    #expect(resolve(.waiting(elapsed: .seconds(12)), in: .standard).motion?.kind == .progress)
}

// MARK: - Каскад

@Test func firstItemHasNoStaggerDelay() {
    #expect(resolve(.contentArrived(staggerIndex: 0), in: .standard).motion?.delay == .zero)
}

@Test func staggerDelayIsCappedAtJourney() {
    #expect(resolve(.contentArrived(staggerIndex: 500), in: .standard).motion?.delay == MotionBudget.journey)
}

// MARK: - Чистота и независимость осей

@Test func resolverIsDeterministic() {
    for event in routineCoverage {
        #expect(resolve(event, in: .standard) == resolve(event, in: .standard))
    }
}

/// Страховка от повторной склейки осей: частый эффект имеет право быть
/// изменением экрана, а не только мгновенным откликом.
@Test func frequencyAndDurationStayIndependent() {
    let plan = resolve(.contentArrived(staggerIndex: 0), in: .standard)
    #expect(plan.tier == .workhorse)
    #expect(plan.motion?.change == .screen)
}
```

- [ ] **Step 2: Прогнать, убедиться в провале**

```bash
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: `cannot find 'resolve' in scope`, `cannot find 'RoutineInteraction' in scope`.

- [ ] **Step 3: Написать типы событий**

```swift
// Sources/CadenceCore/Interactions.swift

/// Повседневные события интерфейса.
///
/// Отдельный тип от `SignatureInteraction` — это основной механизм, которым
/// ресерч влияет на использование: повесить эффект уровня signature на
/// обычное действие не запрещено соглашением, а не компилируется.
public enum RoutineInteraction: Sendable, Equatable {
    /// Палец коснулся интерактивного элемента.
    case pressed
    /// Сменился выбранный элемент: сегмент, таб, значение пикера.
    case selectionChanged
    /// Появился контент. `staggerIndex` — порядковый номер в списке.
    case contentArrived(staggerIndex: Int)
    /// Идёт ожидание. `elapsed` считает вызывающая сторона: резолвер
    /// не должен знать текущее время, иначе он перестаёт быть чистым.
    case waiting(elapsed: Duration)
    /// Ввод не прошёл проверку.
    case validationFailed
    /// Задача завершилась успешно.
    case taskSucceeded
}

/// События, для которых уместны редкие выразительные эффекты.
public enum SignatureInteraction: Sendable, Equatable {
    /// Необратимое удаление.
    case destroyed
    /// Появление из угла экрана.
    case summoned(from: ScreenCorner)
}
```

- [ ] **Step 4: Написать резолвер**

```swift
// Sources/CadenceCore/Resolver.swift

/// Событие плюс среда даёт план обратной связи.
///
/// Чистая функция без сайд-эффектов, без SwiftUI и UIKit. Именно поэтому
/// правила ресерча можно проверить юнит-тестами: см. ResolverRuleTests.
public func resolve(_ event: RoutineInteraction, in context: CadenceContext) -> FeedbackPlan {
    degrade(baseline(for: event), in: context)
}

// MARK: - Таблица соответствий

func baseline(for event: RoutineInteraction) -> FeedbackPlan {
    switch event {
    case .pressed:
        FeedbackPlan(
            motion: MotionSpec(
                duration: MotionBudget.immediate,
                curve: .spring(response: 0.25, damping: 0.8),
                change: .direct,
                kind: .scale(to: 0.96)
            ),
            haptic: HapticSpec(pattern: .impactLight, minimumInterval: .milliseconds(40)),
            tier: .workhorse
        )

    case .selectionChanged:
        FeedbackPlan(
            motion: MotionSpec(
                duration: MotionBudget.immediate,
                curve: .easeInOut,
                change: .direct,
                kind: .timingOnly
            ),
            haptic: HapticSpec(pattern: .selection, minimumInterval: .milliseconds(80)),
            tier: .workhorse
        )

    case .contentArrived(let index):
        FeedbackPlan(
            motion: MotionSpec(
                duration: MotionBudget.transition,
                delay: staggerDelay(for: index),
                curve: .easeOut,
                change: .screen,
                kind: .fade
            ),
            haptic: nil,
            tier: .workhorse
        )

    case .waiting(let elapsed):
        waitingPlan(elapsed: elapsed)

    case .validationFailed:
        FeedbackPlan(
            motion: MotionSpec(
                duration: MotionBudget.transition,
                curve: .easeInOut,
                change: .screen,
                kind: .shake(amplitude: 8)
            ),
            haptic: HapticSpec(pattern: .error, minimumInterval: .milliseconds(500)),
            tier: .accent
        )

    case .taskSucceeded:
        FeedbackPlan(
            motion: MotionSpec(
                duration: .milliseconds(250),
                curve: .easeOut,
                change: .screen,
                kind: .drawOn
            ),
            haptic: HapticSpec(pattern: .success, minimumInterval: .milliseconds(500)),
            tier: .accent
        )
    }
}

/// Каскад появления: шаг 40 мс, суммарная задержка ограничена бюджетом
/// крупного перемещения. Без ограничения последняя ячейка длинного списка
/// ждёт секунды, и это читается как тормоза, а не как анимация.
func staggerDelay(for index: Int) -> Duration {
    guard index > 0 else { return .zero }
    return min(Duration.milliseconds(40) * index, MotionBudget.journey)
}

/// Три порога отклика. Единственное место, где тулкит прямо запрещает
/// показывать индикатор: до секунды он воспринимается мерцанием и делает
/// интерфейс субъективно медленнее, а не быстрее.
func waitingPlan(elapsed: Duration) -> FeedbackPlan {
    guard elapsed >= .seconds(1) else {
        return FeedbackPlan(motion: nil, haptic: nil, tier: .accent)
    }
    let kind: MotionKind = elapsed < .seconds(10) ? .shimmer : .progress
    return FeedbackPlan(
        motion: MotionSpec(
            duration: .milliseconds(1200),
            curve: .easeInOut,
            change: .persistent,
            kind: kind
        ),
        haptic: nil,
        tier: .accent
    )
}

// MARK: - Деградация

/// Порядок важен: сначала подменяем движение, потом решаем судьбу хаптика,
/// иначе можно оставить хаптик без визуального сопровождения.
func degrade(_ plan: FeedbackPlan, in context: CadenceContext) -> FeedbackPlan {
    var plan = plan

    if context.reduceMotion, let motion = plan.motion {
        // Подмена, а не удаление: пользователь всё равно должен понять,
        // что состояние изменилось.
        plan.motion = MotionSpec(
            duration: min(motion.duration, MotionBudget.transition),
            delay: motion.delay,
            curve: .easeInOut,
            change: motion.change,
            kind: .fade
        )
    }

    if context.lowPower, plan.tier == .signature, let motion = plan.motion {
        // Шейдер, считающийся каждый кадр, — неподходящая нагрузка
        // при экономии энергии.
        plan.motion = MotionSpec(
            duration: min(motion.duration, MotionBudget.journey),
            delay: motion.delay,
            curve: .easeOut,
            change: .journey,
            kind: .fade
        )
    }

    if !context.hapticsAvailable || !context.sceneActive {
        plan.haptic = nil
    }

    // Хаптик не может быть единственным носителем информации.
    if plan.motion == nil {
        plan.haptic = nil
    }

    return plan
}
```

- [ ] **Step 5: Прогнать тесты**

```bash
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: все тесты правил зелёные.

- [ ] **Step 6: Проверить, что правило реально ловит нарушение**

Временно поменять в `baseline(for:)` у `.pressed` длительность на `.milliseconds(600)`, прогнать тесты, убедиться, что падают `everyRoutineMotionFitsItsBudget` и `directMotionNeverExceedsImmediate`. Вернуть `MotionBudget.immediate` обратно, прогнать снова — зелено.

Этот шаг обязателен: правило, которое никогда не падало, не является проверкой.

- [ ] **Step 7: Commit**

```bash
git add Sources/CadenceCore/Interactions.swift Sources/CadenceCore/Resolver.swift Tests/CadenceCoreTests/ResolverRuleTests.swift
git commit -m "Резолвер повседневных событий: ресерч как исполняемые правила

Чистая функция событие + среда -> план. Пороги ожидания, каскад с
ограничением, подмена движения при reduce motion. Правила проверяются
тестами, а не декларируются в README."
```

---

### Task 6: Резолвер signature-событий

**Files:**
- Modify: `Sources/CadenceCore/Resolver.swift` — добавить перегрузку `resolve` и `baseline` для `SignatureInteraction`
- Test: `Tests/CadenceCoreTests/SignatureRuleTests.swift`

**Interfaces:**
- Consumes: `SignatureInteraction`, `degrade(_:in:)` из задачи 5.
- Produces: `public func resolve(_ event: SignatureInteraction, in context: CadenceContext) -> FeedbackPlan`.

- [ ] **Step 1: Написать падающие тесты**

```swift
// Tests/CadenceCoreTests/SignatureRuleTests.swift
import Testing
@testable import CadenceCore

/// Исчерпывающий свитч без `default`: новый signature-случай не
/// скомпилируется, пока не добавят образец.
let signatureCoverage: [SignatureInteraction] = {
    let all: [SignatureInteraction] = [.destroyed, .summoned(from: .topTrailing)]
    for event in all {
        switch event {
        case .destroyed, .summoned:
            break
        }
    }
    return all
}()

@Test func signatureEventsAreMarkedSignature() {
    for event in signatureCoverage {
        #expect(resolve(event, in: .standard).tier == .signature)
    }
}

/// Превышать бюджет крупного перемещения разрешено только signature —
/// это и есть плата, за которую они заперты за отдельным типом.
@Test func onlySignatureMayExceedJourney() {
    for event in routineCoverage {
        guard let motion = resolve(event, in: .standard).motion, motion.change != .persistent else { continue }
        #expect(motion.duration <= MotionBudget.journey)
    }
    #expect(resolve(.destroyed, in: .standard).motion!.duration > MotionBudget.journey)
}

@Test func lowPowerClampsSignatureToJourney() {
    for event in signatureCoverage {
        let plan = resolve(event, in: CadenceContext(lowPower: true))
        #expect(plan.motion!.duration <= MotionBudget.journey, "\(event) не ужался при экономии энергии")
        #expect(plan.motion?.kind == .fade, "\(event): дорогой эффект остался при экономии энергии")
    }
}

@Test func signatureSubstitutesUnderReduceMotion() {
    for event in signatureCoverage {
        let plan = resolve(event, in: CadenceContext(reduceMotion: true))
        #expect(plan.motion?.kind == .fade)
        #expect(!plan.isEmpty)
    }
}

@Test func everyCornerResolves() {
    for corner in ScreenCorner.allCases {
        let plan = resolve(.summoned(from: corner), in: .standard)
        #expect(plan.motion?.kind == .cornerReveal(corner: corner))
    }
}

@Test func signatureHapticsAreRateLimited() {
    for event in signatureCoverage {
        let haptic = resolve(event, in: .standard).haptic
        #expect(haptic!.minimumInterval >= .milliseconds(500))
    }
}
```

- [ ] **Step 2: Прогнать, убедиться в провале**

```bash
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: `cannot find an overload for 'resolve' that accepts SignatureInteraction`.

- [ ] **Step 3: Дописать резолвер**

Добавить в конец `Sources/CadenceCore/Resolver.swift`:

```swift
// MARK: - Signature

/// Редкие выразительные события. Отдельная перегрузка, потому что и тип
/// события отдельный: случайно вызвать её на обычном действии нельзя.
public func resolve(_ event: SignatureInteraction, in context: CadenceContext) -> FeedbackPlan {
    degrade(baseline(for: event), in: context)
}

func baseline(for event: SignatureInteraction) -> FeedbackPlan {
    switch event {
    case .destroyed:
        // 900 мс сознательно превышают бюджет крупного перемещения.
        // Основание эстетическое, не эмпирическое — см. docs/research/05-novelty.md,
        // грейд D. Плата за превышение — запертость за отдельным типом.
        FeedbackPlan(
            motion: MotionSpec(
                duration: .milliseconds(900),
                curve: .easeIn,
                change: .journey,
                kind: .disintegrate
            ),
            haptic: HapticSpec(
                pattern: .decayingRumble(duration: .milliseconds(900)),
                minimumInterval: .seconds(1)
            ),
            tier: .signature
        )

    case .summoned(let corner):
        FeedbackPlan(
            motion: MotionSpec(
                duration: .milliseconds(450),
                curve: .spring(response: 0.45, damping: 0.75),
                change: .journey,
                kind: .cornerReveal(corner: corner)
            ),
            haptic: HapticSpec(pattern: .impactMedium, minimumInterval: .milliseconds(500)),
            tier: .signature
        )
    }
}
```

- [ ] **Step 4: Прогнать тесты**

```bash
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Sources/CadenceCore/Resolver.swift Tests/CadenceCoreTests/SignatureRuleTests.swift
git commit -m "Резолвер signature: превышение бюджета разрешено только здесь

Деградация при экономии энергии и reduce motion проверена тестами."
```

---

### Task 7: Рендер движения в CadenceMotion

**Files:**
- Create: `Sources/CadenceMotion/MotionSpec+Animation.swift`
- Create: `Sources/CadenceMotion/MotionKindFamily.swift`
- Create: `Sources/CadenceMotion/ShakeEffect.swift`
- Create: `Sources/CadenceMotion/CadenceMotionModifier.swift`
- Delete: `Sources/CadenceMotion/Placeholder.swift`
- Test: `Tests/CadenceMotionTests/ShakeEffectTests.swift`
- Test: `Tests/CadenceMotionTests/MotionKindFamilyTests.swift`

**Interfaces:**
- Consumes: `MotionSpec`, `MotionKind`, `Curve`, `Duration.timeInterval` из задачи 3.
- Produces:
  `MotionSpec.animation -> Animation`;
  `MotionKind.isModifierFamily -> Bool`;
  `ShakeEffect(amplitude:shakes:)` с `animatableData`;
  `CadenceMotionModifier(spec:phase:)`.

**Замечание о границе.** Виды движения делятся на два семейства. Модификаторные накладываются поверх вью вызывающей стороны. Видовые требуют, чтобы Cadence нарисовал вью сам: скелетон, галочку, полосу прогресса. Эта задача закрывает только модификаторное семейство; видовое — во втором плане. Смешивать их в одном API нельзя, поэтому классификация вынесена в явное свойство и покрыта тестом.

- [ ] **Step 1: Написать падающие тесты**

```swift
// Tests/CadenceMotionTests/ShakeEffectTests.swift
import Testing
import SwiftUI
@testable import CadenceMotion

@Test func shakeIsIdentityAtRest() {
    let effect = ShakeEffect(amplitude: 8, shakes: 0)
    let transform = effect.effectValue(size: CGSize(width: 100, height: 40))
    #expect(transform == ProjectionTransform(.identity))
}

@Test func shakeReturnsToIdentityWhenFinished() {
    let effect = ShakeEffect(amplitude: 8, shakes: 3)
    let transform = effect.effectValue(size: CGSize(width: 100, height: 40))
    #expect(transform == ProjectionTransform(.identity))
}

@Test func shakeDisplacesMidway() {
    let effect = ShakeEffect(amplitude: 8, shakes: 0.25)
    let transform = effect.effectValue(size: CGSize(width: 100, height: 40))
    #expect(transform != ProjectionTransform(.identity))
}

/// Колебание затухает: первый выброс сильнее последнего.
@Test func shakeDecays() {
    func displacement(at shakes: CGFloat) -> CGFloat {
        ShakeEffect(amplitude: 8, shakes: shakes).horizontalDisplacement
    }
    #expect(abs(displacement(at: 0.25)) > abs(displacement(at: 2.25)))
}

@Test func animatableDataTracksShakes() {
    var effect = ShakeEffect(amplitude: 8, shakes: 0)
    effect.animatableData = 1.5
    #expect(effect.shakes == 1.5)
}
```

```swift
// Tests/CadenceMotionTests/MotionKindFamilyTests.swift
import Testing
import CadenceCore
@testable import CadenceMotion

/// Исчерпывающий свитч без `default`: новый вид движения не скомпилируется,
/// пока его не отнесут к семейству явно.
let kindCoverage: [MotionKind] = {
    let all: [MotionKind] = [
        .timingOnly, .scale(to: 0.96), .fade, .shake(amplitude: 8),
        .shimmer, .progress, .drawOn,
        .disintegrate, .cornerReveal(corner: .topTrailing),
    ]
    for kind in all {
        switch kind {
        case .timingOnly, .scale, .fade, .shake,
             .shimmer, .progress, .drawOn,
             .disintegrate, .cornerReveal:
            break
        }
    }
    return all
}()

@Test func everyKindIsClassified() {
    // Классификация тотальна: свойство не падает ни на одном виде.
    for kind in kindCoverage {
        _ = kind.isModifierFamily
    }
}

@Test func modifierFamilyIsExactlyTheOverlayKinds() {
    #expect(MotionKind.timingOnly.isModifierFamily)
    #expect(MotionKind.scale(to: 0.96).isModifierFamily)
    #expect(MotionKind.fade.isModifierFamily)
    #expect(MotionKind.shake(amplitude: 8).isModifierFamily)
    #expect(MotionKind.disintegrate.isModifierFamily)
}

@Test func viewFamilyNeedsCadenceToDrawIt() {
    #expect(MotionKind.shimmer.isModifierFamily == false)
    #expect(MotionKind.progress.isModifierFamily == false)
    #expect(MotionKind.drawOn.isModifierFamily == false)
    #expect(MotionKind.cornerReveal(corner: .topLeading).isModifierFamily == false)
}
```

- [ ] **Step 2: Прогнать, убедиться в провале**

```bash
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: `cannot find 'ShakeEffect' in scope`.

- [ ] **Step 3: Написать перевод спеки в анимацию**

```swift
// Sources/CadenceMotion/MotionSpec+Animation.swift
import SwiftUI
import CadenceCore

public extension MotionSpec {
    /// SwiftUI-анимация, соответствующая спеке. Задержка каскада входит сюда.
    var animation: Animation {
        let seconds = duration.timeInterval
        let base: Animation = switch curve {
        case .easeIn: .easeIn(duration: seconds)
        case .easeOut: .easeOut(duration: seconds)
        case .easeInOut: .easeInOut(duration: seconds)
        case .spring(let response, let damping): .spring(response: response, dampingFraction: damping)
        }
        return delay == .zero ? base : base.delay(delay.timeInterval)
    }
}
```

- [ ] **Step 4: Написать классификацию семейств**

```swift
// Sources/CadenceMotion/MotionKindFamily.swift
import CadenceCore

public extension MotionKind {
    /// Накладывается ли вид поверх вью вызывающей стороны.
    ///
    /// `false` означает, что Cadence обязан нарисовать вью сам: скелетон,
    /// галочку, полосу прогресса. Такие виды не выражаются модификатором,
    /// и попытка применить их через `CadenceMotionModifier` — ошибка.
    var isModifierFamily: Bool {
        switch self {
        case .timingOnly, .scale, .fade, .shake, .disintegrate:
            true
        case .shimmer, .progress, .drawOn, .cornerReveal:
            false
        }
    }
}
```

- [ ] **Step 5: Написать эффект потряхивания**

```swift
// Sources/CadenceMotion/ShakeEffect.swift
import SwiftUI

/// Затухающее горизонтальное колебание.
///
/// Отдельный `GeometryEffect`, а не `offset`: потряхивание — это колебание
/// во времени, одним сдвигом его не выразить. `animatableData` ведёт
/// счётчик колебаний от 0 до 3, амплитуда линейно гаснет к концу.
public struct ShakeEffect: GeometryEffect {
    public var amplitude: CGFloat
    public var shakes: CGFloat

    public init(amplitude: CGFloat, shakes: CGFloat) {
        self.amplitude = amplitude
        self.shakes = shakes
    }

    public var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    /// Вынесено отдельно, чтобы математику затухания можно было проверить
    /// тестом, не собирая `ProjectionTransform`.
    public var horizontalDisplacement: CGFloat {
        let decay = max(0, 1 - shakes / 3)
        return amplitude * decay * sin(shakes * .pi * 2)
    }

    public func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: horizontalDisplacement, y: 0))
    }
}
```

- [ ] **Step 6: Написать модификатор**

```swift
// Sources/CadenceMotion/CadenceMotionModifier.swift
import SwiftUI
import CadenceCore

/// Применяет к вью виды движения модификаторного семейства.
///
/// `phase` — булев триггер: переключение означает, что событие случилось.
/// Виды видового семейства модификатор игнорирует: их рисует не он.
public struct CadenceMotionModifier: ViewModifier {
    public let spec: MotionSpec?
    public let phase: Bool

    public init(spec: MotionSpec?, phase: Bool) {
        self.spec = spec
        self.phase = phase
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .modifier(ShakeEffect(amplitude: shakeAmplitude, shakes: phase ? 3 : 0))
            .animation(spec?.animation, value: phase)
    }

    private var scale: CGFloat {
        guard phase, let spec, case .scale(let target) = spec.kind else { return 1 }
        return target
    }

    private var opacity: Double {
        guard let spec, case .fade = spec.kind else { return 1 }
        return phase ? 1 : 0
    }

    private var shakeAmplitude: CGFloat {
        guard let spec, case .shake(let amplitude) = spec.kind else { return 0 }
        return amplitude
    }
}
```

- [ ] **Step 7: Удалить заглушку и прогнать всё**

```bash
rm Sources/CadenceMotion/Placeholder.swift
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add Sources/CadenceMotion Tests/CadenceMotionTests
git commit -m "Рендер движения: анимация из спеки, затухающий shake, два семейства видов

Разделение на модификаторное и видовое семейство закреплено свойством
и покрыто исчерпывающим свитчем: новый вид не скомпилируется без классификации."
```

---

### Task 8: Публичный API и мост со средой

**Files:**
- Create: `Sources/Cadence/EnvironmentBridge.swift`
- Create: `Sources/Cadence/PowerState.swift`
- Create: `Sources/Cadence/CadenceRuntime.swift`
- Create: `Sources/Cadence/CadenceModifier.swift`
- Delete: `Sources/Cadence/Placeholder.swift`
- Test: `Tests/CadenceTests/EnvironmentBridgeTests.swift`

**Interfaces:**
- Consumes: `resolve(_:in:)`, `CadenceContext` из задач 5–6; `CadenceMotionModifier` из задачи 7; `HapticScheduler`, `CoreHapticsOutput` из задачи 4.
- Produces:
  `CadenceContext.make(reduceMotion:reduceTransparency:lowPower:scenePhase:hapticsAvailable:) -> CadenceContext`;
  `EnvironmentValues.cadenceContextOverride: CadenceContext?`;
  `@MainActor final class CadenceRuntime` с `static let shared`, `var hapticsAvailable: Bool`, `var scheduler: HapticScheduler`;
  `View.cadence<T: Equatable>(_ event: RoutineInteraction, trigger: T) -> some View`;
  `View.cadenceSignature<T: Equatable>(_ event: SignatureInteraction, trigger: T) -> some View`.

- [ ] **Step 1: Написать падающий тест моста**

Мост — единственная часть склейки, которую можно проверить юнит-тестом, поэтому он вынесен в чистую функцию.

```swift
// Tests/CadenceTests/EnvironmentBridgeTests.swift
import Testing
import SwiftUI
import CadenceCore
@testable import Cadence

@Test func activeScenePhaseMeansSceneActive() {
    let context = CadenceContext.make(
        reduceMotion: false, reduceTransparency: false, lowPower: false,
        scenePhase: .active, hapticsAvailable: true
    )
    #expect(context.sceneActive)
}

@Test(arguments: [ScenePhase.inactive, ScenePhase.background])
func nonActiveScenePhaseSuppressesScene(phase: ScenePhase) {
    let context = CadenceContext.make(
        reduceMotion: false, reduceTransparency: false, lowPower: false,
        scenePhase: phase, hapticsAvailable: true
    )
    #expect(context.sceneActive == false)
}

@Test func bridgeCarriesEveryFlagThrough() {
    let context = CadenceContext.make(
        reduceMotion: true, reduceTransparency: true, lowPower: true,
        scenePhase: .active, hapticsAvailable: false
    )
    #expect(context.reduceMotion)
    #expect(context.reduceTransparency)
    #expect(context.lowPower)
    #expect(context.hapticsAvailable == false)
}

/// Мост обязан быть чистым: он не читает глобальное состояние сам,
/// всё приходит аргументами. Иначе его нельзя проверить.
@Test func bridgeIsPure() {
    let first = CadenceContext.make(
        reduceMotion: false, reduceTransparency: false, lowPower: false,
        scenePhase: .active, hapticsAvailable: true
    )
    let second = CadenceContext.make(
        reduceMotion: false, reduceTransparency: false, lowPower: false,
        scenePhase: .active, hapticsAvailable: true
    )
    #expect(first == second)
}
```

- [ ] **Step 2: Прогнать, убедиться в провале**

```bash
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: `type 'CadenceContext' has no member 'make'`.

- [ ] **Step 3: Написать мост и переопределение среды**

```swift
// Sources/Cadence/EnvironmentBridge.swift
import SwiftUI
import CadenceCore

public extension CadenceContext {
    /// Собирает контекст из значений среды.
    ///
    /// Все входы передаются явно и функция ничего не читает из глобального
    /// состояния: только так её можно проверить тестом.
    static func make(
        reduceMotion: Bool,
        reduceTransparency: Bool,
        lowPower: Bool,
        scenePhase: ScenePhase,
        hapticsAvailable: Bool
    ) -> CadenceContext {
        CadenceContext(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            lowPower: lowPower,
            hapticsAvailable: hapticsAvailable,
            sceneActive: scenePhase == .active
        )
    }
}

public extension EnvironmentValues {
    /// Подмена контекста целиком. Нужна каталогу и превью, чтобы показывать
    /// деградацию, не меняя системные настройки устройства.
    @Entry var cadenceContextOverride: CadenceContext? = nil
}
```

- [ ] **Step 4: Написать наблюдение за режимом энергосбережения**

```swift
// Sources/Cadence/PowerState.swift
import Foundation
import Observation

/// Режим энергосбережения меняется на ходу, поэтому его читают не разово,
/// а наблюдают: иначе signature-эффект останется дорогим до перезапуска.
@MainActor
@Observable
public final class PowerState {
    public static let shared = PowerState()

    public private(set) var isLowPower: Bool

    private init() {
        isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                PowerState.shared.isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }
}
```

- [ ] **Step 5: Написать рантайм**

```swift
// Sources/Cadence/CadenceRuntime.swift
import CadenceCore
import CadenceHaptics

/// Единственный владелец хаптик-движка в процессе.
///
/// Синглтон здесь оправдан: CHHapticEngine — дорогой системный ресурс,
/// и поднимать его на каждый модификатор нельзя.
@MainActor
public final class CadenceRuntime {
    public static let shared = CadenceRuntime()

    private let output: CoreHapticsOutput
    public let scheduler: HapticScheduler

    public var hapticsAvailable: Bool { output.isAvailable }

    private init() {
        let output = CoreHapticsOutput()
        self.output = output
        self.scheduler = HapticScheduler(output: output)
    }
}
```

- [ ] **Step 6: Написать публичные модификаторы**

```swift
// Sources/Cadence/CadenceModifier.swift
import SwiftUI
import CadenceCore
import CadenceMotion

public extension View {
    /// Повседневное событие: движение и хаптик подбирает резолвер.
    func cadence<T: Equatable>(_ event: RoutineInteraction, trigger: T) -> some View {
        modifier(CadenceEventModifier(plan: { resolve(event, in: $0) }, trigger: trigger))
    }

    /// Редкое выразительное событие. Отдельный метод и отдельный тип события:
    /// применить его к обычному действию не получится — не скомпилируется.
    func cadenceSignature<T: Equatable>(_ event: SignatureInteraction, trigger: T) -> some View {
        modifier(CadenceEventModifier(plan: { resolve(event, in: $0) }, trigger: trigger))
    }
}

struct CadenceEventModifier<T: Equatable>: ViewModifier {
    let plan: (CadenceContext) -> FeedbackPlan
    let trigger: T

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cadenceContextOverride) private var override

    @State private var phase = false

    func body(content: Content) -> some View {
        let context = override ?? CadenceContext.make(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            lowPower: PowerState.shared.isLowPower,
            scenePhase: scenePhase,
            hapticsAvailable: CadenceRuntime.shared.hapticsAvailable
        )
        let resolved = plan(context)

        return content
            .modifier(CadenceMotionModifier(spec: resolved.motion, phase: phase))
            .onChange(of: trigger) {
                phase.toggle()
                if let haptic = resolved.haptic {
                    CadenceRuntime.shared.scheduler.fire(haptic)
                }
            }
    }
}
```

- [ ] **Step 7: Удалить заглушку и прогнать всё**

```bash
rm Sources/Cadence/Placeholder.swift
xcodebuild test -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```
Ожидание: `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add Sources/Cadence Tests/CadenceTests
git commit -m "Публичный API: .cadence и .cadenceSignature, мост со средой

Мост вынесен в чистую функцию и покрыт тестами. Переопределение контекста
через среду даёт каталогу и превью показ деградации без системных настроек."
```

---

### Task 9: Каталог

Демо-приложение — не витрина, а инструмент проверки: тактильную часть и субъективное качество движения нельзя оценить по коду и нельзя заассертить.

**Files:**
- Create: `Catalog/Catalog.xcodeproj` (вручную через Xcode, шаги ниже)
- Create: `Catalog/Catalog/CatalogApp.swift`
- Create: `Catalog/Catalog/EffectListScreen.swift`
- Create: `Catalog/Catalog/DegradationControls.swift`
- Create: `Catalog/Catalog/FireCounter.swift`
- Create: `Catalog/Catalog/Screens/PressResponseScreen.swift`
- Create: `Catalog/Catalog/Screens/SelectionShiftScreen.swift`
- Create: `Catalog/Catalog/Screens/ContentArrivalScreen.swift`
- Create: `Catalog/Catalog/Screens/ValidationFailureScreen.swift`
- Create: `AGENTS.md`

**Interfaces:**
- Consumes: `View.cadence(_:trigger:)`, `EnvironmentValues.cadenceContextOverride`, `CadenceContext` из задачи 8.
- Produces: приложение `Catalog`; `AGENTS.md` с правилом ручной проверки хаптиков.

- [ ] **Step 1: Создать проект вручную в Xcode**

Инструментов генерации проектов на машине нет (`xcodegen` и `tuist` отсутствуют), поэтому таргет создаётся руками. Точные шаги:

1. Xcode → File → New → Project → iOS → App.
2. Product Name: `Catalog`. Interface: SwiftUI. Language: Swift. Storage: None. Тесты не включать.
3. Сохранить в `~/projects/cadence/Catalog`.
4. Target Catalog → General → Minimum Deployments → iOS 26.0.
5. Target Catalog → Signing & Capabilities → снять Automatically manage signing, выбрать **Sign to Run Locally**. Команду разработчика не проставлять.
6. File → Add Package Dependencies → Add Local → выбрать папку `~/projects/cadence` → добавить продукт `Cadence` к таргету Catalog.
7. Собрать пустое приложение и убедиться, что оно запускается в симуляторе.

- [ ] **Step 2: Написать счётчик срабатываний**

```swift
// Catalog/Catalog/FireCounter.swift
import Observation

/// Делает понятие tier физически ощутимым: видно, сколько раз эффект
/// сыграл за сессию. Для workhorse счёт уходит в десятки за минуту,
/// для signature остаётся единичным.
@MainActor
@Observable
final class FireCounter {
    private(set) var counts: [String: Int] = [:]

    func record(_ effect: String) {
        counts[effect, default: 0] += 1
    }

    func count(_ effect: String) -> Int { counts[effect] ?? 0 }
}
```

- [ ] **Step 3: Написать переключатели деградации**

```swift
// Catalog/Catalog/DegradationControls.swift
import SwiftUI
import Cadence
import CadenceCore

/// Переключатели среды. Подменяют контекст целиком, поэтому деградацию
/// видно, не выходя в системные настройки устройства.
struct DegradationControls: View {
    @Binding var context: CadenceContext

    var body: some View {
        Section("Среда") {
            Toggle("Reduce Motion", isOn: $context.reduceMotion)
            Toggle("Reduce Transparency", isOn: $context.reduceTransparency)
            Toggle("Экономия энергии", isOn: $context.lowPower)
            Toggle("Хаптик доступен", isOn: $context.hapticsAvailable)
        }
    }
}
```

- [ ] **Step 4: Написать корневой экран**

```swift
// Catalog/Catalog/CatalogApp.swift
import SwiftUI

@main
struct CatalogApp: App {
    var body: some Scene {
        WindowGroup {
            EffectListScreen()
        }
    }
}
```

```swift
// Catalog/Catalog/EffectListScreen.swift
import SwiftUI
import Cadence
import CadenceCore

struct EffectListScreen: View {
    @State private var context = CadenceContext.standard
    @State private var counter = FireCounter()

    var body: some View {
        NavigationStack {
            List {
                DegradationControls(context: $context)

                Section("Workhorse — сотни раз за сессию") {
                    NavigationLink("pressResponse") { PressResponseScreen() }
                    NavigationLink("selectionShift") { SelectionShiftScreen() }
                    NavigationLink("contentArrival") { ContentArrivalScreen() }
                }

                Section("Accent — единицы раз за сессию") {
                    NavigationLink("validationFailure") { ValidationFailureScreen() }
                }
            }
            .navigationTitle("Cadence")
        }
        .environment(\.cadenceContextOverride, context)
        .environment(counter)
    }
}
```

- [ ] **Step 5: Написать экраны эффектов**

```swift
// Catalog/Catalog/Screens/PressResponseScreen.swift
import SwiftUI
import Cadence

struct PressResponseScreen: View {
    @Environment(FireCounter.self) private var counter
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 32) {
            Text("Отклик на нажатие. Бюджет 100 мс — порог, ниже которого отклик неотличим от прямого манипулирования объектом.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Нажми") {
                taps += 1
                counter.record("pressResponse")
            }
            .buttonStyle(.borderedProminent)
            .cadence(.pressed, trigger: taps)

            Text("Сыграл \(counter.count("pressResponse")) раз за сессию")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("pressResponse")
    }
}
```

```swift
// Catalog/Catalog/Screens/SelectionShiftScreen.swift
import SwiftUI
import Cadence

struct SelectionShiftScreen: View {
    @Environment(FireCounter.self) private var counter
    @State private var selection = 0

    var body: some View {
        VStack(spacing: 32) {
            Text("Смена выбора. Cadence даёт тайминг и хаптик, геометрию двигает приложение. Хаптик троттлится: быстрые переключения не дают жужжания.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Раздел", selection: $selection) {
                Text("Один").tag(0)
                Text("Два").tag(1)
                Text("Три").tag(2)
            }
            .pickerStyle(.segmented)
            .cadence(.selectionChanged, trigger: selection)
            .onChange(of: selection) { counter.record("selectionShift") }

            Text("Сыграл \(counter.count("selectionShift")) раз за сессию")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("selectionShift")
    }
}
```

```swift
// Catalog/Catalog/Screens/ContentArrivalScreen.swift
import SwiftUI
import Cadence

struct ContentArrivalScreen: View {
    @State private var shown = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Появление контента каскадом. Задержка ограничена бюджетом крупного перемещения: иначе последняя ячейка ждёт секунды и это читается как тормоза.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(shown ? "Спрятать" : "Показать") { shown.toggle() }
                .buttonStyle(.bordered)

            if shown {
                VStack(spacing: 8) {
                    ForEach(0..<12, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.tint.opacity(0.2))
                            .frame(height: 28)
                            .cadence(.contentArrived(staggerIndex: index), trigger: shown)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("contentArrival")
    }
}
```

```swift
// Catalog/Catalog/Screens/ValidationFailureScreen.swift
import SwiftUI
import Cadence

struct ValidationFailureScreen: View {
    @State private var attempts = 0
    @State private var code = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Ошибка ввода. Введи что угодно кроме 1234 и нажми проверить.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Код", text: $code)
                .textFieldStyle(.roundedBorder)
                .cadence(.validationFailed, trigger: attempts)

            Button("Проверить") {
                if code != "1234" { attempts += 1 }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("validationFailure")
    }
}
```

- [ ] **Step 6: Собрать и проверить руками на устройстве**

```bash
xcodebuild build -project Catalog/Catalog.xcodeproj -scheme Catalog \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Затем запустить на **физическом устройстве** и проверить глазами и пальцами:

1. `pressResponse` — нажатие ощущается мгновенным, лёгкий импакт совпадает с визуальным сжатием, не запаздывает.
2. `selectionShift` — быстрое перещёлкивание сегментов не даёт непрерывного жужжания.
3. `contentArrival` — двенадцатая ячейка появляется не позже, чем через 400 мс после первой.
4. `validationFailure` — потряхивание затухает, не обрывается рывком.
5. Включить Reduce Motion тумблером — движение заменилось кросс-фейдом, а не пропало.
6. Выключить «Хаптик доступен» — движение осталось, вибрации нет.

- [ ] **Step 7: Написать AGENTS.md**

```markdown
# AGENTS.md — читать до того, как что-то трогать

## Проверка перед тем, как сказать «готово»

    xcodebuild test -scheme Cadence \
      -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'

`swift test` не работает: пакет iOS-only.

## Чего автотесты не проверяют

**Хаптику проверить тестами нельзя.** Ощущение вибрации не заассертить.
Любой хаптик-эффект считается готовым только после ручной проверки на
физическом устройстве через приложение Catalog. Зелёные тесты этого
не заменяют и не означают, что тактильная часть работает.

## Правила, которые ломать нельзя

1. `CadenceCore` не импортирует SwiftUI и UIKit. Резолвер обязан быть
   чистым, иначе правила ресерча перестанут быть проверяемыми.
2. Литерал длительности, которого нет в `docs/research/01-timing.md`, —
   повод отклонить изменение. Числа приходят из ресерча, а не из вкуса.
3. `Tier` — частота, `ChangeClass` — длительность. Это разные оси.
   Их уже склеивали один раз; тест `frequencyAndDurationStayIndependent`
   стоит именно против этого.
4. Reduce Motion подменяет движение, а не удаляет его. `reducedAlternative`
   не может быть пустым.
5. Хаптик не бывает без визуального сопровождения.
6. Никаких голых `try?` на путях отказа. Тихо в релизе, громко в дебаге.
```

- [ ] **Step 8: Commit**

```bash
git add Catalog AGENTS.md
git commit -m "Каталог: четыре эффекта, тумблеры деградации, счётчик срабатываний

Инструмент ручной проверки: хаптику и субъективное качество движения
нельзя оценить по коду. AGENTS.md фиксирует это как обязательный шаг."
```

---

## Что остаётся на второй план

Этот план даёт работающее ядро и четыре события из шести, доведённых до экрана. Вторым планом идёт то, что требует уже построенных здесь API:

1. **Видовое семейство:** `CadenceSkeleton`, `CadenceProgress`, `CadenceSuccessMark` — виды, которые Cadence рисует сам. Закрывает `waiting` и `taskSucceeded`.
2. **`disintegrate`:** Metal-шейдер в SPM, `layerEffect`, `maxSampleOffset`, тест загрузки через `ShaderLibrary.bundle(.module)`.
3. **`cornerEmergence`:** `concentricCornerRadii(in:)`, `ConcentricRectangle`, `GlassEffectContainer` с `glassEffectID`.
4. **Каталог:** экраны signature-эффектов с антипримерами.
5. **README и DocC:** двусторонние ссылки между символами API и файлами ресерча.

Второй план пишется после того, как первый приземлится: детальные шаги для шейдера и стекла имеет смысл формулировать, когда `MotionSpec`, `FeedbackPlan` и модификаторы уже существуют в коде, а не в тексте.

## Самопроверка плана

**Покрытие спеки.** Разделы 2–5 → задачи 2–3. Раздел 6 (примитивы) → задачи 5–7 частично, остаток во втором плане, названо явно. Раздел 7 (семантический слой) → задачи 5, 6, 8. Раздел 8 (доступность) → задачи 5, 6, 8, 9. Раздел 9 (ошибки) → задача 4, правило в AGENTS.md. Раздел 10 (каталог) → задача 9. Раздел 11 (тесты) → задачи 3–8. Раздел 12 (ресерч) → задача 1.

**Расхождения со спекой, зафиксированные выше:** резолвер живёт в Core, `MotionSpec` получил `delay`, правило про reduce motion переформулировано, `MotionKind` разделён на два семейства, `summoned` принимает угол.

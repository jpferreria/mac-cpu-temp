import Foundation
import AppIntents

@available(macOS 13.0, *)
public struct GetCPUTemperatureIntent: AppIntent {
    public static var title: LocalizedStringResource = "Get CPU Temperature"
    public static var description = IntentDescription("Returns the current CPU and SoC temperature of your Mac.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some ProvidesDialog {
        let insight = ThermalInsightEngine.shared().currentInsight()
        let dialogText = insight.naturalLanguageSummary
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}

@available(macOS 13.0, *)
public struct CheckThermalHealthIntent: AppIntent {
    public static var title: LocalizedStringResource = "Check Thermal Health"
    public static var description = IntentDescription("Checks whether your Mac is overheating and evaluates thermal throttling risk.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some ProvidesDialog {
        let insight = ThermalInsightEngine.shared().currentInsight()
        let status = insight.stateDescription
        let temp = Int(insight.currentTemp)
        let headroom = Int(insight.thermalHeadroom)
        let action = insight.recommendedAction

        let dialogText = "Thermal state is \(status) at \(temp)°C with \(headroom)°C of headroom before throttling. \(action)"
        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}

@available(macOS 13.0, *)
public struct CPUTempShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: GetCPUTemperatureIntent(),
                phrases: [
                    "What's my CPU temperature in \\(.applicationName)?",
                    "Check CPU temperature in \\(.applicationName)",
                    "How hot is my Mac with \\(.applicationName)?"
                ],
                shortTitle: "Get CPU Temperature",
                systemImageName: "thermometer.medium"
            ),
            AppShortcut(
                intent: CheckThermalHealthIntent(),
                phrases: [
                    "Is my Mac overheating in \\(.applicationName)?",
                    "Check thermal health with \\(.applicationName)",
                    "Check thermal throttling in \\(.applicationName)"
                ],
                shortTitle: "Check Thermal Health",
                systemImageName: "flame"
            )
        ]
    }
}

@objc public class AppIntentsBootstrap: NSObject {
    @objc public static func initializeIntents() {
        if #available(macOS 13.0, *) {
            CPUTempShortcutsProvider.updateAppShortcutParameters()
        }
    }
}

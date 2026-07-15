import AppKit
import MacPowerCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(title: "当前电源模式", value: model.actualModeText)
                StatusRow(title: "自动化运行状态", value: model.automationStatusText)
                StatusRow(title: "最近一次切换原因", value: model.lastSwitchReasonText)
            }

            Divider()

            Toggle("自动化", isOn: automationBinding)

            Button {
                DispatchQueue.main.async {
                    AppLifecycle.shared.showAutomationSettings()
                }
            } label: {
                Label("自动切换设置…", systemImage: "gearshape")
            }
            .accessibilityHint("打开自动电源切换的详细设置")

            if model.isPaused {
                Button("恢复自动") {
                    model.resumeAutomation()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            Button("退出软件") {
                NSApplication.shared.terminate(nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(AppVersion.displayText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel("版本 \(AppVersion.version)，\(AppVersion.releaseName)")
        }
        .padding(14)
        .frame(width: 320)
    }

    private var automationBinding: Binding<Bool> {
        Binding(
            get: { model.isAutomationEnabled },
            set: { model.setAutomationEnabled($0) }
        )
    }
}

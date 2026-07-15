import MacPowerCore
import SwiftUI

/// A full settings window keeps the menu-bar popover focused on status and the
/// main switch, while presenting the automation rule as a short, readable flow.
struct AutomationSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var isShowingResetConfirmation = false

    var body: some View {
        Form {
            Section("自动切换状态") {
                Toggle("启用自动切换", isOn: automationBinding)
                LabeledContent("当前状态") {
                    Text(model.automationStatusText)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("当前电源模式") {
                    Text(model.actualModeText)
                        .foregroundStyle(.secondary)
                }
            }

            Section("用户空闲后切换") {
                HStack {
                    Text("连续无操作达到")
                    Spacer()
                    TextField(
                        "连续无操作时间",
                        value: idleTimeValueBinding,
                        format: .number
                    )
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    .accessibilityLabel("连续无操作时间")

                    Stepper("", value: idleTimeValueBinding, in: 1 ... 86_400)
                        .labelsHidden()
                        .accessibilityLabel("调整连续无操作时间")

                    Picker("时间单位", selection: idleTimeUnitBinding) {
                        ForEach(IdleTimeUnit.allCases, id: \.self) { unit in
                            Text(unit.displayText).tag(unit)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .accessibilityLabel("连续无操作时间单位")
                }

                Text(
                    "当系统连续 \(idleDurationDescription) 没有检测到键盘、鼠标或触控板操作时，切换到下方选择的电源模式。"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                powerModePicker(
                    title: "随后切换到",
                    selection: idlePowerModeBinding
                )

                pollingIntervalControl(
                    title: "空闲时检测间隔",
                    value: idlePollingIntervalValueBinding,
                    unit: idlePollingIntervalUnitBinding,
                    units: PollingIntervalUnit.idleOptions
                )
            }

            Section("活跃时") {
                powerModePicker(
                    title: "使用电源模式",
                    selection: activePowerModeBinding
                )

                pollingIntervalControl(
                    title: "活跃时检测间隔",
                    value: activePollingIntervalValueBinding,
                    unit: activePollingIntervalUnitBinding,
                    units: PollingIntervalUnit.activeOptions
                )

                Text("检测间隔可设为 100 毫秒至 3600 秒；活跃时也可使用分钟。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("空闲保护") {
                Toggle(
                    "手动切换后暂停自动切换",
                    isOn: pauseOnManualPowerModeChangeBinding
                )
                .accessibilityHint("检测到系统电源模式被外部修改时暂停自动切换。")

                if model.isPaused {
                    Button("恢复自动切换") {
                        model.resumeAutomation()
                    }
                }
            }

            Section("亮度恢复") {
                Toggle(
                    "退出低电量模式后恢复亮度",
                    isOn: restoreBrightnessAfterLowPowerBinding
                )
                .accessibilityHint("恢复进入低电量模式前保存的内建屏幕亮度。")

                LabeledContent("恢复前等待") {
                    HStack(spacing: 6) {
                        TextField(
                            "等待时间",
                            value: brightnessRestoreDelayBinding,
                            format: .number
                        )
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .accessibilityLabel("亮度恢复等待时间")

                        Stepper(
                            "",
                            value: brightnessRestoreDelayBinding,
                            in: AutomationConfig.brightnessRestoreDelayRange
                        )
                        .labelsHidden()
                        .accessibilityLabel("调整亮度恢复等待时间")

                        Text("毫秒")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!model.restoreBrightnessAfterLowPower)

                Text("默认 0 毫秒；如果没有恢复，可以延长等待时间。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("设置管理") {
                Button("恢复默认设置") {
                    isShowingResetConfirmation = true
                }

                Text("恢复所有规则与选项；当前自动化开关保持不变。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !model.isHighPowerCurrentlyAvailable {
                Text("当前设备或供电状态不支持高性能模式；选择它时会自动使用自动模式。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 480)
        .confirmationDialog(
            "恢复默认设置？",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("恢复默认设置", role: .destructive) {
                model.restoreDefaultSettings()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("空闲时间、检测间隔、电源模式和亮度选项将恢复默认值。")
        }
    }

    private var automationBinding: Binding<Bool> {
        Binding(
            get: { model.isAutomationEnabled },
            set: { model.setAutomationEnabled($0) }
        )
    }

    private var idleTimeValueBinding: Binding<Int> {
        Binding(
            get: { model.idleTimeValue },
            set: { model.setIdleTimeValue($0) }
        )
    }

    private var idleTimeUnitBinding: Binding<IdleTimeUnit> {
        Binding(
            get: { model.idleTimeUnit },
            set: { model.setIdleTimeUnit($0) }
        )
    }

    private var idleDurationDescription: String {
        "\(model.idleTimeValue) \(model.idleTimeUnit.displayText)"
    }

    private var activePollingIntervalValueBinding: Binding<Double> {
        Binding(
            get: { model.activePollingIntervalValue },
            set: { model.setActivePollingIntervalValue($0) }
        )
    }

    private var activePollingIntervalUnitBinding: Binding<PollingIntervalUnit> {
        Binding(
            get: { model.activePollingIntervalUnit },
            set: { model.setActivePollingIntervalUnit($0) }
        )
    }

    private var idlePollingIntervalValueBinding: Binding<Double> {
        Binding(
            get: { model.idlePollingIntervalValue },
            set: { model.setIdlePollingIntervalValue($0) }
        )
    }

    private var idlePollingIntervalUnitBinding: Binding<PollingIntervalUnit> {
        Binding(
            get: { model.idlePollingIntervalUnit },
            set: { model.setIdlePollingIntervalUnit($0) }
        )
    }

    private var activePowerModeBinding: Binding<PowerMode> {
        Binding(
            get: { model.activePowerMode },
            set: { model.setActivePowerMode($0) }
        )
    }

    private var idlePowerModeBinding: Binding<PowerMode> {
        Binding(
            get: { model.idlePowerMode },
            set: { model.setIdlePowerMode($0) }
        )
    }

    private var pauseOnManualPowerModeChangeBinding: Binding<Bool> {
        Binding(
            get: { model.pauseOnManualPowerModeChange },
            set: { model.setPauseOnManualPowerModeChange($0) }
        )
    }

    private var restoreBrightnessAfterLowPowerBinding: Binding<Bool> {
        Binding(
            get: { model.restoreBrightnessAfterLowPower },
            set: { model.setRestoreBrightnessAfterLowPower($0) }
        )
    }

    private var brightnessRestoreDelayBinding: Binding<Int> {
        Binding(
            get: { model.brightnessRestoreDelayMilliseconds },
            set: { model.setBrightnessRestoreDelayMilliseconds($0) }
        )
    }

    private func powerModePicker(
        title: String,
        selection: Binding<PowerMode>
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(PowerMode.allCases, id: \.rawValue) { mode in
                Text(powerModeOptionText(mode)).tag(mode)
            }
        }
    }

    private func pollingIntervalControl(
        title: String,
        value: Binding<Double>,
        unit: Binding<PollingIntervalUnit>,
        units: [PollingIntervalUnit]
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                TextField(
                    "检测间隔",
                    value: value,
                    format: .number.precision(.fractionLength(0 ... 4))
                )
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 88)
                .accessibilityLabel(title)

                Picker("时间单位", selection: unit) {
                    ForEach(units, id: \.self) { option in
                        Text(option.displayText).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .accessibilityLabel("\(title)单位")
            }
        }
    }

    private func powerModeOptionText(_ mode: PowerMode) -> String {
        guard mode == .highPower, !model.isHighPowerCurrentlyAvailable else {
            return mode.displayText
        }
        return "高性能（当前不可用）"
    }
}

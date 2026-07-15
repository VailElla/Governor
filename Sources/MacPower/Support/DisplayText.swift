import MacPowerCore

extension PowerMode {
    var displayText: String {
        switch self {
        case .lowPower:
            "低电量"
        case .automatic:
            "自动"
        case .highPower:
            "高性能"
        }
    }

    var menuBarSystemImage: String {
        switch self {
        case .lowPower:
            "leaf.fill"
        case .automatic:
            "bolt.circle"
        case .highPower:
            "bolt.fill"
        }
    }
}

extension AutomationStatus {
    var displayText: String {
        switch self {
        case .disabled:
            "已关闭"
        case .starting:
            "正在启动"
        case .running:
            "运行中"
        case .pausedForManualChange:
            "已暂停"
        case .restoring:
            "正在恢复"
        case let .errorStopped(failure):
            "已停止：\(failure.displayText)"
        }
    }

    var isPaused: Bool {
        self == .pausedForManualChange
    }
}

extension AutomationFailure {
    var displayText: String {
        switch self {
        case .permissionDenied:
            "权限不足"
        case .systemReadFailed:
            "读取失败"
        case .invalidDecisionInput:
            "状态无效"
        case .switchRequestFailed:
            "切换失败"
        case .confirmationReadFailed:
            "确认失败"
        case .confirmationMismatch:
            "切换未生效"
        case .historyReadFailed:
            "记录读取失败"
        case .historyWriteFailed:
            "记录保存失败"
        case .highPowerUnavailableForRestoration:
            "无法恢复原模式"
        }
    }
}

extension DecisionReason {
    var displayText: String {
        switch self {
        case .highPowerBecameUnavailable:
            "High Power 不再可用"
        case .idleThresholdReached:
            "已使用空闲电源模式"
        case .userActive:
            "已使用活跃电源模式"
        }
    }
}

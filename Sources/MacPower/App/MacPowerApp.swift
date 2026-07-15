import SwiftUI

@main
@MainActor
struct MacPowerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel

    init() {
        let model = AppModel.live()
        _model = StateObject(wrappedValue: model)
        AppLifecycle.shared.model = model
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Image(systemName: model.menuBarSystemImage)
                .accessibilityLabel("MacPower")
        }
        .menuBarExtraStyle(.window)
    }
}

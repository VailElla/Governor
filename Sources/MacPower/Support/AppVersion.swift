import Foundation

enum AppVersion {
    private static let fallbackVersion = "开发构建"
    private static let fallbackReleaseName = "未标记"

    static var version: String {
        bundleValue(forKey: "CFBundleShortVersionString") ?? fallbackVersion
    }

    static var releaseName: String {
        bundleValue(forKey: "MacPowerReleaseName") ?? fallbackReleaseName
    }

    static var displayText: String {
        "MacPower \(version) · \(releaseName)"
    }

    private static func bundleValue(forKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else {
            return nil
        }
        return value
    }
}

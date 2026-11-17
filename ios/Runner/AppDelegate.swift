import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 小组件数据通道：Dart 端把实时数据写入 App Group UserDefaults
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.xintiao.widget",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        if call.method == "update", let args = call.arguments as? [String: Any] {
          let ud = UserDefaults(suiteName: "group.com.xintiao.widget")
          for (k, v) in args {
            ud?.set(v, forKey: k)
          }
          ud?.synchronize()
          // 提示系统尽快刷新小组件（系统会限流）
          if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
          }
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

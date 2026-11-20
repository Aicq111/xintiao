import Flutter
import UIKit
import WidgetKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // OCR 通道：本地 Vision 文字识别（识别排班表截图，不联网）
    if let controller = window?.rootViewController as? FlutterViewController {
      let ocrChannel = FlutterMethodChannel(
        name: "com.xintiao.ocr",
        binaryMessenger: controller.binaryMessenger)
      ocrChannel.setMethodCallHandler { call, result in
        if call.method == "recognize", let path = call.arguments as? String {
          guard let image = UIImage(contentsOfFile: path)?.cgImage else {
            result(FlutterError(code: "OCR_NO_IMAGE", message: "无法读取图片", details: path))
            return
          }
          let request = VNRecognizeTextRequest { req, _ in
            guard let observations = req.results as? [VNRecognizedTextObservation] else {
              result([])
              return
            }
            var lines: [[String: Any]] = []
            for obs in observations {
              guard let top = obs.topCandidates(1).first else { continue }
              let b = obs.boundingBox
              lines.append([
                "text": top.string,
                "x": b.origin.x,
                "y": b.origin.y,
                "w": b.size.width,
                "h": b.size.height,
              ])
            }
            result(lines)
          }
          request.recognitionLevel = .accurate
          request.recognitionLanguages = ["zh-Hans", "en-US"]
          let handler = VNImageRequestHandler(cgImage: image, options: [:])
          DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

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

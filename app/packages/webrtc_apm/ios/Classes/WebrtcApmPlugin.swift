import Flutter
import UIKit
import AVFoundation

/// WebRTC APM Flutter Plugin for iOS
public class WebrtcApmPlugin: NSObject, FlutterPlugin {
    private var audioProcessor: WebrtcAudioProcessor?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "webrtc_apm", binaryMessenger: registrar.messenger())
        let instance = WebrtcApmPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        NSLog("[WebrtcApmPlugin] Plugin registered")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        NSLog("[WebrtcApmPlugin] Method called: \(call.method)")

        switch call.method {
        case "initialize":
            handleInitialize(call, result: result)
        case "dispose":
            handleDispose(result: result)
        case "setAecEnabled":
            handleSetAecEnabled(call, result: result)
        case "setAecSuppressionLevel":
            handleSetAecSuppressionLevel(call, result: result)
        case "setNsEnabled":
            handleSetNsEnabled(call, result: result)
        case "setNsSuppressionLevel":
            handleSetNsSuppressionLevel(call, result: result)
        case "setAgcEnabled":
            handleSetAgcEnabled(call, result: result)
        case "setAgcMode":
            handleSetAgcMode(call, result: result)
        case "setAgcTargetLevel":
            handleSetAgcTargetLevel(call, result: result)
        case "processCaptureFrame":
            handleProcessCaptureFrame(call, result: result)
        case "processRenderFrame":
            handleProcessRenderFrame(call, result: result)
        case "getStatus":
            handleGetStatus(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleInitialize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        let sampleRate = args["sampleRate"] as? Int ?? 16000
        let channels = args["channels"] as? Int ?? 1

        if audioProcessor != nil {
            NSLog("[WebrtcApmPlugin] Already initialized, disposing old instance")
            audioProcessor = nil
        }

        audioProcessor = WebrtcAudioProcessor()
        let success = audioProcessor?.initialize(sampleRate: sampleRate, channels: channels) ?? false

        NSLog("[WebrtcApmPlugin] Initialize result: \(success)")
        result(success)
    }

    private func handleDispose(result: @escaping FlutterResult) {
        audioProcessor?.dispose()
        audioProcessor = nil
        NSLog("[WebrtcApmPlugin] Disposed")
        result(nil)
    }

    private func handleSetAecEnabled(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(false)
            return
        }

        let success = audioProcessor?.setAecEnabled(enabled) ?? false
        result(success)
    }

    private func handleSetAecSuppressionLevel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let level = args["level"] as? Int else {
            result(false)
            return
        }

        let success = audioProcessor?.setAecSuppressionLevel(level) ?? false
        result(success)
    }

    private func handleSetNsEnabled(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(false)
            return
        }

        let success = audioProcessor?.setNsEnabled(enabled) ?? false
        result(success)
    }

    private func handleSetNsSuppressionLevel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let level = args["level"] as? Int else {
            result(false)
            return
        }

        let success = audioProcessor?.setNsSuppressionLevel(level) ?? false
        result(success)
    }

    private func handleSetAgcEnabled(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(false)
            return
        }

        let success = audioProcessor?.setAgcEnabled(enabled) ?? false
        result(success)
    }

    private func handleSetAgcMode(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let mode = args["mode"] as? Int else {
            result(false)
            return
        }

        let success = audioProcessor?.setAgcMode(mode) ?? false
        result(success)
    }

    private func handleSetAgcTargetLevel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let targetLevelDbfs = args["targetLevelDbfs"] as? Int else {
            result(false)
            return
        }

        let success = audioProcessor?.setAgcTargetLevel(targetLevelDbfs) ?? false
        result(success)
    }

    private func handleProcessCaptureFrame(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let audioData = args["audioData"] as? FlutterStandardTypedData else {
            result(nil)
            return
        }

        if let processedData = audioProcessor?.processCaptureFrame(audioData.data) {
            result(FlutterStandardTypedData(bytes: processedData))
        } else {
            result(audioData)
        }
    }

    private func handleProcessRenderFrame(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let audioData = args["audioData"] as? FlutterStandardTypedData else {
            result(false)
            return
        }

        let success = audioProcessor?.processRenderFrame(audioData.data) ?? false
        result(success)
    }

    private func handleGetStatus(result: @escaping FlutterResult) {
        let status = audioProcessor?.getStatus() ?? ["initialized": false]
        result(status)
    }
}

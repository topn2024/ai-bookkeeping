import Foundation
import Flutter

/// iOS 安全密钥存储
///
/// 使用 XOR 加密存储密钥，运行时解密。
/// 与 Android 的 secure_keys.c 保持一致。
class SecureKeyStore {
    // XOR 加密密钥（与 Android C 层一致）
    private static let xorKey: [UInt8] = [0x4B, 0x5A, 0x3C, 0x7F, 0x2E, 0x9A, 0x1D, 0x8B]

    // 阿里云 AccessKey ID (XOR加密)
    private static let akIdEnc: [UInt8] = [
        0x07, 0x0E, 0x7D, 0x36, 0x1B, 0xEE, 0x56, 0xB3,
        0x3D, 0x1C, 0x64, 0x4C, 0x74, 0xD7, 0x7F, 0xC9,
        0x3F, 0x2C, 0x55, 0x3E, 0x79, 0xF9, 0x4A, 0xE0
    ]

    // 阿里云 AccessKey Secret (XOR加密)
    private static let akSecEnc: [UInt8] = [
        0x26, 0x68, 0x50, 0x39, 0x4B, 0xCA, 0x2A, 0xC4,
        0x78, 0x30, 0x0B, 0x37, 0x5E, 0xCE, 0x2E, 0xFD,
        0x0F, 0x17, 0x4F, 0x0F, 0x1A, 0xAB, 0x75, 0xC1,
        0x11, 0x30, 0x4D, 0x18, 0x4D, 0xEC
    ]

    // 阿里云 AppKey (XOR加密)
    private static let appKeyEnc: [UInt8] = [
        0x08, 0x62, 0x7A, 0x4F, 0x4A, 0xE0, 0x2D, 0xE2,
        0x23, 0x1C, 0x51, 0x09, 0x65, 0xD2, 0x25, 0xCC
    ]

    // 通义千问 API Key (XOR加密)
    private static let qwenEnc: [UInt8] = [
        0x38, 0x31, 0x11, 0x19, 0x1E, 0xFB, 0x25, 0xBE,
        0x2F, 0x69, 0x59, 0x4A, 0x18, 0xFB, 0x2A, 0xBF,
        0x7D, 0x6F, 0x0C, 0x46, 0x4B, 0xF9, 0x29, 0xB8,
        0x7E, 0x3B, 0x5A, 0x4D, 0x1A, 0xAE, 0x2B, 0xE8,
        0x7D, 0x6D, 0x5D
    ]

    /// XOR 解密
    private static func xorDecrypt(_ encrypted: [UInt8]) -> String {
        var result = [UInt8](repeating: 0, count: encrypted.count)
        for i in 0..<encrypted.count {
            result[i] = encrypted[i] ^ xorKey[i % xorKey.count]
        }
        return String(bytes: result, encoding: .utf8) ?? ""
    }

    /// 注册 Flutter MethodChannel
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.example.ai_bookkeeping/secure_keys",
            binaryMessenger: registrar.messenger()
        )

        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "getAliyunAccessKeyId":
                result(xorDecrypt(akIdEnc))
            case "getAliyunAccessKeySecret":
                result(xorDecrypt(akSecEnc))
            case "getAliyunAppKey":
                result(xorDecrypt(appKeyEnc))
            case "getQwenApiKey":
                result(xorDecrypt(qwenEnc))
            case "getAsrUrl":
                result("wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1")
            case "getAsrRestUrl":
                result("https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/asr")
            case "getTtsUrl":
                result("wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1")
            case "getAllKeys":
                result([
                    "accessKeyId": xorDecrypt(akIdEnc),
                    "accessKeySecret": xorDecrypt(akSecEnc),
                    "appKey": xorDecrypt(appKeyEnc),
                    "qwenApiKey": xorDecrypt(qwenEnc),
                    "asrUrl": "wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1",
                    "asrRestUrl": "https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/asr",
                    "ttsUrl": "wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1"
                ])
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}

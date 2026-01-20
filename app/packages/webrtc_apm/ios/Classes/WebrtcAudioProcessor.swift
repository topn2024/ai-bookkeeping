import Foundation
import AVFoundation
import Accelerate

/// WebRTC 音频处理器 (iOS)
///
/// 提供软件级的 AEC/NS/AGC 处理
class WebrtcAudioProcessor {
    private var isInitialized = false
    private var sampleRate: Int = 16000
    private var channels: Int = 1

    // 配置状态
    private var aecEnabled = false
    private var nsEnabled = false
    private var agcEnabled = false
    private var aecSuppressionLevel = 2
    private var nsSuppressionLevel = 2
    private var agcMode = 1
    private var agcTargetLevel = 3

    // 参考信号缓冲区（用于 AEC）
    private var renderBuffer: [Int16] = []
    private var renderBufferSize: Int = 0

    init() {}

    func initialize(sampleRate: Int, channels: Int) -> Bool {
        if isInitialized {
            NSLog("[WebrtcAudioProcessor] Already initialized")
            return true
        }

        self.sampleRate = sampleRate
        self.channels = channels

        // 初始化参考信号缓冲区（存储约 100ms 的音频）
        let bufferSize = sampleRate / 10 * channels
        renderBuffer = [Int16](repeating: 0, count: bufferSize)
        renderBufferSize = 0

        isInitialized = true
        NSLog("[WebrtcAudioProcessor] Initialized: sampleRate=\(sampleRate), channels=\(channels)")
        return true
    }

    func dispose() {
        renderBuffer = []
        renderBufferSize = 0
        isInitialized = false
        NSLog("[WebrtcAudioProcessor] Disposed")
    }

    func setAecEnabled(_ enabled: Bool) -> Bool {
        aecEnabled = enabled
        NSLog("[WebrtcAudioProcessor] AEC enabled: \(enabled)")
        return true
    }

    func setAecSuppressionLevel(_ level: Int) -> Bool {
        aecSuppressionLevel = min(max(level, 0), 2)
        NSLog("[WebrtcAudioProcessor] AEC suppression level: \(aecSuppressionLevel)")
        return true
    }

    func setNsEnabled(_ enabled: Bool) -> Bool {
        nsEnabled = enabled
        NSLog("[WebrtcAudioProcessor] NS enabled: \(enabled)")
        return true
    }

    func setNsSuppressionLevel(_ level: Int) -> Bool {
        nsSuppressionLevel = min(max(level, 0), 3)
        NSLog("[WebrtcAudioProcessor] NS suppression level: \(nsSuppressionLevel)")
        return true
    }

    func setAgcEnabled(_ enabled: Bool) -> Bool {
        agcEnabled = enabled
        NSLog("[WebrtcAudioProcessor] AGC enabled: \(enabled)")
        return true
    }

    func setAgcMode(_ mode: Int) -> Bool {
        agcMode = min(max(mode, 0), 2)
        NSLog("[WebrtcAudioProcessor] AGC mode: \(agcMode)")
        return true
    }

    func setAgcTargetLevel(_ targetLevelDbfs: Int) -> Bool {
        agcTargetLevel = min(max(targetLevelDbfs, 0), 31)
        NSLog("[WebrtcAudioProcessor] AGC target level: \(agcTargetLevel)")
        return true
    }

    func processCaptureFrame(_ audioData: Data) -> Data? {
        guard isInitialized else { return audioData }

        // 将 Data 转换为 Int16 数组
        var samples = audioData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> [Int16] in
            let int16Buffer = buffer.bindMemory(to: Int16.self)
            return Array(int16Buffer)
        }

        if samples.isEmpty { return audioData }

        // 应用 AEC
        if aecEnabled && renderBufferSize > 0 {
            applyEchoCancellation(&samples)
        }

        // 应用 NS
        if nsEnabled {
            applyNoiseSuppression(&samples)
        }

        // 应用 AGC
        if agcEnabled {
            applyGainControl(&samples)
        }

        // 转换回 Data
        return samples.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }

    func processRenderFrame(_ audioData: Data) -> Bool {
        guard isInitialized else { return false }

        // 将 Data 转换为 Int16 数组
        let samples = audioData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> [Int16] in
            let int16Buffer = buffer.bindMemory(to: Int16.self)
            return Array(int16Buffer)
        }

        if samples.isEmpty { return false }

        // 更新参考信号缓冲区（循环缓冲）
        let copySize = min(samples.count, renderBuffer.count)
        if copySize > 0 {
            // 移动旧数据
            let shiftSize = renderBuffer.count - copySize
            if shiftSize > 0 {
                for i in 0..<shiftSize {
                    renderBuffer[i] = renderBuffer[i + copySize]
                }
            }
            // 复制新数据
            let sourceOffset = samples.count - copySize
            for i in 0..<copySize {
                renderBuffer[shiftSize + i] = samples[sourceOffset + i]
            }
            renderBufferSize = min(renderBufferSize + samples.count, renderBuffer.count)
        }

        return true
    }

    func getStatus() -> [String: Any] {
        return [
            "initialized": isInitialized,
            "aecEnabled": aecEnabled,
            "nsEnabled": nsEnabled,
            "agcEnabled": agcEnabled,
            "aecSuppressionLevel": aecSuppressionLevel,
            "nsSuppressionLevel": nsSuppressionLevel,
            "agcMode": agcMode,
            "agcTargetLevel": agcTargetLevel
        ]
    }

    // MARK: - Private Methods

    /// 简化的回声消除
    private func applyEchoCancellation(_ samples: inout [Int16]) {
        guard renderBufferSize > 0 else { return }

        // 计算相关性
        let correlation = calculateCorrelation(samples)

        // 根据抑制级别和相关性决定衰减系数
        let suppressionFactors: [Float] = [0.7, 0.5, 0.3] // low, moderate, high
        let suppressionFactor = suppressionFactors[aecSuppressionLevel]

        // 如果相关性高，应用衰减
        if correlation > 0.5 {
            let attenuation = max(1.0 - (correlation * suppressionFactor), 0.1)

            for i in 0..<samples.count {
                samples[i] = Int16(Float(samples[i]) * attenuation)
            }

            NSLog("[WebrtcAudioProcessor] AEC: correlation=\(String(format: "%.2f", correlation)), attenuation=\(String(format: "%.2f", attenuation))")
        }
    }

    /// 计算与参考信号的相关性
    private func calculateCorrelation(_ samples: [Int16]) -> Float {
        guard renderBufferSize > 0, !samples.isEmpty else { return 0.0 }

        let compareSize = min(samples.count, renderBufferSize)
        let startOffset = renderBuffer.count - renderBufferSize

        var sumXY: Float = 0.0
        var sumX2: Float = 0.0
        var sumY2: Float = 0.0

        for i in 0..<compareSize {
            let x = Float(samples[i])
            let y = Float(renderBuffer[startOffset + i])
            sumXY += x * y
            sumX2 += x * x
            sumY2 += y * y
        }

        if sumX2 < 1.0 || sumY2 < 1.0 { return 0.0 }

        return abs(sumXY) / sqrt(sumX2 * sumY2)
    }

    /// 简化的噪声抑制
    /// 注意：对于小声信号，减少抑制强度以保留语音
    private func applyNoiseSuppression(_ samples: inout [Int16]) {
        guard samples.count >= 3 else { return }

        // 先计算信号强度
        var sumSquares: Int64 = 0
        for sample in samples {
            sumSquares += Int64(sample) * Int64(sample)
        }
        let rms = sqrt(Float(sumSquares) / Float(samples.count))

        // 如果信号较弱（可能是小声说话），减少噪声抑制强度
        var effectiveLevel = nsSuppressionLevel
        if rms < 500.0 && rms > 20.0 {
            effectiveLevel = max(0, effectiveLevel - 1)
        }

        // 根据抑制级别决定滤波器大小（减小滤波器尺寸）
        let filterSizes = [3, 3, 5, 7]
        let filterSize = filterSizes[effectiveLevel]
        let halfFilter = filterSize / 2

        var filtered = [Int16](repeating: 0, count: samples.count)

        for i in 0..<samples.count {
            var sum: Int32 = 0
            var count: Int32 = 0

            for j in -halfFilter...halfFilter {
                let idx = i + j
                if idx >= 0 && idx < samples.count {
                    sum += Int32(samples[idx])
                    count += 1
                }
            }

            filtered[i] = Int16(sum / count)
        }

        // 混合原始信号和滤波信号
        // 提高原始信号比例，保留更多语音细节
        let mixFactors: [Float] = [0.9, 0.8, 0.7, 0.6]
        let mix = mixFactors[effectiveLevel]

        for i in 0..<samples.count {
            samples[i] = Int16(Float(samples[i]) * mix + Float(filtered[i]) * (1.0 - mix))
        }
    }

    /// 简化的自动增益控制
    private func applyGainControl(_ samples: inout [Int16]) {
        guard !samples.isEmpty else { return }

        // 计算当前音量
        var sumSquares: Int64 = 0
        for sample in samples {
            sumSquares += Int64(sample) * Int64(sample)
        }
        let rms = sqrt(Float(sumSquares) / Float(samples.count))

        // 目标 RMS
        let targetRms = 32768.0 * pow(10.0, Float(-agcTargetLevel) / 20.0)

        // 降低阈值到 20，允许处理更小的声音
        if rms < 20.0 {
            // 信号太弱（基本是静音），跳过
            return
        }

        // 计算增益
        var gain = targetRms / rms

        // 扩大增益范围，允许更大的放大倍数（0.5x - 10x）
        gain = min(max(gain, 0.5), 10.0)

        // 应用增益
        for i in 0..<samples.count {
            let sample = Int32(Float(samples[i]) * gain)
            samples[i] = Int16(min(max(sample, -32768), 32767))
        }
    }
}

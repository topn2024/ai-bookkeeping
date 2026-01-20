#include "include/audio_processor.h"
#include <android/log.h>
#include <cstring>
#include <algorithm>
#include <cmath>

#define LOG_TAG "WebRTC_APM"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace webrtc_apm {

/**
 * AudioProcessor 内部实现
 *
 * 注意：这是一个简化实现，提供基本的音频处理功能
 * 完整的 WebRTC APM 需要链接 libwebrtc_audio_processing.so
 */
class AudioProcessor::Impl {
public:
    Impl() : aecEnabled_(false), nsEnabled_(false), agcEnabled_(false),
             aecSuppressionLevel_(2), nsSuppressionLevel_(2),
             agcMode_(1), agcTargetLevel_(3),
             sampleRate_(16000), channels_(1),
             renderBufferSize_(0) {
        // 初始化参考信号缓冲区（用于 AEC）
        // 存储约 100ms 的音频用于回声消除
        renderBuffer_.resize(sampleRate_ / 10 * channels_);
    }

    ~Impl() = default;

    bool Initialize(int sampleRate, int channels) {
        sampleRate_ = sampleRate;
        channels_ = channels;
        renderBuffer_.resize(sampleRate_ / 10 * channels_);
        renderBufferSize_ = 0;
        LOGD("Initialized: sampleRate=%d, channels=%d", sampleRate, channels);
        return true;
    }

    void Destroy() {
        renderBuffer_.clear();
        renderBufferSize_ = 0;
        LOGD("Destroyed");
    }

    bool SetAecEnabled(bool enabled) {
        aecEnabled_ = enabled;
        LOGD("AEC enabled: %d", enabled);
        return true;
    }

    bool SetAecSuppressionLevel(int level) {
        aecSuppressionLevel_ = std::clamp(level, 0, 2);
        LOGD("AEC suppression level: %d", aecSuppressionLevel_);
        return true;
    }

    bool SetNsEnabled(bool enabled) {
        nsEnabled_ = enabled;
        LOGD("NS enabled: %d", enabled);
        return true;
    }

    bool SetNsSuppressionLevel(int level) {
        nsSuppressionLevel_ = std::clamp(level, 0, 3);
        LOGD("NS suppression level: %d", nsSuppressionLevel_);
        return true;
    }

    bool SetAgcEnabled(bool enabled) {
        agcEnabled_ = enabled;
        LOGD("AGC enabled: %d", enabled);
        return true;
    }

    bool SetAgcMode(int mode) {
        agcMode_ = std::clamp(mode, 0, 2);
        LOGD("AGC mode: %d", agcMode_);
        return true;
    }

    bool SetAgcTargetLevel(int targetLevelDbfs) {
        agcTargetLevel_ = std::clamp(targetLevelDbfs, 0, 31);
        LOGD("AGC target level: %d", agcTargetLevel_);
        return true;
    }

    int ProcessCaptureFrame(const int16_t* audioData, int sampleCount, int16_t* outputData) {
        if (!audioData || !outputData || sampleCount <= 0) {
            return 0;
        }

        // 复制输入到输出
        std::memcpy(outputData, audioData, sampleCount * sizeof(int16_t));

        // 应用 AEC（简化版：如果检测到与参考信号相似，则衰减）
        if (aecEnabled_ && renderBufferSize_ > 0) {
            ApplyEchoCancellation(outputData, sampleCount);
        }

        // 应用 NS（简化版：低通滤波去除高频噪声）
        if (nsEnabled_) {
            ApplyNoiseSuppression(outputData, sampleCount);
        }

        // 应用 AGC（自动增益控制）
        if (agcEnabled_) {
            ApplyGainControl(outputData, sampleCount);
        }

        return sampleCount;
    }

    bool ProcessRenderFrame(const int16_t* audioData, int sampleCount) {
        if (!audioData || sampleCount <= 0) {
            return false;
        }

        // 更新参考信号缓冲区（循环缓冲）
        int copySize = std::min(sampleCount, static_cast<int>(renderBuffer_.size()));
        if (copySize > 0) {
            // 移动旧数据
            int shiftSize = renderBuffer_.size() - copySize;
            if (shiftSize > 0) {
                std::memmove(renderBuffer_.data(), renderBuffer_.data() + copySize, shiftSize * sizeof(int16_t));
            }
            // 复制新数据
            std::memcpy(renderBuffer_.data() + shiftSize, audioData + (sampleCount - copySize), copySize * sizeof(int16_t));
            renderBufferSize_ = std::min(renderBufferSize_ + sampleCount, static_cast<int>(renderBuffer_.size()));
        }

        return true;
    }

private:
    /**
     * 简化的回声消除
     *
     * 原理：计算输入与参考信号的相关性，如果高度相关则衰减
     */
    void ApplyEchoCancellation(int16_t* data, int sampleCount) {
        if (renderBufferSize_ <= 0) return;

        // 计算相关性
        float correlation = CalculateCorrelation(data, sampleCount);

        // 根据抑制级别和相关性决定衰减系数
        float suppressionFactors[] = {0.7f, 0.5f, 0.3f}; // low, moderate, high
        float suppressionFactor = suppressionFactors[aecSuppressionLevel_];

        // 如果相关性高，应用衰减
        if (correlation > 0.5f) {
            float attenuation = 1.0f - (correlation * suppressionFactor);
            attenuation = std::max(attenuation, 0.1f);

            for (int i = 0; i < sampleCount; ++i) {
                data[i] = static_cast<int16_t>(data[i] * attenuation);
            }

            LOGD("AEC: correlation=%.2f, attenuation=%.2f", correlation, attenuation);
        }
    }

    /**
     * 计算与参考信号的相关性
     */
    float CalculateCorrelation(const int16_t* data, int sampleCount) {
        if (renderBufferSize_ <= 0 || sampleCount <= 0) return 0.0f;

        int compareSize = std::min(sampleCount, renderBufferSize_);
        int startOffset = renderBuffer_.size() - renderBufferSize_;

        float sumXY = 0.0f;
        float sumX2 = 0.0f;
        float sumY2 = 0.0f;

        for (int i = 0; i < compareSize; ++i) {
            float x = static_cast<float>(data[i]);
            float y = static_cast<float>(renderBuffer_[startOffset + i]);
            sumXY += x * y;
            sumX2 += x * x;
            sumY2 += y * y;
        }

        if (sumX2 < 1.0f || sumY2 < 1.0f) return 0.0f;

        return std::abs(sumXY) / std::sqrt(sumX2 * sumY2);
    }

    /**
     * 简化的噪声抑制
     *
     * 使用移动平均滤波器平滑信号
     * 注意：对于小声信号，减少抑制强度以保留语音
     */
    void ApplyNoiseSuppression(int16_t* data, int sampleCount) {
        if (sampleCount < 3) return;

        // 先计算信号强度
        int64_t sumSquares = 0;
        for (int i = 0; i < sampleCount; ++i) {
            sumSquares += static_cast<int64_t>(data[i]) * data[i];
        }
        float rms = std::sqrt(static_cast<float>(sumSquares) / sampleCount);

        // 如果信号较弱（可能是小声说话），减少噪声抑制强度
        // 避免把小声说话当作噪音滤掉
        int effectiveLevel = nsSuppressionLevel_;
        if (rms < 500.0f && rms > 20.0f) {
            // 小声信号，降低抑制级别
            effectiveLevel = std::max(0, effectiveLevel - 1);
        }

        // 根据抑制级别决定滤波器大小
        int filterSizes[] = {3, 3, 5, 7}; // 减小滤波器尺寸
        int filterSize = filterSizes[effectiveLevel];
        int halfFilter = filterSize / 2;

        std::vector<int16_t> filtered(sampleCount);

        for (int i = 0; i < sampleCount; ++i) {
            int sum = 0;
            int count = 0;

            for (int j = -halfFilter; j <= halfFilter; ++j) {
                int idx = i + j;
                if (idx >= 0 && idx < sampleCount) {
                    sum += data[idx];
                    count++;
                }
            }

            filtered[i] = static_cast<int16_t>(sum / count);
        }

        // 混合原始信号和滤波信号
        // 提高原始信号比例，保留更多语音细节
        float mixFactors[] = {0.9f, 0.8f, 0.7f, 0.6f}; // 原来是 0.8, 0.6, 0.4, 0.2
        float mix = mixFactors[effectiveLevel];

        for (int i = 0; i < sampleCount; ++i) {
            data[i] = static_cast<int16_t>(data[i] * mix + filtered[i] * (1.0f - mix));
        }
    }

    /**
     * 简化的自动增益控制
     */
    void ApplyGainControl(int16_t* data, int sampleCount) {
        if (sampleCount <= 0) return;

        // 计算当前音量
        int64_t sumSquares = 0;
        for (int i = 0; i < sampleCount; ++i) {
            sumSquares += static_cast<int64_t>(data[i]) * data[i];
        }
        float rms = std::sqrt(static_cast<float>(sumSquares) / sampleCount);

        // 目标 RMS（基于 target level dBFS）
        // dBFS = 20 * log10(value / 32768)
        // 3 dBFS 约等于 RMS 23000
        float targetRms = 32768.0f * std::pow(10.0f, -agcTargetLevel_ / 20.0f);

        // 降低阈值到 20，允许处理更小的声音
        // 原来 100 太高，会过滤掉小声说话
        if (rms < 20.0f) {
            // 信号太弱（基本是静音），跳过
            return;
        }

        // 计算增益
        float gain = targetRms / rms;

        // 扩大增益范围，允许更大的放大倍数（0.5x - 10x）
        // 这样小声说话也能被放大
        gain = std::clamp(gain, 0.5f, 10.0f);

        // 应用增益
        for (int i = 0; i < sampleCount; ++i) {
            int32_t sample = static_cast<int32_t>(data[i] * gain);
            // 防止溢出
            data[i] = static_cast<int16_t>(std::clamp(sample, -32768, 32767));
        }
    }

    bool aecEnabled_;
    bool nsEnabled_;
    bool agcEnabled_;
    int aecSuppressionLevel_;
    int nsSuppressionLevel_;
    int agcMode_;
    int agcTargetLevel_;
    int sampleRate_;
    int channels_;

    // 参考信号缓冲区（用于 AEC）
    std::vector<int16_t> renderBuffer_;
    int renderBufferSize_;
};

// AudioProcessor 实现
AudioProcessor::AudioProcessor() : impl_(std::make_unique<Impl>()), initialized_(false) {}

AudioProcessor::~AudioProcessor() {
    Destroy();
}

bool AudioProcessor::Initialize(int sampleRate, int channels) {
    if (initialized_) return true;

    sampleRate_ = sampleRate;
    channels_ = channels;

    if (impl_->Initialize(sampleRate, channels)) {
        initialized_ = true;
        return true;
    }
    return false;
}

void AudioProcessor::Destroy() {
    if (!initialized_) return;
    impl_->Destroy();
    initialized_ = false;
}

bool AudioProcessor::SetAecEnabled(bool enabled) {
    return initialized_ && impl_->SetAecEnabled(enabled);
}

bool AudioProcessor::SetAecSuppressionLevel(int level) {
    return initialized_ && impl_->SetAecSuppressionLevel(level);
}

bool AudioProcessor::SetNsEnabled(bool enabled) {
    return initialized_ && impl_->SetNsEnabled(enabled);
}

bool AudioProcessor::SetNsSuppressionLevel(int level) {
    return initialized_ && impl_->SetNsSuppressionLevel(level);
}

bool AudioProcessor::SetAgcEnabled(bool enabled) {
    return initialized_ && impl_->SetAgcEnabled(enabled);
}

bool AudioProcessor::SetAgcMode(int mode) {
    return initialized_ && impl_->SetAgcMode(mode);
}

bool AudioProcessor::SetAgcTargetLevel(int targetLevelDbfs) {
    return initialized_ && impl_->SetAgcTargetLevel(targetLevelDbfs);
}

int AudioProcessor::ProcessCaptureFrame(const int16_t* audioData, int size, int16_t* outputData) {
    if (!initialized_) {
        std::memcpy(outputData, audioData, size * sizeof(int16_t));
        return size;
    }
    return impl_->ProcessCaptureFrame(audioData, size, outputData);
}

bool AudioProcessor::ProcessRenderFrame(const int16_t* audioData, int size) {
    return initialized_ && impl_->ProcessRenderFrame(audioData, size);
}

} // namespace webrtc_apm

#ifndef AUDIO_PROCESSOR_H
#define AUDIO_PROCESSOR_H

#include <cstdint>
#include <vector>
#include <memory>

namespace webrtc_apm {

/**
 * 音频处理器
 *
 * 封装 WebRTC APM 的功能
 */
class AudioProcessor {
public:
    AudioProcessor();
    ~AudioProcessor();

    /**
     * 初始化处理器
     * @param sampleRate 采样率（如 16000）
     * @param channels 声道数（如 1）
     * @return 是否成功
     */
    bool Initialize(int sampleRate, int channels);

    /**
     * 释放资源
     */
    void Destroy();

    // AEC 配置
    bool SetAecEnabled(bool enabled);
    bool SetAecSuppressionLevel(int level);

    // NS 配置
    bool SetNsEnabled(bool enabled);
    bool SetNsSuppressionLevel(int level);

    // AGC 配置
    bool SetAgcEnabled(bool enabled);
    bool SetAgcMode(int mode);
    bool SetAgcTargetLevel(int targetLevelDbfs);

    /**
     * 处理捕获的音频（麦克风输入）
     * @param audioData PCM16 音频数据
     * @param size 数据大小
     * @param outputData 输出缓冲区
     * @return 处理后的数据大小
     */
    int ProcessCaptureFrame(const int16_t* audioData, int size, int16_t* outputData);

    /**
     * 处理渲染的音频（扬声器输出/TTS 参考信号）
     * @param audioData PCM16 音频数据
     * @param size 数据大小
     * @return 是否成功
     */
    bool ProcessRenderFrame(const int16_t* audioData, int size);

private:
    class Impl;
    std::unique_ptr<Impl> impl_;

    bool initialized_;
    int sampleRate_;
    int channels_;
};

} // namespace webrtc_apm

#endif // AUDIO_PROCESSOR_H

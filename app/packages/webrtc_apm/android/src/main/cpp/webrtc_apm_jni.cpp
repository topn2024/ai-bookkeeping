#include <jni.h>
#include <android/log.h>
#include "include/audio_processor.h"
#include <map>
#include <mutex>

#define LOG_TAG "WebRTC_APM_JNI"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {
    std::map<jlong, webrtc_apm::AudioProcessor*> processors;
    std::mutex processorsMutex;
    jlong nextHandle = 1;

    webrtc_apm::AudioProcessor* GetProcessor(jlong handle) {
        std::lock_guard<std::mutex> lock(processorsMutex);
        auto it = processors.find(handle);
        return (it != processors.end()) ? it->second : nullptr;
    }
}

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_anthropic_webrtc_1apm_WebrtcAudioProcessor_nativeCreate(
        JNIEnv* env,
        jobject /* this */,
        jint sampleRate,
        jint channels) {
    LOGD("nativeCreate: sampleRate=%d, channels=%d", sampleRate, channels);

    auto* processor = new webrtc_apm::AudioProcessor();
    if (!processor->Initialize(sampleRate, channels)) {
        LOGE("Failed to initialize processor");
        delete processor;
        return 0;
    }

    std::lock_guard<std::mutex> lock(processorsMutex);
    jlong handle = nextHandle++;
    processors[handle] = processor;

    LOGD("Created processor with handle: %lld", (long long)handle);
    return handle;
}

JNIEXPORT void JNICALL
Java_com_anthropic_webrtc_1apm_WebrtcAudioProcessor_nativeDestroy(
        JNIEnv* env,
        jobject /* this */,
        jlong handle) {
    LOGD("nativeDestroy: handle=%lld", (long long)handle);

    std::lock_guard<std::mutex> lock(processorsMutex);
    auto it = processors.find(handle);
    if (it != processors.end()) {
        it->second->Destroy();
        delete it->second;
        processors.erase(it);
        LOGD("Destroyed processor");
    }
}

JNIEXPORT jboolean JNICALL
Java_com_anthropic_webrtc_1apm_WebrtcAudioProcessor_nativeSetAecEnabled(
        JNIEnv* env,
        jobject /* this */,
        jlong handle,
        jboolean enabled) {
    auto* processor = GetProcessor(handle);
    if (!processor) return JNI_FALSE;
    return processor->SetAecEnabled(enabled) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_anthropic_webrtc_1apm_WebrtcAudioProcessor_nativeSetAecSuppressionLevel(
        JNIEnv* env,
        jobject /* this */,
        jlong handle,
        jint level) {
    auto* processor = GetProcessor(handle);
    if (!processor) return JNI_FALSE;
    return processor->SetAecSuppressionLevel(level) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_anthropic_webrtc_1apm_WebrtcAudioProcessor_nativeSetNsEnabled(
        JNIEnv* env,
        jobject /* this */,
        jlong handle,
        jboolean enabled) {
    auto* processor = GetProcessor(handle);
    if (!processor) return JNI_FALSE;
    return processor->SetNsEnabled(enabled) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_anthropic_webrtc_1apm_WebrtcAudioProcessor_nativeSetNsSuppressionLevel(
        JNIEnv* env,
        jobject /* this */,
        jlong handle,
        jint level) {
    auto* processor = GetProcessor(handle);
    if (!processor) return JNI_FALSE;
    return processor->SetNsSuppressionLevel(level) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_anthropic_webrtc_1apm_WebrtcAudioProcessor_nativeSetAgcEnabled(
        JNIEnv* env,
        jobject /* this */,
        jlong handle,
        jboolean enabled) {
    auto* processor = GetProcessor(handle);
    if (!processor) return JNI_FALSE;
    return processor->SetAgcEnabled(enabled) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_anthropic_webrtc_1apm_WebrtcAudioProcessor_nativeSetAgcMode(
        JNIEnv* env,
        jobject /* this */,
        jlong handle,
        jint mode) {
    auto* processor = GetProcessor(handle);
    if (!processor) return JNI_FALSE;
    return processor->SetAgcMode(mode) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_anthropic_webrtc_1apm_WebrtcAudioProcessor_nativeSetAgcTargetLevel(
        JNIEnv* env,
        jobject /* this */,
        jlong handle,
        jint targetLevelDbfs) {
    auto* processor = GetProcessor(handle);
    if (!processor) return JNI_FALSE;
    return processor->SetAgcTargetLevel(targetLevelDbfs) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jbyteArray JNICALL
Java_com_anthropic_webrtc_1apm_WebrtcAudioProcessor_nativeProcessCaptureFrame(
        JNIEnv* env,
        jobject /* this */,
        jlong handle,
        jbyteArray audioData) {
    auto* processor = GetProcessor(handle);
    if (!processor || !audioData) {
        return audioData;
    }

    jsize length = env->GetArrayLength(audioData);
    if (length <= 0) {
        return audioData;
    }

    // 获取输入数据
    jbyte* inputBytes = env->GetByteArrayElements(audioData, nullptr);
    if (!inputBytes) {
        return audioData;
    }

    // PCM16 格式：每个样本 2 字节
    int sampleCount = length / 2;
    auto* inputData = reinterpret_cast<const int16_t*>(inputBytes);

    // 分配输出缓冲区
    std::vector<int16_t> outputBuffer(sampleCount);

    // 处理音频
    int processedCount = processor->ProcessCaptureFrame(inputData, sampleCount, outputBuffer.data());

    // 释放输入数据
    env->ReleaseByteArrayElements(audioData, inputBytes, JNI_ABORT);

    // 创建输出数组
    jbyteArray outputArray = env->NewByteArray(processedCount * 2);
    if (outputArray) {
        env->SetByteArrayRegion(outputArray, 0, processedCount * 2,
                                reinterpret_cast<const jbyte*>(outputBuffer.data()));
    }

    return outputArray ? outputArray : audioData;
}

JNIEXPORT jboolean JNICALL
Java_com_anthropic_webrtc_1apm_WebrtcAudioProcessor_nativeProcessRenderFrame(
        JNIEnv* env,
        jobject /* this */,
        jlong handle,
        jbyteArray audioData) {
    auto* processor = GetProcessor(handle);
    if (!processor || !audioData) {
        return JNI_FALSE;
    }

    jsize length = env->GetArrayLength(audioData);
    if (length <= 0) {
        return JNI_FALSE;
    }

    // 获取输入数据
    jbyte* inputBytes = env->GetByteArrayElements(audioData, nullptr);
    if (!inputBytes) {
        return JNI_FALSE;
    }

    // PCM16 格式：每个样本 2 字节
    int sampleCount = length / 2;
    auto* inputData = reinterpret_cast<const int16_t*>(inputBytes);

    // 处理参考信号
    bool result = processor->ProcessRenderFrame(inputData, sampleCount);

    // 释放输入数据
    env->ReleaseByteArrayElements(audioData, inputBytes, JNI_ABORT);

    return result ? JNI_TRUE : JNI_FALSE;
}

} // extern "C"

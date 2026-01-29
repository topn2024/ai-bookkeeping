/**
 * 安全密钥存储 - Native层
 *
 * 密钥经过XOR加密和拆分存储，运行时解密组装。
 * 比纯Dart代码更难逆向工程。
 */

#include <jni.h>
#include <string.h>
#include <stdlib.h>

// XOR加密密钥
static const unsigned char XOR_KEY[] = {0x4B, 0x5A, 0x3C, 0x7F, 0x2E, 0x9A, 0x1D, 0x8B};
static const size_t XOR_KEY_LEN = 8;

// XOR解密函数
static void xor_decrypt(const unsigned char* src, char* dest, size_t len) {
    for (size_t i = 0; i < len; i++) {
        dest[i] = src[i] ^ XOR_KEY[i % XOR_KEY_LEN];
    }
}

// 阿里云 AccessKey ID (XOR加密后的字节数组)
static const unsigned char AK_ID_ENC[] = {
    0x07, 0x0E, 0x7D, 0x36, 0x1B, 0xEE, 0x56, 0xB3,
    0x3D, 0x1C, 0x64, 0x4C, 0x74, 0xD7, 0x7F, 0xC9,
    0x3F, 0x2C, 0x55, 0x3E, 0x79, 0xF9, 0x4A, 0xE0
};
static const size_t AK_ID_LEN = 24;

// 阿里云 AccessKey Secret (XOR加密后的字节数组)
static const unsigned char AK_SEC_ENC[] = {
    0x26, 0x68, 0x50, 0x39, 0x4B, 0xCA, 0x2A, 0xC4,
    0x78, 0x30, 0x0B, 0x37, 0x5E, 0xCE, 0x2E, 0xFD,
    0x0F, 0x17, 0x4F, 0x0F, 0x1A, 0xAB, 0x75, 0xC1,
    0x11, 0x30, 0x4D, 0x18, 0x4D, 0xEC
};
static const size_t AK_SEC_LEN = 30;

// 阿里云 AppKey (XOR加密后的字节数组)
static const unsigned char APP_KEY_ENC[] = {
    0x08, 0x62, 0x7A, 0x4F, 0x4A, 0xE0, 0x2D, 0xE2,
    0x23, 0x1C, 0x51, 0x09, 0x65, 0xD2, 0x25, 0xCC
};
static const size_t APP_KEY_LEN = 16;

// 通义千问 API Key (XOR加密后的字节数组)
static const unsigned char QWEN_ENC[] = {
    0x38, 0x31, 0x11, 0x19, 0x1E, 0xFB, 0x25, 0xBE,
    0x2F, 0x69, 0x59, 0x4A, 0x18, 0xFB, 0x2A, 0xBF,
    0x7D, 0x6F, 0x0C, 0x46, 0x4B, 0xF9, 0x29, 0xB8,
    0x7E, 0x3B, 0x5A, 0x4D, 0x1A, 0xAE, 0x2B, 0xE8,
    0x7D, 0x6D, 0x5D
};
static const size_t QWEN_LEN = 35;

// 组装解密后的密钥
static char* decrypt_key(const unsigned char* enc, size_t len) {
    char* result = (char*)malloc(len + 1);
    if (!result) return NULL;

    xor_decrypt(enc, result, len);
    result[len] = '\0';

    return result;
}

JNIEXPORT jstring JNICALL
Java_com_example_ai_1bookkeeping_SecureKeyStore_getAliyunAccessKeyId(JNIEnv *env, jobject thiz) {
    char* key = decrypt_key(AK_ID_ENC, AK_ID_LEN);
    if (!key) return NULL;

    jstring result = (*env)->NewStringUTF(env, key);

    // 清除内存中的密钥
    memset(key, 0, AK_ID_LEN);
    free(key);

    return result;
}

JNIEXPORT jstring JNICALL
Java_com_example_ai_1bookkeeping_SecureKeyStore_getAliyunAccessKeySecret(JNIEnv *env, jobject thiz) {
    char* key = decrypt_key(AK_SEC_ENC, AK_SEC_LEN);
    if (!key) return NULL;

    jstring result = (*env)->NewStringUTF(env, key);

    memset(key, 0, AK_SEC_LEN);
    free(key);

    return result;
}

JNIEXPORT jstring JNICALL
Java_com_example_ai_1bookkeeping_SecureKeyStore_getAliyunAppKey(JNIEnv *env, jobject thiz) {
    char* key = decrypt_key(APP_KEY_ENC, APP_KEY_LEN);
    if (!key) return NULL;

    jstring result = (*env)->NewStringUTF(env, key);

    memset(key, 0, APP_KEY_LEN);
    free(key);

    return result;
}

JNIEXPORT jstring JNICALL
Java_com_example_ai_1bookkeeping_SecureKeyStore_getQwenApiKey(JNIEnv *env, jobject thiz) {
    char* key = decrypt_key(QWEN_ENC, QWEN_LEN);
    if (!key) return NULL;

    jstring result = (*env)->NewStringUTF(env, key);

    memset(key, 0, QWEN_LEN);
    free(key);

    return result;
}

// ASR URL (不需要混淆，是公开的)
JNIEXPORT jstring JNICALL
Java_com_example_ai_1bookkeeping_SecureKeyStore_getAsrUrl(JNIEnv *env, jobject thiz) {
    return (*env)->NewStringUTF(env, "wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1");
}

JNIEXPORT jstring JNICALL
Java_com_example_ai_1bookkeeping_SecureKeyStore_getAsrRestUrl(JNIEnv *env, jobject thiz) {
    return (*env)->NewStringUTF(env, "https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/asr");
}

JNIEXPORT jstring JNICALL
Java_com_example_ai_1bookkeeping_SecureKeyStore_getTtsUrl(JNIEnv *env, jobject thiz) {
    return (*env)->NewStringUTF(env, "wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1");
}

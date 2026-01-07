/*
 * bspatch_jni.c - JNI wrapper for bspatch
 *
 * Provides Java/Kotlin interface to the bspatch native library.
 */

#include <jni.h>
#include <string.h>
#include <android/log.h>
#include "bspatch.h"

#define LOG_TAG "BsPatch"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/*
 * Class:     com_example_ai_bookkeeping_BsPatchHelper
 * Method:    applyPatch
 * Signature: (Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)I
 */
JNIEXPORT jint JNICALL
Java_com_example_ai_1bookkeeping_BsPatchHelper_applyPatch(
    JNIEnv *env,
    jclass clazz,
    jstring old_path,
    jstring new_path,
    jstring patch_path
) {
    const char *old_path_c = (*env)->GetStringUTFChars(env, old_path, NULL);
    const char *new_path_c = (*env)->GetStringUTFChars(env, new_path, NULL);
    const char *patch_path_c = (*env)->GetStringUTFChars(env, patch_path, NULL);

    if (!old_path_c || !new_path_c || !patch_path_c) {
        LOGE("Failed to get string paths");
        if (old_path_c) (*env)->ReleaseStringUTFChars(env, old_path, old_path_c);
        if (new_path_c) (*env)->ReleaseStringUTFChars(env, new_path, new_path_c);
        if (patch_path_c) (*env)->ReleaseStringUTFChars(env, patch_path, patch_path_c);
        return -10;  /* Memory allocation failed */
    }

    LOGI("Applying patch: %s + %s -> %s", old_path_c, patch_path_c, new_path_c);

    int result = bspatch(old_path_c, new_path_c, patch_path_c);

    if (result == 0) {
        LOGI("Patch applied successfully");
    } else {
        LOGE("Patch failed with error: %d (%s)", result, bspatch_strerror(result));
    }

    (*env)->ReleaseStringUTFChars(env, old_path, old_path_c);
    (*env)->ReleaseStringUTFChars(env, new_path, new_path_c);
    (*env)->ReleaseStringUTFChars(env, patch_path, patch_path_c);

    return result;
}

/*
 * Class:     com_example_ai_bookkeeping_BsPatchHelper
 * Method:    getErrorMessage
 * Signature: (I)Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL
Java_com_example_ai_1bookkeeping_BsPatchHelper_getErrorMessage(
    JNIEnv *env,
    jclass clazz,
    jint error_code
) {
    const char *msg = bspatch_strerror(error_code);
    return (*env)->NewStringUTF(env, msg);
}

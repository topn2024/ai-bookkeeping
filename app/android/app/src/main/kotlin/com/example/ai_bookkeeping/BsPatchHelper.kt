package com.example.ai_bookkeeping

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log
import java.io.File
import java.security.MessageDigest

/**
 * Helper class for bspatch operations.
 *
 * Provides:
 * - Native bspatch functionality for incremental updates
 * - APK path retrieval
 * - MD5 verification
 */
object BsPatchHelper {
    private const val TAG = "BsPatchHelper"

    init {
        try {
            System.loadLibrary("bspatch")
            Log.i(TAG, "bspatch library loaded successfully")
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "Failed to load bspatch library: ${e.message}")
        }
    }

    /**
     * Apply a bsdiff patch to create a new APK.
     *
     * @param oldPath Path to the original APK
     * @param newPath Path for the output (patched) APK
     * @param patchPath Path to the patch file
     * @return 0 on success, negative error code on failure
     */
    @JvmStatic
    external fun applyPatch(oldPath: String, newPath: String, patchPath: String): Int

    /**
     * Get error message for a bspatch error code.
     *
     * @param errorCode The error code returned by applyPatch
     * @return Human-readable error message
     */
    @JvmStatic
    external fun getErrorMessage(errorCode: Int): String

    /**
     * Get the path to the currently installed APK.
     *
     * @param context Application context
     * @return Path to the current APK, or null if not found
     */
    @JvmStatic
    fun getCurrentApkPath(context: Context): String? {
        return try {
            val applicationInfo: ApplicationInfo = context.applicationInfo
            val apkPath = applicationInfo.sourceDir
            Log.i(TAG, "Current APK path: $apkPath")

            // Verify file exists
            if (File(apkPath).exists()) {
                apkPath
            } else {
                Log.w(TAG, "APK file does not exist: $apkPath")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get current APK path: ${e.message}")
            null
        }
    }

    /**
     * Calculate MD5 hash of a file.
     *
     * @param filePath Path to the file
     * @return MD5 hash as lowercase hex string, or null on error
     */
    @JvmStatic
    fun calculateMd5(filePath: String): String? {
        return try {
            val file = File(filePath)
            if (!file.exists()) {
                Log.w(TAG, "File does not exist for MD5 calculation: $filePath")
                return null
            }

            val md = MessageDigest.getInstance("MD5")
            file.inputStream().use { fis ->
                val buffer = ByteArray(8192)
                var bytesRead: Int
                while (fis.read(buffer).also { bytesRead = it } != -1) {
                    md.update(buffer, 0, bytesRead)
                }
            }

            val digest = md.digest()
            val hexString = StringBuilder()
            for (b in digest) {
                val hex = Integer.toHexString(0xff and b.toInt())
                if (hex.length == 1) hexString.append('0')
                hexString.append(hex)
            }

            hexString.toString().lowercase()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to calculate MD5: ${e.message}")
            null
        }
    }

    /**
     * Apply patch with MD5 verification.
     *
     * @param context Application context
     * @param patchPath Path to the patch file
     * @param outputPath Path for the output APK
     * @param expectedMd5 Expected MD5 of the output APK (optional)
     * @return Result containing success status and output path or error message
     */
    @JvmStatic
    fun applyPatchWithVerification(
        context: Context,
        patchPath: String,
        outputPath: String,
        expectedMd5: String? = null
    ): PatchResult {
        // Get current APK path
        val currentApkPath = getCurrentApkPath(context)
            ?: return PatchResult.failure("Cannot get current APK path")

        // Verify patch file exists
        if (!File(patchPath).exists()) {
            return PatchResult.failure("Patch file does not exist: $patchPath")
        }

        Log.i(TAG, "Applying patch: $currentApkPath + $patchPath -> $outputPath")

        // Apply patch
        val result = applyPatch(currentApkPath, outputPath, patchPath)
        if (result != 0) {
            val errorMsg = getErrorMessage(result)
            Log.e(TAG, "Patch failed: $errorMsg (code: $result)")
            return PatchResult.failure("Patch failed: $errorMsg")
        }

        // Verify output file exists
        val outputFile = File(outputPath)
        if (!outputFile.exists()) {
            return PatchResult.failure("Output file was not created")
        }

        // Verify MD5 if provided
        if (expectedMd5 != null && expectedMd5.isNotEmpty()) {
            val actualMd5 = calculateMd5(outputPath)
            if (actualMd5 == null) {
                outputFile.delete()
                return PatchResult.failure("Failed to calculate output MD5")
            }

            if (actualMd5.lowercase() != expectedMd5.lowercase()) {
                Log.e(TAG, "MD5 mismatch! Expected: $expectedMd5, Actual: $actualMd5")
                outputFile.delete()
                return PatchResult.failure("MD5 verification failed")
            }

            Log.i(TAG, "MD5 verification passed: $actualMd5")
        }

        Log.i(TAG, "Patch applied successfully: $outputPath")
        return PatchResult.success(outputPath)
    }

    /**
     * Result of a patch operation.
     */
    data class PatchResult(
        val success: Boolean,
        val outputPath: String? = null,
        val errorMessage: String? = null
    ) {
        companion object {
            fun success(outputPath: String) = PatchResult(true, outputPath, null)
            fun failure(errorMessage: String) = PatchResult(false, null, errorMessage)
        }
    }
}

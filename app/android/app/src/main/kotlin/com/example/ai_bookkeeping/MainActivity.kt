package com.example.ai_bookkeeping

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.ai_bookkeeping/bspatch"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "applyPatch" -> {
                    val patchPath = call.argument<String>("patch")
                    val outputPath = call.argument<String>("output")
                    val expectedMd5 = call.argument<String>("expectedMd5")

                    if (patchPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "patch and output paths are required", null)
                        return@setMethodCallHandler
                    }

                    // Run patch in background thread
                    Thread {
                        val patchResult = BsPatchHelper.applyPatchWithVerification(
                            context = applicationContext,
                            patchPath = patchPath,
                            outputPath = outputPath,
                            expectedMd5 = expectedMd5
                        )

                        runOnUiThread {
                            if (patchResult.success) {
                                result.success(mapOf(
                                    "success" to true,
                                    "outputPath" to patchResult.outputPath
                                ))
                            } else {
                                result.success(mapOf(
                                    "success" to false,
                                    "error" to patchResult.errorMessage
                                ))
                            }
                        }
                    }.start()
                }

                "getCurrentApkPath" -> {
                    val apkPath = BsPatchHelper.getCurrentApkPath(applicationContext)
                    result.success(apkPath)
                }

                "calculateMd5" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "filePath is required", null)
                        return@setMethodCallHandler
                    }

                    // Run MD5 calculation in background
                    Thread {
                        val md5 = BsPatchHelper.calculateMd5(filePath)
                        runOnUiThread {
                            result.success(md5)
                        }
                    }.start()
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}

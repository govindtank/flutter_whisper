package io.github.govindtank.flutter_whisper

import android.content.Context
import android.media.MediaRecorder
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream

class FlutterWhisperPlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var whisperContext: WhisperContext? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "flutter_whisper")
        channel?.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        whisperContext?.close()
        whisperContext = null
        context = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "transcribeFile" -> transcribeFile(call, result)
            "transcribePcm" -> transcribePcm(call, result)
            "cancel" -> cancel(result)
            "dispose" -> dispose(result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: Result) {
        val modelPath = call.argument<String>("modelPath") ?: return result.error("INVALID_ARGS", "modelPath required", null)
        val options = call.argument<Map<String, Any>>("options") ?: mutableMapOf()

        try {
            // Load model
            val modelFile = File(modelPath)
            if (!modelFile.exists()) {
                // Try to copy from assets
                copyModelFromAssets(modelPath) ?: return result.error("MODEL_NOT_FOUND", "Model file not found", null)
            }

            whisperContext = WhisperContext(modelFile.absolutePath)
            result.success(true)
        } catch (e: UnsatisfiedLinkError) {
            Log.e("FlutterWhisper", "Native whisper library missing", e)
            result.error("NATIVE_NOT_BUILT", "whisper.cpp native library not bundled yet", null)
        } catch (e: Exception) {
            Log.e("FlutterWhisper", "Initialize failed", e)
            result.error("INITIALIZATION_FAILED", e.message, null)
        }
    }

    private fun transcribeFile(call: MethodCall, result: Result) {
        val audioPath = call.argument<String>("audioPath") ?: return result.error("INVALID_ARGS", "audioPath required", null)
        val options = call.argument<Map<String, Any>>("options") ?: mutableMapOf()

        try {
            val whisperContext = this.whisperContext ?: return result.error("NOT_INITIALIZED", "Call initialize first", null)

            // Transcribe
            val transcriptionResult = whisperContext.transcribe(audioPath)

            val segmentsList = mutableListOf<Map<String, Any>>()
            for (segment in transcriptionResult.segments) {
                segmentsList.add(
                    mapOf(
                        "text" to segment.text,
                        "start" to segment.start,
                        "end" to segment.end
                    )
                )
            }

            val resultMap = mutableMapOf<String, Any>()
            resultMap["text"] = transcriptionResult.fullText
            resultMap["segments"] = segmentsList
            resultMap["language"] = transcriptionResult.language
            resultMap["duration"] = transcriptionResult.duration

            result.success(resultMap)
        } catch (e: Exception) {
            Log.e("FlutterWhisper", "Transcription failed", e)
            result.error("TRANSCRIPTION_FAILED", e.message, null)
        }
    }

    private fun transcribePcm(call: MethodCall, result: Result) {
        val pcmData = call.argument<ByteArray>("pcmData") ?: return result.error("INVALID_ARGS", "pcmData required", null)
        val options = call.argument<Map<String, Any>>("options") ?: mutableMapOf()

        // TODO: Implement PCM transcription
        result.error("NOT_IMPLEMENTED", "PCM transcription not yet implemented", null)
    }

    private fun cancel(result: Result) {
        // Cancel any ongoing transcription
        result.success(true)
    }

    private fun dispose(result: Result) {
        whisperContext?.close()
        whisperContext = null
        result.success(true)
    }

    private fun copyModelFromAssets(modelPath: String): String? {
        val context = context ?: return null
        val file = File(modelPath)
        val parentDir = file.parentFile
        parentDir?.mkdirs()

        try {
            val fileName = file.name
            val inputStream = context.assets.open("models/$fileName")
            val outputStream = FileOutputStream(file)
            inputStream.copyTo(outputStream)
            inputStream.close()
            outputStream.close()
            return file.absolutePath
        } catch (e: IOException) {
            Log.e("FlutterWhisper", "Failed to copy model from assets", e)
            return null
        }
    }
}
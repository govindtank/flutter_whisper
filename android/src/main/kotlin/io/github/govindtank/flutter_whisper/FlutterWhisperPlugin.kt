package io.github.govindtank.flutter_whisper

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlin.coroutines.cancellation.CancellationException
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

class FlutterWhisperPlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var whisperContext: WhisperContext? = null

    // Transcribe runs on a worker thread so the UI never freezes.
    private val transcribeExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // Recording state (AudioRecord → 16 kHz mono PCM16 WAV).
    private val recordExecutor = Executors.newSingleThreadExecutor()
    @Volatile private var recording = false
    private var recordFile: File? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "flutter_whisper")
        channel?.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        stopRecordingInternal()
        whisperContext?.close()
        whisperContext = null
        context = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "transcribeFile" -> transcribeFile(call, result)
            "transcribePcm" -> transcribePcm(call, result)
            "startRecording" -> startRecording(result)
            "stopRecording" -> stopRecording(result)
            "cancel" -> cancel(result)
            "dispose" -> dispose(result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: Result) {
        val modelPath = call.argument<String>("modelPath") ?: return result.error("INVALID_ARGS", "modelPath required", null)

        try {
            val modelFile = File(modelPath)
            if (!modelFile.exists()) {
                copyModelFromAssets(modelPath) ?: return result.error("MODEL_NOT_FOUND", "Model file not found", null)
            }

            whisperContext = WhisperContext(modelFile.absolutePath) { percent ->
                // Progress fires from the transcribe worker thread — hop to main.
                mainHandler.post { channel?.invokeMethod("transcribeProgress", percent) }
            }
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
        val language = options["language"] as? String ?: ""

        val ctx = whisperContext ?: return result.error("NOT_INITIALIZED", "Call initialize first", null)

        transcribeExecutor.execute {
            try {
                val transcriptionResult = ctx.transcribe(audioPath, language)

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

                mainHandler.post { result.success(resultMap) }
            } catch (e: CancellationException) {
                mainHandler.post { result.error("TRANSCRIPTION_CANCELLED", "cancelled", null) }
            } catch (e: Exception) {
                Log.e("FlutterWhisper", "Transcription failed", e)
                mainHandler.post { result.error("TRANSCRIPTION_FAILED", e.message, null) }
            }
        }
    }

    private fun transcribePcm(call: MethodCall, result: Result) {
        result.error("NOT_IMPLEMENTED", "PCM transcription not yet implemented — use startRecording/stopRecording", null)
    }

    private fun startRecording(result: Result) {
        if (recording) return result.error("ALREADY_RECORDING", "Already recording", null)
        val ctx = context ?: return result.error("NO_CONTEXT", "Plugin detached", null)

        val sampleRate = 16000
        val bufSize = AudioRecord.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (bufSize <= 0) return result.error("MIC_UNAVAILABLE", "No usable audio buffer", null)

        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.MIC, sampleRate,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, bufSize * 2
            )
        } catch (e: Exception) {
            return result.error("MIC_UNAVAILABLE", e.message, null)
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return result.error("MIC_UNAVAILABLE", "Microphone not available", null)
        }

        val dir = File(ctx.filesDir, "recordings").apply { mkdirs() }
        val file = File(dir, "rec_${System.currentTimeMillis()}.wav")
        val fos = try {
            FileOutputStream(file).also { writeWavHeader(it, 0) }
        } catch (e: IOException) {
            record.release()
            return result.error("WRITE_FAILED", e.message, null)
        }

        recording = true
        recordFile = file
        record.startRecording()

        recordExecutor.execute {
            try {
                val buf = ByteArray(bufSize)
                while (recording) {
                    val n = record.read(buf, 0, buf.size)
                    if (n > 0) fos.write(buf, 0, n)
                }
            } catch (e: Exception) {
                Log.e("FlutterWhisper", "Recording loop failed", e)
            } finally {
                try { record.stop() } catch (_: Exception) {}
                record.release()
                try {
                    fos.flush()
                    patchWavHeader(file)
                    fos.close()
                } catch (e: IOException) {
                    Log.e("FlutterWhisper", "Finalize wav failed", e)
                }
            }
        }
        result.success(true)
    }

    private fun stopRecording(result: Result) {
        if (!recording) return result.error("NOT_RECORDING", "Not recording", null)
        recording = false
        // Ordered after the recording loop on the same executor: the loop has
        // flushed + patched the header by the time we resolve with the path.
        recordExecutor.execute { result.success(recordFile?.absolutePath) }
    }

    private fun stopRecordingInternal() {
        if (recording) {
            recording = false
        }
    }

    private fun cancel(result: Result) {
        whisperContext?.cancel()
        result.success(true)
    }

    private fun dispose(result: Result) {
        stopRecordingInternal()
        whisperContext?.close()
        whisperContext = null
        result.success(true)
    }

    private fun copyModelFromAssets(modelPath: String): String? {
        val context = context ?: return null
        val file = File(modelPath)
        file.parentFile?.mkdirs()

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

    companion object {
        /** Writes a 44-byte PCM WAV header (16 kHz mono 16-bit). */
        fun writeWavHeader(fos: FileOutputStream, dataSize: Int) {
            val h = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
            h.put("RIFF".toByteArray()); h.putInt(36 + dataSize)
            h.put("WAVE".toByteArray())
            h.put("fmt ".toByteArray()); h.putInt(16)
            h.putShort(1); h.putShort(1)
            h.putInt(16000); h.putInt(32000)
            h.putShort(2); h.putShort(16)
            h.put("data".toByteArray()); h.putInt(dataSize)
            fos.write(h.array())
        }

        /** Rewrites RIFF/data sizes now that PCM is known. */
        fun patchWavHeader(file: File) {
            val dataSize = (file.length() - 44).toInt().coerceAtLeast(0)
            RandomAccessFile(file, "rw").use { raf ->
                raf.seek(4); raf.writeInt(36 + dataSize)
                raf.seek(40); raf.writeInt(dataSize)
            }
        }
    }
}

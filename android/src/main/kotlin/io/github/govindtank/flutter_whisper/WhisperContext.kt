package io.github.govindtank.flutter_whisper

import android.util.Log
import org.json.JSONObject

/**
 * Android wrapper for whisper.cpp via JNI.
 *
 * Native side is compiled from third_party/whisper.cpp (see
 * src/main/cpp/CMakeLists.txt). Model must be a ggml-*.bin file;
 * audio must be WAV (any rate/channels — resampled to 16 kHz mono natively).
 */
class WhisperContext(private val modelPath: String) {

    private var handle: Long = 0

    init {
        System.loadLibrary("whisper")
        handle = nativeInit(modelPath)
        if (handle == 0L) {
            throw RuntimeException("Failed to initialize whisper context: $modelPath")
        }
        Log.i(TAG, "whisper context initialized")
    }

    private external fun nativeInit(modelPath: String): Long
    private external fun nativeTranscribe(handle: Long, audioPath: String): String
    private external fun nativeFree(handle: Long)

    fun transcribe(audioPath: String): TranscriptionResult {
        val json = nativeTranscribe(handle, audioPath)
        val obj = JSONObject(json)
        val err = obj.optString("error")
        if (err.isNotEmpty()) {
            throw IllegalStateException(err)
        }
        val segments = obj.getJSONArray("segments")
        val segList = mutableListOf<Segment>()
        for (i in 0 until segments.length()) {
            val s = segments.getJSONObject(i)
            segList.add(
                Segment(
                    text = s.getString("text"),
                    start = s.getDouble("start"),
                    end = s.getDouble("end")
                )
            )
        }
        return TranscriptionResult(
            fullText = obj.getString("text"),
            segments = segList,
            language = obj.optString("language"),
            duration = obj.optDouble("duration")
        )
    }

    fun close() {
        if (handle != 0L) {
            nativeFree(handle)
            handle = 0L
        }
    }

    // Data class for transcription results
    data class TranscriptionResult(
        val fullText: String,
        val segments: List<Segment>,
        val language: String,
        val duration: Double
    )

    data class Segment(
        val text: String,
        val start: Double,
        val end: Double
    )

    companion object {
        private const val TAG = "FlutterWhisper"
    }
}

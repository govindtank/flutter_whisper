package io.github.govindtank.flutter_whisper

import android.util.Log
import kotlin.coroutines.cancellation.CancellationException
import org.json.JSONObject

/**
 * Android wrapper for whisper.cpp via JNI.
 *
 * Native side is compiled from third_party/whisper.cpp (see
 * src/main/cpp/CMakeLists.txt). Model must be a ggml-*.bin file;
 * audio can be wav/mp3/flac/ogg — decoded + resampled to 16 kHz mono natively.
 *
 * [onProgress] receives 0..100 during transcription (called from native
 * thread). [cancel] aborts an in-flight transcription at the next segment
 * boundary.
 */
class WhisperContext(
    modelPath: String,
    private val onProgress: (Int) -> Unit,
) {
    private var handle: Long = 0

    init {
        System.loadLibrary("ggml-cpu")
        System.loadLibrary("whisper")
        handle = nativeInit(modelPath)
        if (handle == 0L) {
            throw RuntimeException("Failed to initialize whisper context: $modelPath")
        }
        Log.i(TAG, "whisper context initialized")
    }

    /** Called from native (transcribe worker thread). */
    @Suppress("unused")
    fun onNativeProgress(percent: Int) {
        onProgress(percent)
    }

    private external fun nativeInit(modelPath: String): Long
    private external fun nativeTranscribe(handle: Long, audioPath: String, language: String): String
    private external fun nativeCancel(handle: Long)
    private external fun nativeFree(handle: Long)

    /**
     * Transcribes [audioPath] (blocking — call off the main thread).
     *
     * @throws CancellationException if [cancel] was called mid-transcription.
     */
    fun transcribe(audioPath: String, language: String = ""): TranscriptionResult {
        val json = nativeTranscribe(handle, audioPath, language)
        val obj = JSONObject(json)
        val err = obj.optString("error")
        if (err.isNotEmpty()) {
            if (err == "cancelled") throw CancellationException("Transcription cancelled")
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

    /** Aborts an in-flight transcription. Safe to call from any thread. */
    fun cancel() {
        if (handle != 0L) nativeCancel(handle)
    }

    fun close() {
        if (handle != 0L) {
            nativeFree(handle)
            handle = 0L
        }
    }

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

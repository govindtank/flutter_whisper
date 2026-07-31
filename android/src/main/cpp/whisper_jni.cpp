// JNI bridge: whisper.cpp → Kotlin (io.github.govindtank.flutter_whisper.WhisperContext)
// Protocol: nativeTranscribe returns a JSON string:
//   {"text": "...", "language": "en", "duration": 3.2,
//    "segments": [{"text": "...", "start": 0.0, "end": 1.5}]}
#include <jni.h>
#include <string>
#include <vector>
#include <sstream>
#include <cmath>
#include <cstring>

#include "whisper.h"

#define MA_NO_DEVICE_IO
#define MA_NO_THREADING
#define MA_NO_ENCODING
#define MA_NO_GENERATION
#define MA_NO_RESOURCE_MANAGER
#define MA_NO_NODE_GRAPH
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

// Escapes a string for embedding inside a JSON string literal.
static std::string json_escape(const std::string& s) {
    std::string out;
    out.reserve(s.size());
    for (char c : s) {
        switch (c) {
            case '"':  out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n";  break;
            case '\r': out += "\\r";  break;
            case '\t': out += "\\t";  break;
            default:   out += c;      break;
        }
    }
    return out;
}

// Reads any audio (wav/mp3/flac/ogg…) into 16 kHz mono float PCM.
// Whisper needs 16k mono — miniaudio resamples for us.
static bool load_audio_16k(const std::string& path, std::vector<float>& out) {
    ma_decoder_config cfg = ma_decoder_config_init(ma_format_f32, 1, 16000);
    ma_decoder decoder;
    if (ma_decoder_init_file(path.c_str(), &cfg, &decoder) != MA_SUCCESS) return false;
    std::vector<float> pcm;
    float buf[4096];
    for (;;) {
        ma_uint64 framesRead = 0;
        const ma_uint64 n = ma_decoder_read_pcm_frames(&decoder, buf, 4096, &framesRead);
        if (n == 0) break;
        pcm.insert(pcm.end(), buf, buf + framesRead);
    }
    ma_decoder_uninit(&decoder);
    out.swap(pcm);
    return !out.empty();
}

static std::string transcribe_json(whisper_context* ctx, const std::string& path) {
    std::vector<float> pcm;
    if (!load_audio_16k(path, pcm)) {
        return "{\"error\":\"cannot decode audio (need WAV; 16 kHz mono recommended)\"}";
    }

    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_realtime = false;
    params.print_progress = false;
    params.print_special = false;
    params.print_timestamps = false;
    params.n_threads = 4;
    params.language = "en";
    params.single_segment = false;

    if (whisper_full(ctx, params, pcm.data(), static_cast<int>(pcm.size())) != 0) {
        return "{\"error\":\"whisper_full failed\"}";
    }

    const int n = whisper_full_n_segments(ctx);
    std::string full;
    std::stringstream segs;
    segs << "[";
    double dur = 0.0;
    for (int i = 0; i < n; ++i) {
        const char* text = whisper_full_get_segment_text(ctx, i);
        if (!text) continue;
        const double t0 = whisper_full_get_segment_t0(ctx, i) / 100.0;
        const double t1 = whisper_full_get_segment_t1(ctx, i) / 100.0;
        if (i > 0) segs << ",";
        segs << "{\"text\":\"" << json_escape(text)
             << "\",\"start\":" << t0
             << ",\"end\":" << t1 << "}";
        full += text;
        dur = t1;
    }
    segs << "]";

    std::stringstream out;
    out << "{\"text\":\"" << json_escape(full)
        << "\",\"language\":\"" << whisper_lang_str(whisper_full_lang_id(ctx))
        << "\",\"duration\":" << dur
        << ",\"segments\":" << segs.str() << "}";
    return out.str();
}

extern "C" JNIEXPORT jlong JNICALL
Java_io_github_govindtank_flutter_whisper_WhisperContext_nativeInit(
    JNIEnv* env, jobject /*thiz*/, jstring jmodel) {
    const char* cpath = env->GetStringUTFChars(jmodel, nullptr);
    std::string model(cpath);
    env->ReleaseStringUTFChars(jmodel, cpath);

    struct whisper_context_params cparams = whisper_context_default_params();
    whisper_context* ctx = whisper_init_from_file_with_params(model.c_str(), cparams);
    return reinterpret_cast<jlong>(ctx);
}

extern "C" JNIEXPORT jstring JNICALL
Java_io_github_govindtank_flutter_whisper_WhisperContext_nativeTranscribe(
    JNIEnv* env, jobject /*thiz*/, jlong handle, jstring jpath) {
    whisper_context* ctx = reinterpret_cast<whisper_context*>(handle);
    if (!ctx) return env->NewStringUTF("{\"error\":\"whisper not initialized\"}");
    const char* cpath = env->GetStringUTFChars(jpath, nullptr);
    std::string path(cpath);
    env->ReleaseStringUTFChars(jpath, cpath);
    std::string result = transcribe_json(ctx, path);
    return env->NewStringUTF(result.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_io_github_govindtank_flutter_whisper_WhisperContext_nativeFree(
    JNIEnv* /*env*/, jobject /*thiz*/, jlong handle) {
    whisper_context* ctx = reinterpret_cast<whisper_context*>(handle);
    if (ctx) whisper_free(ctx);
}

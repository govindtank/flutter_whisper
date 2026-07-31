// JNI bridge: whisper.cpp → Kotlin (io.github.govindtank.flutter_whisper.WhisperContext)
//
// Protocol:
//   nativeInit       → jlong handle (0 on failure)
//   nativeTranscribe → JSON string:
//       {"text":"...","language":"en","duration":3.2,
//        "segments":[{"text":"...","start":0.0,"end":1.5}]}
//       or {"error":"..."} (including "cancelled")
//   nativeCancel     → sets abort flag; in-flight whisper_full stops at next
//                      segment boundary (abort callback)
//   nativeFree       → releases context + JNI global refs
//
// Progress: whisper_full_progress_callback fires Kotlin
// WhisperContext.onNativeProgress(int percent) on the calling thread.
#include <jni.h>
#include <atomic>
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

// ---- JNI callback registry (single active context — see ponytail) ----
static JavaVM* g_vm = nullptr;
static jobject g_target = nullptr;        // global ref to WhisperContext
static jmethodID g_onProgress = nullptr;  // (I)V
static std::atomic<bool> g_abort{false};

bool abort_cb(void* /*user_data*/) { return g_abort.load(); }

void progress_cb(whisper_context* /*ctx*/, whisper_state* /*state*/, int progress, void* /*user_data*/) {
    if (progress < 0 || progress > 100) return;
    JNIEnv* env = nullptr;
    if (g_vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
        // Callback runs on the thread that called whisper_full (an executor
        // thread we attach here).
        g_vm->AttachCurrentThread(&env, nullptr);
    }
    if (env && g_target && g_onProgress) {
        env->CallVoidMethod(g_target, g_onProgress, static_cast<jint>(progress));
    }
}

// ---- audio decode: any format → 16 kHz mono f32 (miniaudio resamples) ----
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

// ---- JSON helpers ----
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

static std::string transcribe_json(whisper_context* ctx, const std::string& path, const std::string& language) {
    std::vector<float> pcm;
    if (!load_audio_16k(path, pcm)) {
        return "{\"error\":\"cannot decode audio (wav/mp3/flac/ogg supported)\"}";
    }

    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_realtime = false;
    params.print_progress = false;
    params.print_special = false;
    params.print_timestamps = false;
    params.n_threads = 4;
    params.single_segment = false;
    params.progress_callback = progress_cb;
    params.abort_callback = abort_cb;
    if (language.empty()) {
        params.language = nullptr;  // auto-detect
    } else {
        params.language = language.c_str();  // lives for duration of whisper_full
    }

    g_abort = false;
    if (whisper_full(ctx, params, pcm.data(), static_cast<int>(pcm.size())) != 0) {
        return "{\"error\":\"whisper_full failed\"}";
    }
    if (g_abort.load()) {
        return "{\"error\":\"cancelled\"}";
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

// ---- JNI exports ----
extern "C" JNIEXPORT jlong JNICALL
Java_io_github_govindtank_flutter_whisper_WhisperContext_nativeInit(
    JNIEnv* env, jobject thiz, jstring jmodel) {
    const char* cpath = env->GetStringUTFChars(jmodel, nullptr);
    std::string model(cpath);
    env->ReleaseStringUTFChars(jmodel, cpath);

    env->GetJavaVM(&g_vm);
    jclass cls = env->GetObjectClass(thiz);
    g_onProgress = env->GetMethodID(cls, "onNativeProgress", "(I)V");
    if (g_target) env->DeleteGlobalRef(g_target);
    g_target = env->NewGlobalRef(thiz);

    struct whisper_context_params cparams = whisper_context_default_params();
    whisper_context* ctx = whisper_init_from_file_with_params(model.c_str(), cparams);
    return reinterpret_cast<jlong>(ctx);
}

extern "C" JNIEXPORT jstring JNICALL
Java_io_github_govindtank_flutter_whisper_WhisperContext_nativeTranscribe(
    JNIEnv* env, jobject /*thiz*/, jlong handle, jstring jpath, jstring jlang) {
    whisper_context* ctx = reinterpret_cast<whisper_context*>(handle);
    if (!ctx) return env->NewStringUTF("{\"error\":\"whisper not initialized\"}");

    const char* cpath = env->GetStringUTFChars(jpath, nullptr);
    std::string path(cpath);
    env->ReleaseStringUTFChars(jpath, cpath);

    std::string language;
    if (jlang && env->GetStringUTFLength(jlang) > 0) {
        const char* clang = env->GetStringUTFChars(jlang, nullptr);
        language = clang;
        env->ReleaseStringUTFChars(jlang, clang);
    }

    std::string result = transcribe_json(ctx, path, language);
    return env->NewStringUTF(result.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_io_github_govindtank_flutter_whisper_WhisperContext_nativeCancel(
    JNIEnv* /*env*/, jobject /*thiz*/, jlong /*handle*/) {
    g_abort = true;
}

extern "C" JNIEXPORT void JNICALL
Java_io_github_govindtank_flutter_whisper_WhisperContext_nativeFree(
    JNIEnv* env, jobject /*thiz*/, jlong handle) {
    whisper_context* ctx = reinterpret_cast<whisper_context*>(handle);
    if (ctx) whisper_free(ctx);
    g_abort = false;
    if (g_target) {
        env->DeleteGlobalRef(g_target);
        g_target = nullptr;
    }
    g_onProgress = nullptr;
}

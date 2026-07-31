import Foundation
import Flutter

@objc public class FlutterWhisperPlugin: NSObject, FlutterPlugin {
    private var whisperContext: WhisperContext?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_whisper", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "flutter_whisper/stream", binaryMessenger: registrar.messenger())
        
        let instance = FlutterWhisperPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    private var whisperContext: WhisperContext?

    @objc public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(call: call, result: result)
        case "transcribeFile":
            transcribeFile(call: call, result: result)
        case "transcribePcm":
            transcribePcm(call: call, result: result)
        case "cancel":
            cancel(result: result)
        case "dispose":
            dispose(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPath = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "modelPath required", details: nil))
            return
        }

        let options = args["options"] as? [String: Any] ?? [:]

        do {
            // Check if model exists, if not copy from bundle
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: modelPath) {
                copyModelFromBundle(to: modelPath)
            }

            // Initialize whisper context
            whisperContext = try WhisperContext(modelPath: modelPath)
            result(true)
        } catch {
            result(FlutterError(code: "INITIALIZATION_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func transcribeFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let audioPath = args["audioPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "audioPath required", details: nil))
            return
        }

        guard let whisperContext = whisperContext else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize first", details: nil))
            return
        }

        do {
            let transcriptionResult = try whisperContext.transcribe(audioPath: audioPath)
            
            var segmentsArray: [[String: Any]] = []
            for segment in transcriptionResult.segments {
                var segmentDict: [String: Any] = [
                    "text": segment.text,
                    "start": segment.start,
                    "end": segment.end
                ]
                if let words = segment.words {
                    var wordsArray: [[String: Any]] = []
                    for word in words {
                        wordsArray.append([
                            "word": word.word,
                            "start": word.start,
                            "end": word.end,
                            "probability": word.probability
                        ])
                    }
                    segmentDict["words"] = wordsArray
                }
                segmentsArray.append(segmentDict)
            }

            let resultDict: [String: Any] = [
                "text": transcriptionResult.fullText,
                "segments": segmentsArray,
                "language": transcriptionResult.language,
                "duration": transcriptionResult.duration
            ]
            
            result(resultDict)
        } catch {
            result(FlutterError(code: "TRANSCRIPTION_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func transcribePcm(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement PCM transcription
        result(FlutterError(code: "NOT_IMPLEMENTED", message: "PCM transcription not yet implemented", details: nil))
    }

    private func cancel(result: @escaping FlutterResult) {
        // Cancel any ongoing transcription
        result(true)
    }

    private func dispose(result: @escaping FlutterResult) {
        whisperContext = nil
        result(true)
    }

    private func copyModelFromBundle(to destinationPath: String) {
        let fileManager = FileManager.default
        let bundle = Bundle.main
        
        guard let resourcePath = bundle.path(forResource: "models", ofType: nil) else { return }
        let sourcePath = resourcePath.appendingPathComponent(URL(fileURLWithPath: modelPath).lastPathComponent)
        
        if fileManager.fileExists(atPath: sourcePath) {
            try? fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
        }
    }
}

// FlutterStreamHandler for streaming results
extension FlutterWhisperPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
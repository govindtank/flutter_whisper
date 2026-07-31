import Foundation

/// iOS wrapper for whisper.cpp using Objective-C++
class WhisperContext {
    private var context: OpaquePointer?
    private var modelPath: String

    init(modelPath: String) throws {
        self.modelPath = modelPath
        
        // Load whisper library
        // Note: Actual implementation requires whisper.cpp compiled as static framework
        // This is a placeholder showing the API structure
        
        // In real implementation:
        // context = whisper_init_from_file(modelPath)
        // if context == nil { throw WhisperError.initFailed }
        
        // For now, we'll use a mock implementation
        self.context = nil
    }
    
    struct TranscriptionResult {
        let fullText: String
        let segments: [Segment]
        let language: String
        let duration: Double
        
        func toDictionary() -> [String: Any] {
            let segmentsArray = segments.map { segment in
                var dict: [String: Any] = [
                    "text": segment.text,
                    "start": segment.start,
                    "end": segment.end
                ]
                if let words = segment.words {
                    dict["words"] = words.map { word in
                        return [
                            "word": word.word,
                            "start": word.start,
                            "end": word.end,
                            "probability": word.probability
                        ]
                    }
                }
                return dict
            }
            
            return [
                "text": fullText,
                "segments": segmentsArray,
                "language": language,
                "duration": duration
            ]
        }
    }
    
    struct Segment {
        let text: String
        let start: Double
        let end: Double
        let words: [Word]?
    }
    
    struct Word {
        let word: String
        let start: Double
        let end: Double
        let probability: Double
    }
    
    enum WhisperError: Error {
        case initFailed
        case transcriptionFailed
        case invalidState
    }
    
    // In real implementation, these would call whisper.cpp C API
    func transcribe(audioPath: String) throws -> TranscriptionResult {
        // Mock implementation for compilation
        return TranscriptionResult(
            fullText: "Mock transcription from: \(audioPath)",
            segments: [
                Segment(text: "Mock transcription", start: 0.0, end: 5.0, words: nil)
            ],
            language: "en",
            duration: 5.0
        )
    }
    
    deinit {
        // whisper_free(context)
    }
}
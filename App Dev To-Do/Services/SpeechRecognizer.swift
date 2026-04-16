//
//  SpeechRecognizer.swift
//  App Dev To-Do
//
//  Handles voice-to-text conversion using Speech framework
//

import Foundation
import Combine
import Speech
import AVFoundation

enum SpeechRecognitionError: Error, LocalizedError {
    case notAuthorized
    case recognitionFailed(Error)
    case audioEngineFailed(Error)
    case noSpeechDetected
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in Settings."
        case .recognitionFailed(let error):
            return "Recognition failed: \(error.localizedDescription)"
        case .audioEngineFailed(let error):
            return "Audio engine failed: \(error.localizedDescription)"
        case .noSpeechDetected:
            return "No speech detected. Please try again."
        }
    }
}

/// Manages speech recognition for voice input
@MainActor
class SpeechRecognizer: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var error: SpeechRecognitionError?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Permissions
    
    /// Request necessary permissions for speech recognition
    static func requestAuthorization() async -> Bool {
        // Request speech recognition permission
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    /// Check if all required permissions are granted
    static func checkAuthorization() async -> Bool {
        let speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        let audioAuthorized = AVAudioApplication.shared.recordPermission == .granted
        return speechAuthorized && audioAuthorized
    }
    
    // MARK: - Recognition Control
    
    /// Start listening for speech input
    func startListening() async throws {
        // Reset any previous state
        stopListening()
        
        // Check permissions
        let isAuthorized = await SpeechRecognizer.checkAuthorization()
        guard isAuthorized else {
            error = .notAuthorized
            throw SpeechRecognitionError.notAuthorized
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechRecognitionError.audioEngineFailed(error)
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.recognitionFailed(NSError(domain: "Speech", code: -1))
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Start recognition task
        isListening = true
        transcribedText = ""
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                Task { @MainActor in
                    self.error = .recognitionFailed(error)
                    self.stopListening()
                }
                return
            }
            
            if let result = result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self.isListening = false
                    }
                }
            }
        }
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw SpeechRecognitionError.audioEngineFailed(error)
        }
    }
    
    /// Stop listening and return final transcription
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
    }
    
    /// Clear current transcription
    func clearTranscription() {
        transcribedText = ""
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognizer: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.stopListening()
            }
        }
    }
}

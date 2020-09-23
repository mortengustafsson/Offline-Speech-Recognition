//
//  OfflineSpeechRecognizer.swift
//  Offline Speech Recognition
//
//  Created by Morten Gustafsson on 23/09/2020.
//  Copyright © 2020 mortengustafsson. All rights reserved.
//

import Foundation
import UIKit
import Speech
import AVFoundation

public protocol OfflineSpeechRecognizerDelegate: class {
    func error(_ offlineSpeechRecognizer: OfflineSpeechRecognizer)
    func result(_ offlineSpeechRecognizer: OfflineSpeechRecognizer, message : String)
    func log(_ offlineSpeechRecognizer: OfflineSpeechRecognizer, message: String)
    func didStopListening(_ offlineSpeechRecognizer: OfflineSpeechRecognizer)
    func didStartListening(_ offlineSpeechRecognizer: OfflineSpeechRecognizer)
}

public class OfflineSpeechRecognizer {
    public static var shared: OfflineSpeechRecognizer = OfflineSpeechRecognizer()
    weak var delegate: OfflineSpeechRecognizerDelegate?
    public var isRecording: Bool { audioEngine.isRunning }

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    public func prepareListening(forLanguage language: String, andCountry country: String,  completion: @escaping ((PrepareResult) -> Void)) {
        // Check to see if the Microphone is available, if not bail out and send an error message to Unity.
        // Otherwise request SFSpeechRecognizer.requestAuthorization
        isMicrophoneAvailable(completion: { granted in
            if granted {
                SFSpeechRecognizer.requestAuthorization { (status) in
                    switch status {
                    case .authorized:
                        self.setupRecognition(forLanguage: language, andCountry: country, completion: completion)
                    case .denied:
                        completion(.error(ErrorType.speechRecognizerNotAvailable))
                    case .notDetermined, .restricted:
                        completion(.error(ErrorType.technicalError))
                    @unknown default:
                        completion(.error(ErrorType.technicalError))
                    }
                }
            } else {
                completion(.error(ErrorType.microphoneNotAvailable))
            }
        })
    }

    private func setupRecognition(forLanguage language: String, andCountry country: String, completion: @escaping (PrepareResult)-> Void) {

        let locale = Locale(identifier: language + "-" + country.uppercased())

        guard let speechRecognizer = SFSpeechRecognizer(locale: locale) else {
            log(messsage: "Couldn't create SFSpeechRecognizer")
            completion(.error(ErrorType.technicalError))
            return
        }

        log(messsage: "Locale set to: \(locale)" )
        log(messsage: "SpeechRecognizer Locale: \(speechRecognizer.locale)")

        // This is a Hack. But calling supportsOnDeviceRecognition has an unknown side effect and will make the code work.
        if speechRecognizer.supportsOnDeviceRecognition {}

        // Important! Keep data on Device. RequiresOnDeviceRecognition should be set to true otherwise the recognition data will be sent to Apple's servers.
        if #available(iOS 13, *) {
            // supportsOnDeviceRecognition can be false either if it's not
            // supported on the device or if the locale doesn't support on-device recognition.
            if speechRecognizer.supportsOnDeviceRecognition {
                self.speechRecognizer = speechRecognizer
                completion(.success)
            } else {
                // iPhone 7 will end here.
                log(messsage: "On device is not supported, for \(language)-\(country)")
                completion(.error(ErrorType.onDeviceIsNotAvailable))
            }
        } else {
            // If not iOS 13 then just bail out. supportsOnDeviceRecognition needs iOS 13,
            // and should according Apple be aviable on A9 or later processors (iPhone 6s and later, iPad 5th generation and later).
            // For more information see: https://developer.apple.com/videos/play/wwdc2019/256/ 1:05.
            completion(.error(ErrorType.onDeviceIsNotAvailable))
        }
    }

    private func isMicrophoneAvailable( completion: @escaping ((Bool) -> Void) ){
        switch AVAudioSession.sharedInstance().recordPermission {
        case AVAudioSessionRecordPermission.granted:
            completion(true)
        case AVAudioSessionRecordPermission.denied:
            completion(false)
        case AVAudioSessionRecordPermission.undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission( { granted in
                completion(granted)
            })
        @unknown default:
            completion(false)
        }
    }

   public func startListening() {
        startRecording()
    }

    public func stopListening() {
        resetListening()
    }

    private func startRecording() {
        //
        // If startRecording() is called before prepareListening() bail out.
        guard speechRecognizer != nil else {
            log(messsage: "SpeechRecongnizer is not been initalized: Please call prepareFor(locale) before call startRecording()")
            return
        }

        // Cancel the previous task if it's running.
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            delegate?.error(self)
            log(messsage: "recognitionRequest is not initialized.")
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // Keep speech recognition data on device. If not possible exit, with an error.
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        } else {
            delegate?.error(self)
            log(messsage: "On device is not supported on iOS less then iOS 13.")
        }

        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest ) { result, error in
            var isFinal = false

            if let result = result {
                isFinal = result.isFinal
                self.delegate?.result(self, message: result.bestTranscription.formattedString)
            }

            // Stop recognizing speech if there is a problem or isFinal is true.
            if error != nil || isFinal {
                self.resetListening()
                self.delegate?.didStopListening(self)
            }
        }

        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.multiRoute, mode: .default, options: .mixWithOthers)
            try audioSession.setActive(true, options:  .notifyOthersOnDeactivation)
        } catch {
            log(messsage: "Unexpected error: \(error)")
            delegate?.error(self)
        }

        // Configure the input.
        let format = audioEngine.inputNode.outputFormat(forBus: 0)

        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            delegate?.didStartListening(self)
        } catch {
            delegate?.error(self)
        }
    }

    private func log(messsage: String){
        delegate?.log(self, message: messsage)
    }

    private func resetListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
    }

}

public enum ErrorType: String {
    case microphoneNotAvailable = "MicrophoneNotAvailable"
    case onDeviceIsNotAvailable = "OnDeviceIsNotAvailable"
    case technicalError = "TechnicalError"
    case speechRecognizerNotAvailable = "SpeechRecognizerNotAvailable"
}

public enum PrepareResult {
    case success
    case error(ErrorType)
}

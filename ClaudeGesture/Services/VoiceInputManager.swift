import AVFoundation
import Foundation
import Combine

/// Manages voice input recording and transcription via Deepgram API
class VoiceInputManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var lastTranscription: String = ""
    @Published var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private let settings = AppSettings.shared

    /// Callback when transcription is complete
    var onTranscriptionComplete: ((String) -> Void)?

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        // On macOS, we don't need to configure AVAudioSession like on iOS
        // Just prepare the temporary file URL
        let tempDir = FileManager.default.temporaryDirectory
        audioFileURL = tempDir.appendingPathComponent("voice_recording.wav")
    }

    /// Check microphone permissions
    func checkPermissions() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            var granted = false
            let semaphore = DispatchSemaphore(value: 0)
            AVCaptureDevice.requestAccess(for: .audio) { result in
                granted = result
                semaphore.signal()
            }
            semaphore.wait()
            return granted
        case .denied, .restricted:
            errorMessage = "Microphone access denied. Please enable in System Settings."
            return false
        @unknown default:
            return false
        }
    }

    /// Start recording audio
    func startRecording() {
        guard !isRecording else { return }
        guard checkPermissions() else { return }

        guard let url = audioFileURL else {
            errorMessage = "Failed to create audio file"
            return
        }

        let recordingSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            print("Started recording...")
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    /// Stop recording and transcribe
    func stopRecording() {
        guard isRecording, let recorder = audioRecorder else { return }

        recorder.stop()
        isRecording = false
        print("Stopped recording, starting transcription...")

        transcribeAudio()
    }

    /// Toggle recording state
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    /// Transcribe the recorded audio using Deepgram API
    private func transcribeAudio() {
        guard let url = audioFileURL else {
            errorMessage = "No audio file to transcribe"
            return
        }

        guard !settings.deepgramApiKey.isEmpty else {
            errorMessage = "Deepgram API key not configured. Please add it in Settings."
            return
        }

        isTranscribing = true

        // Read audio file
        guard let audioData = try? Data(contentsOf: url) else {
            isTranscribing = false
            errorMessage = "Failed to read audio file"
            return
        }

        // Prepare Deepgram API request
        let apiURL = URL(string: "https://api.deepgram.com/v1/listen?model=nova-2&language=en")!
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Token \(settings.deepgramApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isTranscribing = false

                if let error = error {
                    self?.errorMessage = "Transcription failed: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "No response from Deepgram"
                    return
                }

                // Parse response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let results = json["results"] as? [String: Any],
                       let channels = results["channels"] as? [[String: Any]],
                       let firstChannel = channels.first,
                       let alternatives = firstChannel["alternatives"] as? [[String: Any]],
                       let firstAlternative = alternatives.first,
                       let transcript = firstAlternative["transcript"] as? String {

                        self?.lastTranscription = transcript
                        self?.onTranscriptionComplete?(transcript)
                        print("Transcription: \(transcript)")
                    } else {
                        // Check for error message
                        if let errorInfo = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errMsg = errorInfo["err_msg"] as? String {
                            self?.errorMessage = "Deepgram error: \(errMsg)"
                        } else {
                            self?.errorMessage = "Failed to parse transcription response"
                        }
                    }
                } catch {
                    self?.errorMessage = "Failed to parse response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

// MARK: - AVAudioRecorderDelegate
extension VoiceInputManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            errorMessage = "Recording failed"
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            errorMessage = "Recording error: \(error.localizedDescription)"
        }
    }
}

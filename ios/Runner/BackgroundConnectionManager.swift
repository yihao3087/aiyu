import AVFoundation

final class BackgroundConnectionManager {
    static let shared = BackgroundConnectionManager()

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let buffer: AVAudioPCMBuffer
    private var isRunning = false

    private init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCapacity = AVAudioFrameCount(format.sampleRate * 1)
        guard let tempBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            fatalError("Failed to create audio buffer for background keep-alive")
        }
        tempBuffer.frameLength = frameCapacity
        if let channelData = tempBuffer.floatChannelData?[0] {
            let samples = Int(tempBuffer.frameLength)
            for index in 0..<samples {
                channelData[index] = 0.0
            }
        }
        buffer = tempBuffer

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        audioEngine.mainMixerNode.outputVolume = 0.0
    }

    func start() {
        guard !isRunning else { return }
        guard hasAudioPermission() else {
            print("BackgroundConnectionManager skipped: microphone permission not granted")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers, .allowBluetooth])
            try session.setActive(true, options: [])
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            playerNode.play()
            isRunning = true
        } catch {
            print("BackgroundConnectionManager start error: \(error)")
            stop()
        }
    }

    func stop() {
        guard isRunning else { return }
        playerNode.stop()
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        isRunning = false
    }

    private func hasAudioPermission() -> Bool {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            return true
        case .undetermined:
            session.requestRecordPermission { _ in }
            return false
        case .denied:
            fallthrough
        @unknown default:
            return false
        }
    }
}

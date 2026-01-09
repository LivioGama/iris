import Foundation
import Combine

@MainActor
class IRISCoordinator: ObservableObject {
    let cameraService = CameraService()
    let gazeEstimator = GazeEstimator()
    let audioService = AudioService()
    let speechService = SpeechService()
    let screenCaptureService = ScreenCaptureService()
    let intentTrigger = IntentTrigger()
    let intentResolver = IntentResolver()
    
    @Published var isActive = false
    @Published var currentState: IntentTrigger.State = .idle
    @Published var lastIntent: ResolvedIntent?
    @Published var debugLog: [String] = []
    
    @Published var gazePoint: CGPoint = CGPoint(x: 960, y: 540)
    @Published var gazeDebugInfo: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        gazeEstimator.$gazePoint
            .receive(on: RunLoop.main)
            .sink { [weak self] point in
                self?.gazePoint = point
                self?.intentTrigger.updateGaze(point)
            }
            .store(in: &cancellables)
        
        gazeEstimator.$debugInfo
            .receive(on: RunLoop.main)
            .sink { [weak self] info in
                self?.gazeDebugInfo = info
            }
            .store(in: &cancellables)
        
        audioService.onVoiceStart = { [weak self] in
            Task { @MainActor in
                self?.intentTrigger.voiceStarted()
                try? self?.speechService.startRecognition()
                self?.log("Voice started - listening...")
            }
        }
        
        audioService.onVoiceEnd = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                let transcript = self.speechService.transcript
                self.speechService.stopRecognition()
                self.intentTrigger.voiceEnded(transcript: transcript)
                self.log("Voice ended: \(transcript)")
            }
        }
        
        audioService.onAudioBuffer = { [weak self] buffer in
            self?.speechService.appendBuffer(buffer)
        }
        
        intentTrigger.onTrigger = { [weak self] gazePoint, transcript in
            Task { @MainActor in
                await self?.processIntent(gazePoint: gazePoint, transcript: transcript)
            }
        }
        
        intentTrigger.$state
            .assign(to: &$currentState)
    }
    
    func start() async {
        do {
            try await audioService.start()
            gazeEstimator.start()
            isActive = true
            log("I.R.I.S activated - EyeGestures Python")
        } catch {
            log("Failed to start: \(error)")
        }
    }
    
    func stop() {
        gazeEstimator.stop()
        audioService.stop()
        isActive = false
        log("I.R.I.S deactivated")
    }
    
    private func processIntent(gazePoint: CGPoint, transcript: String) async {
        log("Processing intent at \(gazePoint)")
        
        do {
            let fullScreen = try await screenCaptureService.captureFullScreen()
            let cropped = try await screenCaptureService.captureCroppedRegion(around: gazePoint)
            
            guard let fullBase64 = screenCaptureService.imageToBase64(fullScreen),
                  let croppedBase64 = screenCaptureService.imageToBase64(cropped) else {
                log("Failed to encode images")
                intentTrigger.reset()
                return
            }
            
            let intent = try await intentResolver.resolve(
                fullScreenImage: fullBase64,
                croppedImage: croppedBase64,
                transcript: transcript,
                gazePoint: gazePoint
            )
            
            lastIntent = intent
            intentTrigger.resolved()
            log("Resolved: \(intent.action) on \(intent.target) (\(Int(intent.confidence * 100))%)")
            
        } catch {
            log("Resolution failed: \(error)")
            intentTrigger.reset()
        }
    }
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugLog.append("[\(timestamp)] \(message)")
        if debugLog.count > 50 {
            debugLog.removeFirst()
        }
    }
}

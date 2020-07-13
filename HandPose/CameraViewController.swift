/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 The app's main view controller object.
 */

import UIKit
import AVFoundation
import Vision

class CameraViewController: RecorderViewController {
    var recordButton: UIButton = {
        var button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("record", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 25)
        button.titleLabel?.textColor = .systemYellow
        return button
    }()
    private let label = UILabel(frame: CGRect(x: 100, y: 100, width: 100, height: 100))
    
    private var cameraView: CameraView { view as! CameraView }
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    private var gestureProcessor = ApprovalGestureProcessor()
    
    private let drawOverlay = CAShapeLayer()
    private let drawPath = UIBezierPath()
    private var evidenceBuffer = [Fingers]()
    private var lastDrawPoint: CGPoint?
    private var isFirstSegment = true
    private var lastObservationTimestamp = Date()
    var startedRecording = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        drawOverlay.frame = view.layer.bounds
        view.layer.addSublayer(drawOverlay)
        handPoseRequest.maximumHandCount = 1
        gestureProcessor.didChangeStateClosure = { [weak self] state in
            self?.handleGestureStateChange(state: state)
        }
        label.font = UIFont.boldSystemFont(ofSize: 50.0)
        view.addSubview(label)
        
        recorder.videoListeners.append { (url) in
            let result = self.getNumberOfFrames(url: url) // Or send this to an SDK and do something with the result
            
            let alert = UIAlertController(title: "Frames", message: "The video counted \(result) frames", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: nil))
            self.present(alert, animated: true)
            
            FileManager.default.clearTmpDirectory() // You shouldn't to keep the video in /tmp for security reasons
        }
        
        recorder.sampleBufferListeners.append { (output, sampleBuffer, connection) in
            if output is AVCaptureVideoDataOutput {
                self.updateHandTracking(output, didOutput: sampleBuffer, from: connection)
            }
        }
        
        view.addSubview(recordButton)
        recordButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20).isActive = true
        recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        recordButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1 / 3).isActive = true
        recordButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        recordButton.addTarget(self, action: #selector(recordButtonAction), for: .touchUpInside)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cameraView.previewLayer.videoGravity = .resizeAspectFill
        cameraView.previewLayer.session = recorder.captureSession
    }
    
    func toggleRecording() {
        guard !startedRecording else { return }
        startedRecording = true
        recordButtonAction()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [self] in
            self.startedRecording = false
            self.recordButtonAction()
        }
    }
    
    func processPoints(fingers: PossibleFingers) {
        // Check that we have both points.
        guard let thumbTip = fingers.thumb.TIP,
              let thumbIp = fingers.thumb.IP,
              let thumbMp = fingers.thumb.MP,
              let thumbCmc = fingers.thumb.CMC,
              let indexTip = fingers.index.TIP,
              let indexDip = fingers.index.DIP,
              let indexPip = fingers.index.PIP,
              let indexMcp = fingers.index.MCP,
              let middleTip = fingers.middle.TIP,
              let middleDip = fingers.middle.DIP,
              let middlePip = fingers.middle.PIP,
              let middleMcp = fingers.middle.MCP,
              let ringTip = fingers.ring.TIP,
              let ringDip = fingers.ring.DIP,
              let ringPip = fingers.ring.PIP,
              let ringMcp = fingers.ring.MCP,
              let littleTip = fingers.little.TIP,
              let littleDip = fingers.little.DIP,
              let littlePip = fingers.little.PIP,
              let littleMcp = fingers.little.MCP,
              let wrist = fingers.wrist else {
            // If there were no observations for more than 2 seconds reset gesture processor.
            if Date().timeIntervalSince(lastObservationTimestamp) > 2 {
                gestureProcessor.reset()
            }
            cameraView.showPoints([], color: .clear)
            return
        }
        
        // Convert points from AVFoundation coordinates to UIKit coordinates.
        let previewLayer = cameraView.previewLayer
        let thumbTipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbTip)
        let thumbIpConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbIp)
        let thumbMpConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbMp)
        let thumbCmcConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbCmc)
        
        let indexTipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexTip)
        let indexDipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexDip)
        let indexPipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexPip)
        let indexMcpConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexMcp)
        
        let middleTipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: middleTip)
        let middleDipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: middleDip)
        let middlePipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: middlePip)
        let middleMcpConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: middleMcp)
        
        let ringTipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: ringTip)
        let ringDipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: ringDip)
        let ringPipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: ringPip)
        let ringMcpConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: ringMcp)
        
        let littleTipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: littleTip)
        let littleDipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: littleDip)
        let littlePipConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: littlePip)
        let littleMcpConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: littleMcp)
        
        let wristConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: wrist)
        
        // Process new points
        let fingers = Fingers(thumb: Thumb(TIP: thumbTipConverted, IP: thumbIpConverted, MP: thumbMpConverted, CMC: thumbCmcConverted),
                              index: Finger(TIP: indexTipConverted, DIP: indexDipConverted, PIP: indexPipConverted, MCP: indexMcpConverted),
                              middle: Finger(TIP: middleTipConverted, DIP: middleDipConverted, PIP: middlePipConverted, MCP: middleMcpConverted),
                              ring: Finger(TIP: ringTipConverted, DIP: ringDipConverted, PIP: ringPipConverted, MCP: ringMcpConverted),
                              little: Finger(TIP: littleTipConverted, DIP: littleDipConverted, PIP: littlePipConverted, MCP: littleMcpConverted),
                              wrist: wristConverted)
        
        gestureProcessor.processFingerPoints(fingers)
    }
    
    private func handleGestureStateChange(state: ApprovalGestureProcessor.State) {
        let pointsFingers = gestureProcessor.lastProcessedPointsFingers
        var tipsColor: UIColor
        switch state {
        case .possibleThumbsUp, .possibleThumbsDown:
            tipsColor = .orange
            label.text = ""
        case .thumbsUp:
            tipsColor = .green
            label.text = "👍"
            toggleRecording()
        case .thumbsDown, .unknown:
            tipsColor = .red
            label.text = "👎"
        }
        cameraView.showPoints([pointsFingers.thumb.TIP, pointsFingers.thumb.IP, pointsFingers.thumb.MP, pointsFingers.thumb.CMC,
                               pointsFingers.index.TIP, pointsFingers.index.DIP, pointsFingers.index.PIP, pointsFingers.index.MCP,
                               pointsFingers.middle.TIP, pointsFingers.middle.DIP, pointsFingers.middle.PIP, pointsFingers.middle.MCP,
                               pointsFingers.ring.TIP, pointsFingers.ring.DIP, pointsFingers.ring.PIP, pointsFingers.ring.MCP,
                               pointsFingers.little.TIP, pointsFingers.little.DIP, pointsFingers.little.PIP, pointsFingers.little.MCP,
                               pointsFingers.wrist], color: tipsColor)
    }
    
    public func updateHandTracking(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var thumbTip: CGPoint?
        var thumbIp: CGPoint?
        var thumbMp: CGPoint?
        var thumbCmc: CGPoint?
        
        var indexTip: CGPoint?
        var indexDip: CGPoint?
        var indexPip: CGPoint?
        var indexMcp: CGPoint?
        
        var middleTip: CGPoint?
        var middleDip: CGPoint?
        var middlePip: CGPoint?
        var middleMcp: CGPoint?
        
        var ringTip: CGPoint?
        var ringDip: CGPoint?
        var ringPip: CGPoint?
        var ringMcp: CGPoint?
        
        var littleTip: CGPoint?
        var littleDip: CGPoint?
        var littlePip: CGPoint?
        var littleMcp: CGPoint?
        
        var wrist: CGPoint?
        
        defer {
            DispatchQueue.main.sync {
                self.processPoints(fingers: PossibleFingers(thumb: PossibleThumb(TIP: thumbTip, IP: thumbIp, MP: thumbMp, CMC: thumbCmc),
                                                            index: PossibleFinger(TIP: indexTip, DIP: indexDip, PIP: indexPip, MCP: indexMcp),
                                                            middle: PossibleFinger(TIP: middleTip, DIP: middleDip, PIP: middlePip, MCP: middleMcp),
                                                            ring: PossibleFinger(TIP: ringTip, DIP: ringDip, PIP: ringPip, MCP: ringMcp),
                                                            little: PossibleFinger(TIP: littleTip, DIP: littleDip, PIP: littlePip, MCP: littleMcp),
                                                            wrist: wrist))
            }
        }
        
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])
            // Continue only when a hand was detected in the frame.
            // Since we set the maximumHandCount property of the request to 1, there will be at most one observation.
            guard let observation = handPoseRequest.results?.first as? VNRecognizedPointsObservation else {
                return
            }
            // Get points for thumb and index finger.
            let thumbPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyThumb)
            let indexFingerPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyIndexFinger)
            let middleFingerPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyMiddleFinger)
            let ringFingerPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyRingFinger)
            let littleFingerPoints = try observation.recognizedPoints(forGroupKey: .handLandmarkRegionKeyLittleFinger)
            let wristPoints = try observation.recognizedPoints(forGroupKey: .all)
            
            // Look for tip points.
            guard let thumbTipPoint = thumbPoints[.handLandmarkKeyThumbTIP],
                  let thumbIpPoint = thumbPoints[.handLandmarkKeyThumbIP],
                  let thumbMpPoint = thumbPoints[.handLandmarkKeyThumbMP],
                  let thumbCMCPoint = thumbPoints[.handLandmarkKeyThumbCMC] else {
                return
            }
            
            guard let indexTipPoint = indexFingerPoints[.handLandmarkKeyIndexTIP],
                  let indexDipPoint = indexFingerPoints[.handLandmarkKeyIndexDIP],
                  let indexPipPoint = indexFingerPoints[.handLandmarkKeyIndexPIP],
                  let indexMcpPoint = indexFingerPoints[.handLandmarkKeyIndexMCP] else {
                return
            }
            
            guard let middleTipPoint = middleFingerPoints[.handLandmarkKeyMiddleTIP],
                  let middleDipPoint = middleFingerPoints[.handLandmarkKeyMiddleDIP],
                  let middlePipPoint = middleFingerPoints[.handLandmarkKeyMiddlePIP],
                  let middleMcpPoint = middleFingerPoints[.handLandmarkKeyMiddleMCP] else {
                return
            }
            
            guard let ringTipPoint = ringFingerPoints[.handLandmarkKeyRingTIP],
                  let ringDipPoint = ringFingerPoints[.handLandmarkKeyRingDIP],
                  let ringPipPoint = ringFingerPoints[.handLandmarkKeyRingPIP],
                  let ringMcpPoint = ringFingerPoints[.handLandmarkKeyRingMCP] else {
                return
            }
            
            guard let littleTipPoint = littleFingerPoints[.handLandmarkKeyLittleTIP],
                  let littleDipPoint = littleFingerPoints[.handLandmarkKeyLittleDIP],
                  let littlePipPoint = littleFingerPoints[.handLandmarkKeyLittlePIP],
                  let littleMcpPoint = littleFingerPoints[.handLandmarkKeyLittleMCP] else {
                return
            }
            
            guard let wristPoint = wristPoints[.handLandmarkKeyWrist] else {
                return
            }
            
            let minimumConfidence: Float = 0.3
            // Ignore low confidence points.
            guard thumbTipPoint.confidence > minimumConfidence,
                  thumbIpPoint.confidence > minimumConfidence,
                  thumbMpPoint.confidence > minimumConfidence,
                  thumbCMCPoint.confidence > minimumConfidence else {
                return
            }
            
            guard indexTipPoint.confidence > minimumConfidence,
                  indexDipPoint.confidence > minimumConfidence,
                  indexPipPoint.confidence > minimumConfidence,
                  indexMcpPoint.confidence > minimumConfidence else {
                return
            }
            
            guard middleTipPoint.confidence > minimumConfidence,
                  middleDipPoint.confidence > minimumConfidence,
                  middlePipPoint.confidence > minimumConfidence,
                  middleMcpPoint.confidence > minimumConfidence else {
                return
            }
            
            guard ringTipPoint.confidence > minimumConfidence,
                  ringDipPoint.confidence > minimumConfidence,
                  ringPipPoint.confidence > minimumConfidence,
                  ringMcpPoint.confidence > minimumConfidence else {
                return
            }
            
            guard littleTipPoint.confidence > minimumConfidence,
                  littleDipPoint.confidence > minimumConfidence,
                  littlePipPoint.confidence > minimumConfidence,
                  littleMcpPoint.confidence > minimumConfidence else {
                return
            }
            
            guard wristPoint.confidence > minimumConfidence else {
                return
            }
            
            // Convert points from Vision coordinates to AVFoundation coordinates.
            thumbTip = CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y)
            thumbIp = CGPoint(x: thumbIpPoint.location.x, y: 1 - thumbIpPoint.location.y)
            thumbMp = CGPoint(x: thumbMpPoint.location.x, y: 1 - thumbMpPoint.location.y)
            thumbCmc = CGPoint(x: thumbCMCPoint.location.x, y: 1 - thumbCMCPoint.location.y)
            
            indexTip = CGPoint(x: indexTipPoint.location.x, y: 1 - indexTipPoint.location.y)
            indexDip = CGPoint(x: indexDipPoint.location.x, y: 1 - indexDipPoint.location.y)
            indexPip = CGPoint(x: indexPipPoint.location.x, y: 1 - indexPipPoint.location.y)
            indexMcp = CGPoint(x: indexMcpPoint.location.x, y: 1 - indexMcpPoint.location.y)
            
            middleTip = CGPoint(x: middleTipPoint.location.x, y: 1 - middleTipPoint.location.y)
            middleDip = CGPoint(x: middleDipPoint.location.x, y: 1 - middleDipPoint.location.y)
            middlePip = CGPoint(x: middlePipPoint.location.x, y: 1 - middlePipPoint.location.y)
            middleMcp = CGPoint(x: middleMcpPoint.location.x, y: 1 - middleMcpPoint.location.y)
            
            ringTip = CGPoint(x: ringTipPoint.location.x, y: 1 - ringTipPoint.location.y)
            ringDip = CGPoint(x: ringDipPoint.location.x, y: 1 - ringDipPoint.location.y)
            ringPip = CGPoint(x: ringPipPoint.location.x, y: 1 - ringPipPoint.location.y)
            ringMcp = CGPoint(x: ringMcpPoint.location.x, y: 1 - ringMcpPoint.location.y)
            
            littleTip = CGPoint(x: littleTipPoint.location.x, y: 1 - littleTipPoint.location.y)
            littleDip = CGPoint(x: littleDipPoint.location.x, y: 1 - littleDipPoint.location.y)
            littlePip = CGPoint(x: littlePipPoint.location.x, y: 1 - littlePipPoint.location.y)
            littleMcp = CGPoint(x: littleMcpPoint.location.x, y: 1 - littleMcpPoint.location.y)
            
            wrist = CGPoint(x: wristPoint.location.x, y: 1 - wristPoint.location.y)
        } catch {
            let error = AppError.visionError(error: error)
            DispatchQueue.main.async {
                error.displayInViewController(self)
            }
        }
    }
}

extension CameraViewController {
    @objc
    func recordButtonAction() {
        print(#function)
        if recorder.isRecording {
            recorder.stopRecording()
        } else {
            recorder.startRecording()
        }
        recordButton.setTitle(recorder.isRecording ? "Recording" : "Start", for: .normal)
    }
    
    func getNumberOfFrames(url: URL) -> Int {
        let asset = AVURLAsset(url: url, options: nil)
        do {
            let reader = try AVAssetReader(asset: asset)
            //AVAssetReader(asset: asset, error: nil)
            let videoTrack = asset.tracks(withMediaType: AVMediaType.video)[0]
            
            let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil) // NB: nil, should give you raw frames
            reader.add(readerOutput)
            reader.startReading()
            
            var nFrames = 0
            
            while true {
                let sampleBuffer = readerOutput.copyNextSampleBuffer()
                if sampleBuffer == nil {
                    break
                }
                
                nFrames = nFrames+1
            }
            
            print("Num frames: \(nFrames)")
            return nFrames
        }catch {
            print("Error: \(error)")
        }
        return 0
    }
}

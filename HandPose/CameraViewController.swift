/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 The app's main view controller object.
 */

import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController {
    
    private var cameraView: CameraView { view as! CameraView }
    
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    private var cameraFeedSession: AVCaptureSession?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    private let drawOverlay = CAShapeLayer()
    private let drawPath = UIBezierPath()
    private var evidenceBuffer = [ApprovalGestureProcessor.PointsFingers]()
    private var lastDrawPoint: CGPoint?
    private var isFirstSegment = true
    private var lastObservationTimestamp = Date()
    
    private let label = UILabel(frame: CGRect(x: 100, y: 100, width: 100, height: 100))
    
    private var gestureProcessor = ApprovalGestureProcessor()
    
    struct PossibleThumb {
        let TIP: CGPoint?
        let IP: CGPoint?
        let MP: CGPoint?
        let CMC: CGPoint?
    }
    
    struct PossibleFinger {
        let TIP: CGPoint?
        let DIP: CGPoint?
        let PIP: CGPoint?
        let MCP: CGPoint?
    }
    
    typealias PossibleFingers = (thumb: PossibleThumb, index: PossibleFinger, middle: PossibleFinger, ring: PossibleFinger, little: PossibleFinger, wrist: CGPoint?)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        drawOverlay.frame = view.layer.bounds
        drawOverlay.lineWidth = 5
        drawOverlay.backgroundColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0).cgColor
        drawOverlay.strokeColor = #colorLiteral(red: 0.6, green: 0.1, blue: 0.3, alpha: 1).cgColor
        drawOverlay.fillColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0).cgColor
        drawOverlay.lineCap = .round
        view.layer.addSublayer(drawOverlay)
        // This sample app detects one hand only.
        handPoseRequest.maximumHandCount = 1
        // Add state change handler to hand gesture processor.
        gestureProcessor.didChangeStateClosure = { [weak self] state in
            self?.handleGestureStateChange(state: state)
        }
        // Add double tap gesture recognizer for clearing the draw path.
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        recognizer.numberOfTouchesRequired = 1
        recognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(recognizer)
        label.font = UIFont.boldSystemFont(ofSize: 50.0)
        view.addSubview(label)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            if cameraFeedSession == nil {
                cameraView.previewLayer.videoGravity = .resizeAspectFill
                try setupAVSession()
                cameraView.previewLayer.session = cameraFeedSession
            }
            cameraFeedSession?.startRunning()
        } catch {
            AppError.display(error, inViewController: self)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        cameraFeedSession?.stopRunning()
        super.viewWillDisappear(animated)
    }
    
    func setupAVSession() throws {
        // Select a front facing camera, make an input.
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw AppError.captureSessionSetup(reason: "Could not find a front facing camera.")
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw AppError.captureSessionSetup(reason: "Could not create video device input.")
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.high
        
        // Add a video input.
        guard session.canAddInput(deviceInput) else {
            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            // Add a video data output.
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
        }
        session.commitConfiguration()
        cameraFeedSession = session
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
        gestureProcessor.processPointsFingers(
            ApprovalGestureProcessor.PointsFingers(thumb: Thumb(TIP: thumbTipConverted, IP: thumbIpConverted, MP: thumbMpConverted, CMC: thumbCmcConverted),
                                                   index: Finger(TIP: indexTipConverted, DIP: indexDipConverted, PIP: indexPipConverted, MCP: indexMcpConverted),
                                                   middle: Finger(TIP: middleTipConverted, DIP: middleDipConverted, PIP: middlePipConverted, MCP: middleMcpConverted),
                                                   ring: Finger(TIP: ringTipConverted, DIP: ringDipConverted, PIP: ringPipConverted, MCP: ringMcpConverted),
                                                   little: Finger(TIP: littleTipConverted, DIP: littleDipConverted, PIP: littlePipConverted, MCP: littleMcpConverted),
                                                   wrist: wristConverted))
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
    
    @IBAction func handleGesture(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }
        evidenceBuffer.removeAll()
        drawPath.removeAllPoints()
        drawOverlay.path = drawPath.cgPath
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
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
            cameraFeedSession?.stopRunning()
            let error = AppError.visionError(error: error)
            DispatchQueue.main.async {
                error.displayInViewController(self)
            }
        }
    }
}


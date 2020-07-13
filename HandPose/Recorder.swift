//
//  Recorder.swift
//  HandPose
//
//  Created by Yannis De Cleene on 04/07/2020.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit
import AVFoundation

open class Recorder: NSObject {
    public typealias VideoListener = (URL) -> ()
    public typealias SampleBufferListener = (AVCaptureOutput, CMSampleBuffer, AVCaptureConnection) -> ()
    public typealias MetadataListener = (AVCaptureMetadataOutput, [AVMetadataObject], AVCaptureConnection) -> ()
    
    public var videoListeners: [VideoListener] = [VideoListener]()
    public var sampleBufferListeners: [SampleBufferListener] = [SampleBufferListener]()
    public var metadataListeners: [MetadataListener] = [MetadataListener]()
    
    public private(set) var isRecording: Bool = false
    public var captureSession: AVCaptureSession = AVCaptureSession()
    
    private var assetWriter: AVAssetWriter? = nil
    private var audioInput: AVAssetWriterInput? = nil
    private var videoInput: AVAssetWriterInput? = nil
    
    private var startTime: CMTime = CMTime.invalid
    private var duration: CMTime = CMTime.zero
    
    private var lastVideoSampleBuffer: CMSampleBuffer? = nil
    
    public var isFacingFront: Bool = true {
        didSet {
            self.setupInputs()
        }
    }
    
    public override init() {
        super.init()
        openCamera()
    }
    
    private func openCamera() {
        let videoAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if videoAuthStatus == .authorized && audioAuthStatus == .authorized {
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [
                //String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_32BGRA)
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = false
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            } else {
                print("can't add video output")
            }
            
            let audioOutput = AVCaptureAudioDataOutput()
            audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov)
            if captureSession.canAddOutput(audioOutput) {
                captureSession.addOutput(audioOutput)
            } else {
                print("can't add audio output")
            }
            
            setupInputs()
            
            let queue = DispatchQueue(label: "recorder.queue")
            videoOutput.setSampleBufferDelegate(self, queue: queue)
            audioOutput.setSampleBufferDelegate(self, queue: queue)
            
            let metadataOutput = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.metadataObjectTypes = metadataOutput.availableMetadataObjectTypes
            }
            else {
                print("can't add metadata output")
            }
            metadataOutput.setMetadataObjectsDelegate(self, queue: queue)
            
            captureSession.startRunning()
        } else if videoAuthStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                if granted {
                    DispatchQueue.main.async {
                        self.openCamera()
                    }
                }
            }
        } else if videoAuthStatus == .authorized && audioAuthStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio, completionHandler: { (granted) in
                if granted {
                    DispatchQueue.main.async {
                        self.openCamera()
                    }
                }
            })
        }
    }
    
    private func setupInputs() {
        print(#function)
        let captureDeviceVideoFront = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: isFacingFront ? .front : .back).devices.first
        let captureDeviceAudio = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified).devices.first
        captureSession.beginConfiguration()
        if captureSession.inputs.contains(where: { (input) -> Bool in
            (input as! AVCaptureDeviceInput).device.hasMediaType(.video)
        }) {
            captureSession.removeInput(captureSession.inputs.first { input in
                (input as! AVCaptureDeviceInput).device.hasMediaType(.video)
                }!)
        }
        if captureSession.inputs.contains(where: { (input) -> Bool in
            (input as! AVCaptureDeviceInput).device.hasMediaType(.audio)
        }) {
            captureSession.removeInput(captureSession.inputs.first { input in
                (input as! AVCaptureDeviceInput).device.hasMediaType(.audio)
                }!)
        }
        let frontCaptureDeviceInput = try! AVCaptureDeviceInput(device: captureDeviceVideoFront!)
        
        let audioCaptureDeviceInput = try! AVCaptureDeviceInput(device: captureDeviceAudio!)
        captureSession.addInput(frontCaptureDeviceInput)
        
        var suitableFormat: AVCaptureDevice.Format?
        for format in captureDeviceVideoFront!.formats {
            //0.5625 - 16:9, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange(420f) - "875704422"
            let mediaSubtypeType = CMFormatDescriptionGetMediaSubType(format.formatDescription)
            if (Float(format.highResolutionStillImageDimensions.height) / Float(format.highResolutionStillImageDimensions.width) == 9.0 / 16.0 && mediaSubtypeType.description == "875704422") {
                suitableFormat = format
                print(suitableFormat!)
                break
            }
        }
        
        do {
            try captureDeviceVideoFront?.lockForConfiguration()
            captureDeviceVideoFront?.activeFormat = suitableFormat!
            captureDeviceVideoFront?.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 25)
            captureDeviceVideoFront?.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 25)
            captureDeviceVideoFront?.unlockForConfiguration()
        } catch {
            print(error)
        }
        
        captureSession.addInput(audioCaptureDeviceInput)
        
        captureSession.outputs.forEach { (output) in
            output.connections.forEach { (connection) in
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
                }
//                if connection.isVideoOrientationSupported {
//                    connection.videoOrientation = AVCaptureVideoOrientation.portrait
//                }
//                if connection.isVideoMirroringSupported {
//                    connection.isVideoMirrored = isFacingFront
//                }
            }
        }
        
        captureSession.commitConfiguration()
    }
    
    public func startRecording() {
        print(#function)
        if !isRecording {
            let outputURL = URL(fileURLWithPath: NSTemporaryDirectory().appending(UUID().uuidString).appending(".mp4"))
            do {
                assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            } catch {
                print(error)
            }
            assetWriter!.shouldOptimizeForNetworkUse = true
            let videoSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoHeightKey: 800, AVVideoWidthKey: 450]
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput!.expectsMediaDataInRealTime = true
            if assetWriter!.canAdd(videoInput!) {
                assetWriter!.add(videoInput!)
            } else {
                videoInput = nil
                print("recorder, could not add video input to session")
            }
            let audioSettings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100.0, AVNumberOfChannelsKey: 1]
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput!.expectsMediaDataInRealTime = true
            if assetWriter!.canAdd(audioInput!) {
                assetWriter!.add(audioInput!)
            } else {
                audioInput = nil
                print("recorder, could not add audio input to session")
            }
            isRecording = assetWriter!.startWriting()
        }
    }
    
    public func stopRecording() {
        print(#function)
        if isRecording {
            if startTime.isValid {
                isRecording = false
                videoInput?.markAsFinished()
                audioInput?.markAsFinished()
                assetWriter!.endSession(atSourceTime: duration + startTime)
                startTime = CMTime.invalid
                duration = CMTime.zero
                assetWriter!.finishWriting {
                    DispatchQueue.main.async {
                        for listener in self.videoListeners {
                            listener(self.assetWriter!.outputURL)
                        }
                    }
                }
            }
            else {
                //if the recording has started, but startSession has not yet been called, repeat this method with a slight pause
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.stopRecording()
                }
            }
        }
    }
    
    public func takePhoto() -> UIImage? {
        if lastVideoSampleBuffer != nil {
            let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(lastVideoSampleBuffer!)!
            
            let ciimage : CIImage = CIImage(cvPixelBuffer: imageBuffer)
            
            let image : UIImage = self.convert(cmage: ciimage)
            return image
        }
        
        return nil
    }
    
    // Convert CIImage to CGImage
    func convert(cmage:CIImage) -> UIImage
    {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
    
    deinit {
        print(#function)
    }
}

extension Recorder: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate {
    open func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        for listener in sampleBufferListeners {
            listener(output, sampleBuffer, connection)
        }
        if output is AVCaptureVideoDataOutput {
            lastVideoSampleBuffer = sampleBuffer
        }
        if self.isRecording {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if !startTime.isValid && output is AVCaptureVideoDataOutput {
                startTime = timestamp
                assetWriter!.startSession(atSourceTime: startTime)
            }
            if startTime.isValid {
                if output is AVCaptureVideoDataOutput {
                    if videoInput != nil && videoInput!.isReadyForMoreMediaData {
                        videoInput!.append(sampleBuffer)
                        duration = timestamp - startTime
                    }
                }
                else if output is AVCaptureAudioDataOutput {
                    if audioInput != nil && audioInput!.isReadyForMoreMediaData {
                        audioInput!.append(sampleBuffer)
                    }
                }
            }
        }
    }
    
    open func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for listener in metadataListeners {
            listener(output, metadataObjects, connection)
        }
    }
}


/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The camera view shows the feed from the camera, and renders the points
     returned from VNDetectHumanHandpose observations.
*/

import UIKit
import AVFoundation

class CameraView: UIView {

    private var overlayLayer = CAShapeLayer()
    private var pointsPath = UIBezierPath()

    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        if layer == previewLayer {
            overlayLayer.frame = layer.bounds
        }
    }

    private func setupOverlay() {
        previewLayer.addSublayer(overlayLayer)
    }
    
    func showPoints(_ points: [CGPoint], color: UIColor) {
        pointsPath.removeAllPoints()
        for point in points {
            pointsPath.move(to: point)
            pointsPath.addArc(withCenter: point, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        }
        
        if points.count > 1 {
            // Draw thumb bones
            pointsPath.move(to: points[0])
            pointsPath.addLine(to: points[1])
            pointsPath.move(to: points[1])
            pointsPath.addLine(to: points[2])
            pointsPath.move(to: points[2])
            pointsPath.addLine(to: points[3])
            pointsPath.move(to: points[3])
            pointsPath.addLine(to: points.last!)
            
            // Draw indexFinger bones
            pointsPath.move(to: points[4])
            pointsPath.addLine(to: points[5])
            pointsPath.move(to: points[5])
            pointsPath.addLine(to: points[6])
            pointsPath.move(to: points[6])
            pointsPath.addLine(to: points[7])
            pointsPath.move(to: points[7])
            pointsPath.addLine(to: points.last!)
            
            // Draw middleFinger bones
            pointsPath.move(to: points[8])
            pointsPath.addLine(to: points[9])
            pointsPath.move(to: points[9])
            pointsPath.addLine(to: points[10])
            pointsPath.move(to: points[10])
            pointsPath.addLine(to: points[11])
            pointsPath.move(to: points[11])
            pointsPath.addLine(to: points.last!)
            
            // Draw ringFinger bones
            pointsPath.move(to: points[12])
            pointsPath.addLine(to: points[13])
            pointsPath.move(to: points[13])
            pointsPath.addLine(to: points[14])
            pointsPath.move(to: points[14])
            pointsPath.addLine(to: points[15])
            pointsPath.move(to: points[15])
            pointsPath.addLine(to: points.last!)
            
            // Draw littleFinger bones
            pointsPath.move(to: points[16])
            pointsPath.addLine(to: points[17])
            pointsPath.move(to: points[17])
            pointsPath.addLine(to: points[18])
            pointsPath.move(to: points[18])
            pointsPath.addLine(to: points[19])
            pointsPath.move(to: points[19])
            pointsPath.addLine(to: points.last!)
        }
        
        overlayLayer.fillColor = color.cgColor
        overlayLayer.strokeColor = color.cgColor
        overlayLayer.lineWidth = 5.0
        overlayLayer.lineCap = .round
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        overlayLayer.path = pointsPath.cgPath
        CATransaction.commit()
    }
}

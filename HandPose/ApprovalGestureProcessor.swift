//
//  ApprovalGestureProcessor.swift
//  HandPose
//
//  Created by Yannis De Cleene on 29/06/2020.
//  Copyright © 2020 Apple. All rights reserved.
//

import CoreGraphics

class ApprovalGestureProcessor {
    enum State {
        case possibleThumbsUp
        case thumbsUp
        case possibleThumbsDown
        case thumbsDown
        case unknown
    }
    
    private var state = State.unknown {
        didSet {
            didChangeStateClosure?(state)
        }
    }
    private var pinchEvidenceCounter = 0
    private var apartEvidenceCounter = 0
    private let pinchMaxDistance: CGFloat
    private let evidenceCounterStateTrigger: Int
    
    var didChangeStateClosure: ((State) -> Void)?
    private (set) var lastProcessedPointsFingers = defaultHand
    
    init(pinchMaxDistance: CGFloat = 40, evidenceCounterStateTrigger: Int = 5) {
        self.pinchMaxDistance = pinchMaxDistance
        self.evidenceCounterStateTrigger = evidenceCounterStateTrigger
    }
    
    func reset() {
        state = .unknown
        pinchEvidenceCounter = 0
        apartEvidenceCounter = 0
    }
    
    func processFingerPoints(_ pointsFingers: Fingers) {
        pointsFingers.findGesture()
        
        lastProcessedPointsFingers = pointsFingers
//        let distance = pointsFingers.index.TIP.isLocatedLower(then: pointsFingers.thumb.TIP)
        let distance = pointsFingers.index.TIP.distance(from: pointsFingers.thumb.TIP)
        if distance < pinchMaxDistance {
            // Keep accumulating evidence for pinch state.
            pinchEvidenceCounter += 1
            apartEvidenceCounter = 0
            // Set new state based on evidence amount.
            state = (pinchEvidenceCounter >= evidenceCounterStateTrigger) ? .thumbsUp : .possibleThumbsUp
        } else {
            // Keep accumulating evidence for apart state.
            apartEvidenceCounter += 1
            pinchEvidenceCounter = 0
            // Set new state based on evidence amount.
            state = (apartEvidenceCounter >= evidenceCounterStateTrigger) ? .thumbsDown : .possibleThumbsDown
        }
    }
}

// MARK: - CGPoint helpers

extension CGPoint {

    static func midPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }
    
    func distance(from point: CGPoint) -> CGFloat {
        return hypot(point.x - x, point.y - y)
    }
    
    func isLocatedLower(then point: CGPoint) -> CGFloat {
        return y > point.y ? 1 : 100
    }
    
    static func angleBetween(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Double {
        let v1 = CGVector(dx: p1.x - p2.x, dy: p1.y - p2.y)
        let v2 = CGVector(dx: p3.x - p2.x, dy: p3.y - p2.y)
        
        let theta1 = atan2(v1.dy, v1.dx)
        let theta2 = atan2(v2.dy, v2.dx)
        
        let angle = theta1 - theta2
        return (Double(angle) * 180.0) / Double.pi
    }
}

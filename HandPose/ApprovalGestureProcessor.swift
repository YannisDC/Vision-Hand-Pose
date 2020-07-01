//
//  ApprovalGestureProcessor.swift
//  HandPose
//
//  Created by Yannis De Cleene on 29/06/2020.
//  Copyright © 2020 Apple. All rights reserved.
//

import CoreGraphics

public struct Thumb {
    let TIP: CGPoint
    let IP: CGPoint
    let MP: CGPoint
    let CMC: CGPoint
}

public struct Finger {
    let TIP: CGPoint
    let DIP: CGPoint
    let PIP: CGPoint
    let MCP: CGPoint
}

class ApprovalGestureProcessor {
    enum State {
        case possibleThumbsUp
        case thumbsUp
        case possibleThumbsDown
        case thumbsDown
        case unknown
    }
    
    typealias PointsFingers = (thumb: Thumb, index: Finger, middle: Finger, ring: Finger, little: Finger, wrist: CGPoint)
    
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
    private (set) var lastProcessedPointsFingers = PointsFingers(thumb: Thumb(TIP: .zero, IP: .zero, MP: .zero, CMC: .zero),
                                                              index: Finger(TIP: .zero, DIP: .zero, PIP: .zero, MCP: .zero),
                                                              middle: Finger(TIP: .zero, DIP: .zero, PIP: .zero, MCP: .zero),
                                                              ring: Finger(TIP: .zero, DIP: .zero, PIP: .zero, MCP: .zero),
                                                              little: Finger(TIP: .zero, DIP: .zero, PIP: .zero, MCP: .zero),
                                                              wrist: .zero)
    
    init(pinchMaxDistance: CGFloat = 40, evidenceCounterStateTrigger: Int = 3) {
        self.pinchMaxDistance = pinchMaxDistance
        self.evidenceCounterStateTrigger = evidenceCounterStateTrigger
    }
    
    func reset() {
        state = .unknown
        pinchEvidenceCounter = 0
        apartEvidenceCounter = 0
    }
    
    func processPointsFingers(_ pointsFingers: PointsFingers) {
        lastProcessedPointsFingers = pointsFingers
        let distance = pointsFingers.index.TIP.isLocatedLower(then: pointsFingers.thumb.TIP)
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
}

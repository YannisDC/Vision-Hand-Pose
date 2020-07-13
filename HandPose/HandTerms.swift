//
//  HandTerms.swift
//  HandPose
//
//  Created by Yannis De Cleene on 04/07/2020.
//  Copyright © 2020 Apple. All rights reserved.
//

import CoreGraphics

public struct Thumb {
    let TIP: CGPoint
    let IP: CGPoint
    let MP: CGPoint
    let CMC: CGPoint
}

struct PossibleThumb {
    let TIP: CGPoint?
    let IP: CGPoint?
    let MP: CGPoint?
    let CMC: CGPoint?
}

public struct Finger {
    let TIP: CGPoint
    let DIP: CGPoint
    let PIP: CGPoint
    let MCP: CGPoint
}

struct PossibleFinger {
    let TIP: CGPoint?
    let DIP: CGPoint?
    let PIP: CGPoint?
    let MCP: CGPoint?
}

typealias Fingers = (thumb: Thumb, index: Finger, middle: Finger, ring: Finger, little: Finger, wrist: CGPoint)

typealias PossibleFingers = (thumb: PossibleThumb, index: PossibleFinger, middle: PossibleFinger, ring: PossibleFinger, little: PossibleFinger, wrist: CGPoint?)

let defaultHand = Fingers(thumb: Thumb(TIP: .zero, IP: .zero, MP: .zero, CMC: .zero),
                          index: Finger(TIP: .zero, DIP: .zero, PIP: .zero, MCP: .zero),
                          middle: Finger(TIP: .zero, DIP: .zero, PIP: .zero, MCP: .zero),
                          ring: Finger(TIP: .zero, DIP: .zero, PIP: .zero, MCP: .zero),
                          little: Finger(TIP: .zero, DIP: .zero, PIP: .zero, MCP: .zero),
                          wrist: .zero)

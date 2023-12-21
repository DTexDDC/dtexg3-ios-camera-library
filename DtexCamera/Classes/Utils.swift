//
//  Utils.swift
//  DtexCamera
//
//  Created by Admin on 12/20/23.
//

import Foundation

internal func getDeviceOrientation() -> Int {
    let orientation = UIDevice.current.orientation

    switch orientation {
    case .portrait:
        return 0
    case .landscapeLeft:
        return -90
    case .landscapeRight:
        return 90
    case .portraitUpsideDown:
        return 180
    default:
        return 0
    }
}

internal func radiansToDegrees(_ radians: Double) -> Double {
    return radians * 180 / Double.pi
}

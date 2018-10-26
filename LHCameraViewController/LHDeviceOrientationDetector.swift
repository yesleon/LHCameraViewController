//
//  LHDeviceOrientationDetector.swift
//  LHCameraViewController
//
//  Created by 許立衡 on 2018/10/26.
//  Copyright © 2018 narrativesaw. All rights reserved.
//

import CoreMotion

protocol LHDeviceOrientationDetectorDelegate: AnyObject {
    func orientationDetector(_ detector: LHDeviceOrientationDetector, didReceive error: Error)
    func orientationDetector(_ detector: LHDeviceOrientationDetector, didDetectOrientationChangeFrom fromOrientation: UIInterfaceOrientation, toOrientation: UIInterfaceOrientation)
}

class LHDeviceOrientationDetector: NSObject {
    
    weak var delegate: LHDeviceOrientationDetectorDelegate?
    
    private(set) var currentOrientation: UIInterfaceOrientation = .unknown
    private lazy var motionManager: CMMotionManager = {
        let motionManager = CMMotionManager()
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.gyroUpdateInterval = 0.2
        return motionManager
    }()
    
    private let queue: OperationQueue = .init()
    
    func startDeviceOrientationUpdates() {
        motionManager.startAccelerometerUpdates(to: queue) { accelerometerData, error in
            DispatchQueue.main.async {            
                if let error = error {
                    self.delegate?.orientationDetector(self, didReceive: error)
                }
                if let accelerometerData = accelerometerData {
                    self.didReceiveAccelertion(accelerometerData.acceleration)
                }
            }
        }
    }
    
    func stopDeviceOrientationUpdates() {
        motionManager.stopAccelerometerUpdates()
    }
    
    private func didReceiveAccelertion(_ acceleration: CMAcceleration) {
        var newOrientation: UIInterfaceOrientation
        
        if acceleration.x >= 0.75 {
            newOrientation = .landscapeLeft
            
        } else if acceleration.x <= -0.75 {
            newOrientation = .landscapeRight
            
        } else if acceleration.y <= -0.75 {
            newOrientation = .portrait
            
        } else if acceleration.y >= 0.75 {
            newOrientation = .portraitUpsideDown
            
        } else {
            return
        }
        
        guard newOrientation != currentOrientation else { return }
        delegate?.orientationDetector(self, didDetectOrientationChangeFrom: currentOrientation, toOrientation: newOrientation)
        currentOrientation = newOrientation
    }
    
}

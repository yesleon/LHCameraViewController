//
//  PreviewView.swift
//  LHCameraViewController
//
//  Created by 許立衡 on 2018/10/26.
//  Copyright © 2018 narrativesaw. All rights reserved.
//

import UIKit
import AVFoundation
import LHConvenientMethods

class PreviewView: UIView {
    
    enum Error: Swift.Error {
        case noCaptureSession, noPhotoOutput
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    var cameraPosition: AVCaptureDevice.Position {
        guard let input = videoPreviewLayer.session?.inputs.first as? AVCaptureDeviceInput else { return .unspecified }
        return input.device.position
    }
    
    func setCameraPosition(_ position: AVCaptureDevice.Position) throws {
        guard let session = videoPreviewLayer.session else { throw Error.noCaptureSession }
        try session.configure {
            if let input = videoPreviewLayer.session?.inputs.first as? AVCaptureDeviceInput {
                $0.removeInput(input)
            }
            try $0.setInputVideoDevice(try .defaultCamera(position: position))
        }
    }
    
    func setVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
        videoPreviewLayer.connection?.videoOrientation = orientation
    }
    
    func startCapturing() throws {
        let session = AVCaptureSession()
        
        session.sessionPreset = .high
        try session.setInputVideoDevice(try .defaultCamera(position: .back))
        try session.setOutput(AVCapturePhotoOutput())
        videoPreviewLayer.session = session
        session.startRunning()
        
        
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }
    
    func takePhoto(delegate: AVCapturePhotoCaptureDelegate) throws {
        guard let session = videoPreviewLayer.session else { throw Error.noCaptureSession }
        guard let photoOutput = session.outputs.first as? AVCapturePhotoOutput else { throw Error.noPhotoOutput }
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
    }
    
}

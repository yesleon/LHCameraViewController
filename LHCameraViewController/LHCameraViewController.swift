//
//  LHCameraViewController.swift
//  Storyboards
//
//  Created by 許立衡 on 2018/10/25.
//  Copyright © 2018 narrativesaw. All rights reserved.
//

import UIKit
import AVFoundation

public protocol LHCameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ cameraVC: LHCameraViewController, didTakeImage image: UIImage)
    func cameraViewControllerDidCancel(_ cameraVC: LHCameraViewController)
}

open class LHCameraViewController: UIViewController {

    open weak var delegate: LHCameraViewControllerDelegate?
    @IBOutlet private weak var previewView: PreviewView!
    @IBOutlet private weak var overlayView: UIView!
    private lazy var orientationDetector: LHDeviceOrientationDetector = {
        let detector = LHDeviceOrientationDetector()
        detector.delegate = self
        return detector
    }()
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var shutterButton: UIButton!
    
    
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    public init() {
        super.init(nibName: nil, bundle: Bundle(for: LHCameraViewController.self))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        
        if let session = try? makeCaptureSession() {
            previewView.session = session
            session.startRunning()
        }
        
        orientationDetector.startDeviceOrientationUpdates()
    }
    
    deinit {
        orientationDetector.stopDeviceOrientationUpdates()
    }
    
    @IBAction private func didPressCancelButton(_ sender: UIButton) {
        delegate?.cameraViewControllerDidCancel(self)
    }
    
    @IBAction private func didPressShutterButton(_ sender: UIButton) {
        capturePhoto()
        sender.isEnabled = false
    }
    
    enum CaptureSessionError: Error {
        case cantFindDevice, cantAddInput, cantAddOutput
    }
    
    private func makeCaptureSession() throws -> AVCaptureSession {
        let captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { throw CaptureSessionError.cantFindDevice }
        let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        guard captureSession.canAddInput(videoDeviceInput) else { throw CaptureSessionError.cantAddInput }
        captureSession.addInput(videoDeviceInput)
        
        let photoOutput = AVCapturePhotoOutput()
        guard captureSession.canAddOutput(photoOutput) else { throw CaptureSessionError.cantAddOutput }
        captureSession.sessionPreset = .high
        captureSession.addOutput(photoOutput)
        
        captureSession.commitConfiguration()
        return captureSession
    }
    
    private func capturePhoto() {
        guard let session = previewView.session else { return }
        guard let photoOutput = session.outputs.first as? AVCapturePhotoOutput else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

}

extension LHCameraViewController: AVCapturePhotoCaptureDelegate {
    
    open func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        var metadata = photo.metadata
        let orientation = orientationDetector.currentOrientation
        switch orientation {
        case .landscapeLeft:
            metadata["Orientation"] = 3
        case .landscapeRight:
            metadata["Orientation"] = 1
        case .portrait:
            metadata["Orientation"] = 6
        case .portraitUpsideDown:
            metadata["Orientation"] = 8
        default:
            break
        }
        
        guard let imageData = photo.fileDataRepresentation(withReplacementMetadata: metadata,
                                                           replacementEmbeddedThumbnailPhotoFormat: photo.embeddedThumbnailPhotoFormat,
                                                           replacementEmbeddedThumbnailPixelBuffer: nil,
                                                           replacementDepthData: photo.depthData) else { return }
        guard var image = UIImage(data: imageData) else { return }
        
        func cropImage(_ image: UIImage) -> UIImage? {
            guard let cgImage = image.cgImage else { return nil }
            let originalWidth = cgImage.width
            let height = cgImage.height
            let croppedWidth = height * 9/16
            
            guard let croppedCGImage = cgImage.cropping(to: CGRect(x: (originalWidth - croppedWidth) / 2, y: 0, width: croppedWidth, height: height)) else { return nil }
            return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        }
        
        if !orientation.isLandscape {
            if let croppedImage = cropImage(image) {
                image = croppedImage
            }
        }
        
        delegate?.cameraViewController(self, didTakeImage: image)
    }
    
}

extension LHCameraViewController: LHDeviceOrientationDetectorDelegate {
    
    func orientationDetector(_ detector: LHDeviceOrientationDetector, didReceive error: Error) {
        print(error)
    }
    
    func orientationDetector(_ detector: LHDeviceOrientationDetector, didDetectOrientationChangeFrom fromOrientation: UIInterfaceOrientation, toOrientation: UIInterfaceOrientation) {
        UIView.animate(withDuration: 0.2) {
            switch toOrientation {
            case .landscapeLeft:
                [self.cancelButton, self.shutterButton].forEach {
                    $0.transform = CGAffineTransform(rotationAngle: .pi / -2)
                }
                self.overlayView.alpha = 0
            case .landscapeRight:
                [self.cancelButton, self.shutterButton].forEach {
                    $0.transform = CGAffineTransform(rotationAngle: .pi / 2)
                }
                self.overlayView.alpha = 0
            default:
                [self.cancelButton, self.shutterButton].forEach {
                    $0.transform = .identity
                }
                self.overlayView.alpha = 1
            }
        }
    }
    
}
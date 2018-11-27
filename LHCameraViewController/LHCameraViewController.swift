//
//  LHCameraViewController.swift
//  Storyboards
//
//  Created by 許立衡 on 2018/10/25.
//  Copyright © 2018 narrativesaw. All rights reserved.
//

import UIKit
import AVFoundation
import LHZoomTransitionKit

public protocol LHCameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ cameraVC: LHCameraViewController, didTakeImage image: UIImage)
    func cameraViewControllerDidCancel(_ cameraVC: LHCameraViewController)
    func zoomTargetView(for cameraVC: LHCameraViewController) -> UIView?
}

public extension LHCameraViewControllerDelegate {
    func zoomTargetView(for cameraVC: LHCameraViewController) -> UIView? { return nil }
}

open class LHCameraViewController: UIViewController {

    open weak var delegate: LHCameraViewControllerDelegate?
    @IBOutlet private weak var previewView: PreviewView!
    @IBOutlet private weak var overlayView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    private lazy var orientationDetector = LHDeviceOrientationDetector { $0.delegate = self }
    @IBOutlet private var buttons: [UIButton]!
    private var orientation: UIInterfaceOrientation = .unknown
    
    
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    private func initialize() {
        transitioningDelegate = self
    }
    
    public init() {
        super.init(nibName: nil, bundle: Bundle.init(for: LHCameraViewController.self))
        initialize()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            try previewView.startCapturing()
        } catch {
            print(error)
        }
        
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            orientationDetector.startDeviceOrientationUpdates()
        case .pad:
            updateVideoOrientation()
            NotificationCenter.default.addObserver(self, selector: #selector(orientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
        default:
            break
        }
    }
    
    deinit {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            orientationDetector.stopDeviceOrientationUpdates()
        case .pad:
            NotificationCenter.default.removeObserver(self)
        default:
            break
        }
    }
    
    private func updateVideoOrientation() {
        if let videoOrientation = AVCaptureVideoOrientation(UIDevice.current.orientation) {
            previewView.setVideoOrientation(videoOrientation)
        }
    }
    
    @objc private func orientationDidChange() {
        updateVideoOrientation()
        orientation = UIInterfaceOrientation(rawValue: UIDevice.current.orientation.rawValue)!
    }
    
    @IBAction private func didPressCancelButton(_ sender: UIButton) {
        delegate?.cameraViewControllerDidCancel(self)
    }
    
    @IBAction private func didPressShutterButton(_ sender: UIButton) {
        do {
            try previewView.takePhoto(delegate: self)
        } catch {
            print(error)
        }
        sender.isEnabled = false
    }
    
    @IBAction private func switchButtonDidPress(_ sender: UIButton) {
        do {
            switch previewView.cameraPosition {
            case .back:
                try previewView.setCameraPosition(.front)
            case .front:
                try previewView.setCameraPosition(.back)
            case .unspecified:
                fatalError()
            }
        } catch {
            print(error)
        }
    }

}

extension LHCameraViewController: AVCapturePhotoCaptureDelegate {
    
    open func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        var metadata = photo.metadata
        switch (orientation, previewView.cameraPosition) {
        case (.landscapeLeft, .back), (.landscapeRight, .front):
            metadata["Orientation"] = 3
        case (.landscapeRight, .back), (.landscapeLeft, .front):
            metadata["Orientation"] = 1
        case (.portrait, _):
            metadata["Orientation"] = 6
        case (.portraitUpsideDown, _):
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
        imageView.image = image
        
        delegate?.cameraViewController(self, didTakeImage: image)
    }
    
}

extension LHCameraViewController: LHDeviceOrientationDetectorDelegate {
    
    func orientationDetector(_ detector: LHDeviceOrientationDetector, didReceive error: Error) {
        print(error)
    }
    
    func orientationDetector(_ detector: LHDeviceOrientationDetector, didDetectOrientationChangeFrom fromOrientation: UIInterfaceOrientation, toOrientation: UIInterfaceOrientation) {
        orientation = toOrientation
        if UIDevice.current.userInterfaceIdiom == .phone {
            UIView.animate(withDuration: 0.2) {
                switch toOrientation {
                case .landscapeLeft:
                    self.buttons.forEach {
                        $0.transform = CGAffineTransform(rotationAngle: .pi / -2)
                    }
                    self.overlayView.alpha = 0
                case .landscapeRight:
                    self.buttons.forEach {
                        $0.transform = CGAffineTransform(rotationAngle: .pi / 2)
                    }
                    self.overlayView.alpha = 0
                default:
                    self.buttons.forEach {
                        $0.transform = .identity
                    }
                    self.overlayView.alpha = 1
                }
            }
        }
    }
    
}

extension LHCameraViewController: UIViewControllerTransitioningDelegate {
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if imageView.image != nil {
            return LHZoomTransitionAnimationController(duration: 0.4, dampingRatio: 1, source: self, destination: self)
        } else {
            return nil
        }
    }
    
}

extension LHCameraViewController: LHZoomTransitionTargetProviding {
    
    public func targetView(for animationController: LHZoomTransitionAnimationController, operation: LHZoomTransitionAnimationController.Operation, viewControllerKey: UITransitionContextViewControllerKey) -> UIView? {
        switch (operation, viewControllerKey) {
        case (.dismiss, .from):
            return imageView
        case (.dismiss, .to):
            return delegate?.zoomTargetView(for: self)
        default:
            return nil
        }
    }
    
    public func animationController(_ animationController: LHZoomTransitionAnimationController, willAnimate operation: LHZoomTransitionAnimationController.Operation) {
        imageView.alpha = 0
        delegate?.zoomTargetView(for: self)?.alpha = 0
    }
    
    public func animationController(_ animationController: LHZoomTransitionAnimationController, didAnimate operation: LHZoomTransitionAnimationController.Operation) {
        imageView.alpha = 1
        delegate?.zoomTargetView(for: self)?.alpha = 1
    }
    
}

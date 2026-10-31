import AVFoundation
import SwiftUI
import RemoteMouseCore

/// SwiftUI Camera QR Scanner view using AVFoundation.
/// Conforms to ADR 3.4-D, ADR-01, and ADR-03.
public struct QRScannerView: UIViewControllerRepresentable {
    public let onScanned: (ParsedQRData) -> Void
    public let onCancel: () -> Void

    public init(
        onScanned: @escaping (ParsedQRData) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onScanned = onScanned
        self.onCancel = onCancel
    }

    public func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    public func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned, onCancel: onCancel)
    }

    public class Coordinator: NSObject, QRScannerViewControllerDelegate {
        let onScanned: (ParsedQRData) -> Void
        let onCancel: () -> Void

        init(onScanned: @escaping (ParsedQRData) -> Void, onCancel: @escaping () -> Void) {
            self.onScanned = onScanned
            self.onCancel = onCancel
        }

        public func qrScannerDidScan(_ rawValue: String) {
            if let parsed = QRCodeParser.parse(rawValue) {
                onScanned(parsed)
            }
        }

        public func qrScannerDidCancel() {
            onCancel()
        }
    }
}

public protocol QRScannerViewControllerDelegate: AnyObject {
    func qrScannerDidScan(_ rawValue: String)
    func qrScannerDidCancel()
}

public class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    public weak var delegate: QRScannerViewControllerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isScanning = false

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraPermissions()
    }

    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        self?.showPermissionDeniedAlert()
                    }
                }
            }
        case .denied, .restricted:
            showPermissionDeniedAlert()
        @unknown default:
            break
        }
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.previewLayer = preview

        self.captureSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        isScanning = true
    }

    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "Please allow camera access in Settings to scan the Desktop Host pairing QR code.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.delegate?.qrScannerDidCancel()
        })
        present(alert, animated: true)
    }

    public func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard isScanning,
              let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringVal = metadata.stringValue
        else {
            return
        }

        isScanning = false
        captureSession?.stopRunning()
        delegate?.qrScannerDidScan(stringVal)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }
}

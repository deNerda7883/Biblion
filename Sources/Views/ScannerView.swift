import SwiftUI
import AVFoundation
import AppKit
import Vision

struct ScannerView: NSViewRepresentable {
    let onCodice: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCodice: onCodice) }

    func makeNSView(context: Context) -> ScannerNSView {
        let view = ScannerNSView()
        view.coordinator = context.coordinator
        view.avvia()
        return view
    }

    func updateNSView(_ nsView: ScannerNSView, context: Context) {}

    static func dismantleNSView(_ nsView: ScannerNSView, coordinator: Coordinator) {
        nsView.ferma()
    }

    // Usa Vision per analizzare ogni frame — molto più affidabile di
    // AVCaptureMetadataOutput su macOS con barcode EAN-13.
    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let onCodice: (String) -> Void
        private var giaLetto = false
        private var frameCount = 0

        init(onCodice: @escaping (String) -> Void) { self.onCodice = onCodice }

        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
            guard !giaLetto,
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            frameCount += 1
            if frameCount % 30 == 1 {
                print("[Scanner] Frame \(frameCount) - pipeline attivo")
            }

            let request = VNDetectBarcodesRequest { [weak self] req, error in
                if let error {
                    print("[Scanner] Errore Vision: \(error)")
                    return
                }
                guard let self, !self.giaLetto else { return }
                let trovati = req.results as? [VNBarcodeObservation] ?? []
                if !trovati.isEmpty {
                    print("[Scanner] Trovati \(trovati.count) codici: \(trovati.compactMap(\.payloadStringValue))")
                }
                guard let obs = trovati.first(where: { $0.payloadStringValue?.isEmpty == false }),
                      let valore = obs.payloadStringValue else { return }
                self.giaLetto = true
                print("[Scanner] Codice accettato: \(valore)")
                DispatchQueue.main.async { self.onCodice(valore) }
            }
            // Nessun filtro di simbolo — rileva qualsiasi barcode visibile
            do {
                try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
            } catch {
                if frameCount % 30 == 1 { print("[Scanner] Errore perform: \(error)") }
            }
        }
    }
}

final class ScannerNSView: NSView {
    var coordinator: ScannerView.Coordinator?
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }

    func avvia() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.configuraSessione()
        }
    }

    private func configuraSessione() {
        guard session == nil else { return }

        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Su macOS prova prima la fotocamera built-in, poi qualsiasi videocamera
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        guard let device = discovery.devices.first ?? AVCaptureDevice.default(for: .video) else {
            print("[Scanner] Nessuna fotocamera trovata.")
            return
        }
        print("[Scanner] Fotocamera: \(device.localizedName)")
        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            print("[Scanner] Impossibile creare input fotocamera.")
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setSampleBufferDelegate(coordinator,
                                       queue: DispatchQueue(label: "com.libreria.barcode",
                                                            qos: .userInitiated))

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer?.addSublayer(preview)

        self.session = session
        self.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            print("[Scanner] Sessione avviata: \(session.isRunning)")
        }
    }

    func ferma() {
        session?.stopRunning()
        previewLayer?.removeFromSuperlayer()
        session = nil
        previewLayer = nil
    }
}

struct ScannerCard: View {
    @Binding var attivo: Bool
    let onCodice: (String) -> Void

    @State private var statoPermesso: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        VStack(spacing: 12) {
            if attivo {
                ZStack {
                    switch statoPermesso {
                    case .authorized:
                        ScannerView { codice in
                            attivo = false
                            onCodice(codice)
                        }
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.5), lineWidth: 2)
                                .padding(60)
                                .allowsHitTesting(false)
                        )

                    case .denied, .restricted:
                        VStack(spacing: 10) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("Accesso alla fotocamera negato.")
                                .font(.headline)
                            Text("Apri Impostazioni di Sistema → Privacy e Sicurezza → Fotocamera e abilita Libreria.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .font(.callout)
                            Button("Apri Impostazioni") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                        .frame(height: 280)
                        .frame(maxWidth: .infinity)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    default:
                        ProgressView("Richiesta accesso fotocamera…")
                            .frame(height: 280)
                            .frame(maxWidth: .infinity)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .task {
                                let granted = await AVCaptureDevice.requestAccess(for: .video)
                                statoPermesso = granted ? .authorized : .denied
                            }
                    }
                }
                HStack {
                    Text("Inquadra il codice a barre sul retro del libro")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    Spacer()
                    Button("Annulla") { attivo = false }
                }
            } else {
                Button {
                    statoPermesso = AVCaptureDevice.authorizationStatus(for: .video)
                    attivo = true
                } label: {
                    Label("Avvia scanner fotocamera", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

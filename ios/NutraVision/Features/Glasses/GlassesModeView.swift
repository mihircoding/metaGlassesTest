import AVFoundation
import NutraCore
import SwiftUI
import UIKit

/// The camera picked for Glasses Mode. Entry points present `fullScreenCover(item:)` with it, so the cover always
/// sees the choice just made (an `isPresented` cover can read a stale `useGlasses` on first presentation).
enum GlassesSource: String, Identifiable {
    case glasses, phone

    var id: String { rawValue }
}

/// Full-screen hands-free scanning through Meta glasses, or the phone camera when `useGlasses` is false: live
/// picture, voice commands and spoken results. Buttons go through `VoiceLoop.handle`, the same path as voice.
struct GlassesModeView: View {
    let useGlasses: Bool
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var loop: VoiceLoop?

    var body: some View {
        Group {
            if let loop { GlassesModeScreen(loop: loop) } else { ProgressView() }
        }
        .task {
            let current: VoiceLoop
            if let loop {
                current = loop
            } else {
                let source: any CameraSource
                if useGlasses { source = GlassesSession() } else { source = PhoneCameraSession() }
                current = VoiceLoop(source: source, app: app)
                let close = dismiss  // not self: the loop must not retain this view's state
                current.onExit = { close() }
                loop = current
            }
            UIApplication.shared.isIdleTimerDisabled = true  // a locked phone pauses the glasses stream
            await current.start()
        }
        .onDisappear {
            loop?.stop()  // sources don't stop themselves; a leaked glasses session blocks the next one
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

private struct GlassesModeScreen: View {
    @Bindable var loop: VoiceLoop

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Exit") { loop.handle(.exit) }
                Spacer()
                Text(status.text)
                    .font(.footnote.bold())
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.15), in: Capsule())
            }

            camera
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                Text(loop.transcript.isEmpty ? "Say \u{201C}scan this\u{201D}" : "\u{201C}\(loop.transcript)\u{201D}")
                    .font(.title3)
                if !loop.reply.isEmpty { Text(loop.reply).foregroundStyle(.secondary) }
                if let error = loop.error { Text(error).font(.footnote).foregroundStyle(Theme.bad) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !loop.pending.isEmpty {
                ScrollView {
                    ScanResultCard(items: $loop.pending, meal: $loop.selectedMeal,
                                   onAdd: { loop.handle(.add($0)) }, onSkip: { loop.handle(.skip) })
                }
                .frame(maxHeight: 340)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            }

            // Fixed below the scroll area, so Add and Skip are always in reach.
            HStack(spacing: 10) {
                if !loop.pending.isEmpty {
                    Button { loop.handle(.skip) } label: { big("Skip") }
                        .buttonStyle(.bordered)
                    Button { loop.handle(.add(loop.selectedMeal)) } label: { big("Add") }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                }
                Button { loop.handle(.scan) } label: { big("Scan") }
                    .buttonStyle(.borderedProminent)
                    .tint(loop.pending.isEmpty ? Theme.accent : Theme.accent2)
                    .disabled(!loop.isRunning || loop.state == .analyzing)
            }
        }
        .padding()
    }

    private func big(_ title: String) -> some View {
        Text(title).font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 48)
    }

    @ViewBuilder private var camera: some View {
        if let phone = loop.source as? PhoneCameraSession {
            CameraPreview(previewLayer: phone.previewLayer)
        } else if let frame = loop.source.latestFrame {
            Image(uiImage: frame).resizable().scaledToFit()
        } else {
            ProgressView().tint(.white)
        }
    }

    private var status: (text: String, color: Color) {
        guard loop.isRunning else { return ("Stopped", .secondary) }
        switch loop.state {
        case .idle: return ("Listening", Theme.accent)
        case .analyzing: return ("Analyzing\u{2026}", Theme.moderation)
        case .awaitingConfirm: return ("Add it or skip?", Theme.accent2)
        }
    }
}

/// The phone camera's live preview layer, sized to the view.
private struct CameraPreview: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ view: LayerView, context: Context) {}

    final class LayerView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.forEach { $0.frame = bounds }
        }
    }
}

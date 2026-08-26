//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import Quartz
import QuickLookThumbnailing
import DClutterCore

/// §6: a static QLThumbnailGenerator thumbnail at rest; only on focus does
/// this become a live QLPreviewView. Keeps the scroll/swipe conflict
/// impossible by default and renders faster for the common (unfocused) case.
struct PreviewPane: View {
    let candidate: FileCandidate
    @Binding var focused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.preview)
                .fill(DesignTokens.ColorToken.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.preview)
                        .strokeBorder(DesignTokens.ColorToken.hairline)
                )
            if focused {
                LivePreview(url: candidate.url)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.preview))
            } else {
                ThumbnailPreview(url: candidate.url)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.preview))
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
    }
}

private struct ThumbnailPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        loadThumbnail(into: view)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        loadThumbnail(into: view)
    }

    private func loadThumbnail(into view: NSImageView) {
        let size = CGSize(width: 400, height: 300)
        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: size, scale: 2, representationTypes: .thumbnail
        )
        Task { @MainActor in
            let thumbnail = try? await QLThumbnailGenerator.shared
                .generateBestRepresentation(for: request)
            view.image = thumbnail?.nsImage
        }
    }
}

private struct LivePreview: NSViewRepresentable {
    let url: URL

    // QLPreviewView's init is failable on recent SDKs. NSViewRepresentable
    // must return a non-optional view, so fall back to an empty NSView
    // rather than force-unwrapping and crashing on an unpreviewable file.
    func makeNSView(context: Context) -> NSView {
        guard let view = QLPreviewView(frame: .zero, style: .normal) else {
            return NSView()
        }
        view.previewItem = url as QLPreviewItem
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? QLPreviewView else { return }
        if (view.previewItem as? URL) != url {
            view.previewItem = url as QLPreviewItem
        }
    }
}

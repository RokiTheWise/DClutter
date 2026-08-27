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

    final class Coordinator {
        var requestedURL: URL?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        // NSImageView reports the image's own size as its intrinsic content
        // size. A file-type icon is 512pt square, which blew the card's
        // layout out and pushed the control bar off screen. Let the
        // SwiftUI aspect box drive the size instead of the image.
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        loadThumbnail(into: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        loadThumbnail(into: view, coordinator: context.coordinator)
    }

    private func loadThumbnail(into view: NSImageView, coordinator: Coordinator) {
        // Skip redundant reloads, and ignore a slow load that lost the race
        // to a newer card — otherwise the pane can show the previous file's
        // thumbnail while the user is deciding on this one.
        guard coordinator.requestedURL != url else { return }
        coordinator.requestedURL = url

        let size = CGSize(width: 400, height: 300)
        // `.all`, not `.thumbnail`: a zip, a .docx, or anything else with no
        // renderable content has no content thumbnail, and asking only for
        // one leaves the well blank — which reads as a broken app rather
        // than as "this file has no preview". `.all` lets QuickLook fall
        // back to the file-type icon, and NSWorkspace covers the rest.
        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: size, scale: 2, representationTypes: .all
        )
        Task { @MainActor in
            let thumbnail = try? await QLThumbnailGenerator.shared
                .generateBestRepresentation(for: request)
            guard coordinator.requestedURL == url else { return }
            if let rendered = thumbnail?.nsImage {
                view.image = rendered
            } else {
                // Clamp the generic icon too — it ships at 512pt.
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 160, height: 160)
                view.image = icon
            }
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

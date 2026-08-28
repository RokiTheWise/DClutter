//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import QuickLookThumbnailing
import DClutterCore

/// Always a QLThumbnailGenerator thumbnail.
///
/// §6 wanted a live QLPreviewView on focus, but focusing it is what
/// created the two-finger-vertical conflict that section spends a
/// paragraph avoiding — and a focusable QuickLook view also stole first
/// responder, which trapped the keyboard entirely. Double-click opens the
/// real file instead, which is what people reached for anyway, and the
/// thumbnail is the faster path §6 preferred for the common case.
struct PreviewPane: View {
    let candidate: FileCandidate

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.preview)
                .fill(DesignTokens.ColorToken.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.preview)
                        .strokeBorder(DesignTokens.ColorToken.hairline)
                )
                ThumbnailPreview(url: candidate.url)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.preview))
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


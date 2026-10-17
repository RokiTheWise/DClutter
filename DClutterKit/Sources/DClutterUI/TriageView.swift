//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import AppKit
import SwiftUI
import DClutterCore
import DClutterPlatform

/// →/K keep, ←/X stage, Space skip, 1-3 file into a destination,
/// ↑ open the shelf then ←/→ and ⏎, ⌘Z undo, ⇧⌘Z or ⌘Y redo,
/// ⌘⏎ commit sheet, ⌘N add a destination, ↓ rename, ? help.
///
/// §6 assigned ↑ to focusing the preview. That focus is gone: it trapped
/// the keyboard, and it was the sole reason two-finger vertical could not
/// be used for the shelf.
public struct TriageView: View {
    @State private var viewModel: SessionViewModel?
    @State private var context: QueueContext?
    @State private var loadError: String?
    // This is a keyboard-first app: .onKeyPress only fires on a focused
    // view, and nothing else in the window claims focus, so the triage
    // surface must explicitly take it — both at launch and again whenever
    // the commit sheet dismisses (a sheet steals focus while presented).
    @FocusState private var isFocused: Bool
    // §7: how the next card arrives. Resolved at insertion, which is the
    // only moment a transition is read, so it can be set in the same pass
    // as the mutation that inserts the card.
    @State private var entrance: CardEntrance = .rise
    /// The card being animated off-screen, and how far along it is. Exits
    /// cannot be transitions — a removal transition is fixed at insertion,
    /// and the card is on screen long before the user picks a direction —
    /// so the outgoing card is simply moved.
    @State private var exitingCardID: FileCandidate.ID?
    @State private var exitingDirection: CardExit?
    @State private var exitFraction: CGFloat = 0
    @State private var exitCompletion: (() -> Void)?
    @State private var exitGeneration = UUID()
    /// The exits this session's decisions used, newest last, so undo can
    /// bring the card back the way it left. View-local and never persisted:
    /// it feeds animation only, and a session restored from disk simply
    /// rises until its first decision.
    @State private var motionHistory: [CardExit] = []
    @State private var redoMotionHistory: [CardExit] = []
    @State private var showResetConfirm = false
    @State private var showSettings = false
    @State private var settingsSection: SettingsSection = .general
    @AppStorage(InteractionSettings.holdSpeedKey) private var holdSpeed = InteractionSettings.defaultHoldSpeed
    @AppStorage(InteractionSettings.confirmAddFolderKey) private var confirmAddFolder = false
    @State private var heldDecision = HeldDecisionController()
    /// Live swipe position, -1..1, so the card tracks the fingers.
    @State private var swipeProgress: CGFloat = 0
    @State private var swipeMonitor = SwipeMonitorController()
    @State private var draftName = ""
    @FocusState private var renameFieldFocused: Bool
    /// Destination shelf. Opened by two fingers up or ↑, steered by the
    /// fingers or ←/→, committed by lifting or Return. §6 originally put
    /// this on a click-drag to avoid colliding with preview scrolling —
    /// that collision is gone now that the preview is never focusable, so
    /// the gesture can live on the axis people reach for.
    @State private var shelfOpen = false
    @State private var selectedBin = 0
    /// The folder being triaged. State, not a constant: it is the one
    /// thing on this screen the user can change without quitting.
    @State private var folder: URL
    /// Held for as long as this folder is the source. Always created on
    /// switch, even for Downloads — the entitlement grants that folder
    /// directly, so the security-scoped start call there simply finds
    /// nothing to hold and `isScoped` comes back false.
    @State private var access: ScopedFolderAccess?
    @State private var recentFolders: [URL] = []
    /// A folder the user asked for while files were still staged. Held
    /// until they say what should happen to the staged set.
    @State private var pendingSwitch: URL?
    private let sourceFolderStore = SourceFolderStore()

    public init(folder: URL) {
        _folder = State(initialValue: folder)
    }

    /// In a sandboxed app, `homeDirectoryForCurrentUser` returns the
    /// container path, not the real home — appending "Downloads" to it
    /// would scan an empty folder inside the container.
    /// `.downloadsDirectory` is what the
    /// `com.apple.security.files.downloads.read-write` entitlement (§7)
    /// resolves to the real ~/Downloads.
    ///
    /// Note it resolves to a *symlink* into the real folder, not the
    /// folder itself; `DirectoryMetadataProvider` resolves that, since the
    /// URL-based directory enumeration refuses to follow symlinks.
    public static var defaultDownloadsFolder: URL {
        (try? FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    /// True when `url` is the entitlement-granted Downloads folder, which
    /// needs neither a bookmark nor a held scope. Takes the folder in
    /// rather than reading the `folder` property, because `loadSession`
    /// must compare against its captured `targetFolder` snapshot — reading
    /// the live property there would reopen the stale-scan race the
    /// snapshot exists to close.
    private static func isDownloadsFolder(_ url: URL) -> Bool {
        url.resolvingSymlinksInPath().standardizedFileURL
            == Self.defaultDownloadsFolder.resolvingSymlinksInPath().standardizedFileURL
    }

    public var body: some View {
        Group {
            if let viewModel, let context {
                content(viewModel: viewModel, context: context)
            } else if let loadError {
                VStack(spacing: DesignTokens.Spacing.large) {
                    Text("Couldn't read the \"\(folder.lastPathComponent)\" folder.")
                        .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                    Text(loadError)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                    // Before folder switching, the source was always
                    // Downloads and "Try Again" alone was fine — nothing
                    // else could go wrong with it. Now the folder can be a
                    // volume that's gone for good, and retrying a dead
                    // folder forever with no way out short of quitting is
                    // worse than the error itself, so this screen needs the
                    // same two escape routes the control bar gives a
                    // working session.
                    HStack(spacing: DesignTokens.Spacing.small) {
                        Button("Try Again") {
                            // Clearing loadError re-renders into the ProgressView
                            // branch, whose own .task fires loadSession() — do
                            // not also kick one off here, or two concurrent
                            // scans race to write the same persistence file.
                            self.loadError = nil
                        }
                        Button("Return to Downloads") {
                            switchFolder(to: Self.defaultDownloadsFolder)
                        }
                        Button("Choose Folder…") {
                            chooseSourceFolder()
                        }
                    }
                }
                .padding(DesignTokens.Spacing.cardMargin)
            } else {
                ProgressView().task(id: folder) { await loadSession() }
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: SessionViewModel, context: QueueContext) -> some View {
        VStack(spacing: 0) {
            controlBar(viewModel: viewModel)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            Divider()
            workspace(viewModel: viewModel, context: context)
            Divider()
            Group {
                if viewModel.isRenaming {
                    renameField(viewModel: viewModel)
                } else {
                    statusBar(viewModel: viewModel)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.ColorToken.surface.ignoresSafeArea())
        .background { SwipeMonitorWindowReader(controller: swipeMonitor) }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(phases: [.down, .repeat, .up]) { press in handle(press, viewModel: viewModel) }
        .onAppear {
            isFocused = true
            recentFolders = sourceFolderStore.recents()
            swipeMonitor.onProgress = { amount in swipeProgress = amount }
            swipeMonitor.onCommit = { direction in
                // Exactly the keyboard's path. The offset is cleared inside
                // performDecision's animation rather than here: zeroing it a
                // pass early snapped the card back to centre and only then
                // played the exit, which is the hesitation a key press
                // doesn't have — and it left the incoming card's slide
                // outside the animated transaction entirely.
                decide(direction, using: viewModel)
            }
            swipeMonitor.onShelfOpen = { openShelf(viewModel: viewModel) }
            swipeMonitor.onShelfStep = { step in stepBin(by: step, viewModel: viewModel) }
            swipeMonitor.onShelfCommit = { confirmShelf(viewModel: viewModel, fromGesture: true) }
            swipeMonitor.onShelfCancel = {
                shelfOpen = false
                swipeMonitor.endShelfSteering()
                isFocused = true
            }
            swipeMonitor.onSnapBack = {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    swipeProgress = 0
                }
            }
            swipeMonitor.start()
        }
        .onDisappear { swipeMonitor.stop(); heldDecision.stop() }
        .onChange(of: inputIsBlocked(viewModel)) { _, blocked in
            // The editor or dialog owns input until it has finished.
            swipeMonitor.isEnabled = !blocked
            if blocked { heldDecision.stop() }
            if !blocked { isFocused = true }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { heldDecision.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window === swipeMonitor.window {
                heldDecision.stop()
            }
        }
        .onChange(of: shelfOpen) { _, open in
            swipeMonitor.isShelfOpen = open
        }
        .confirmationDialog(
            "Start over?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Start Over", role: .destructive) { resetMotion(); viewModel.reset() }
            // The dialog steals focus the same way the commit sheet does,
            // and unlike the sheet there is no onChange hook watching this
            // one dismiss — Cancel has to reclaim it directly, or every
            // binding on the card is dead until the next click.
            Button("Cancel", role: .cancel) { isFocused = true }
        } message: {
            Text(resetMessage(viewModel: viewModel))
        }
        .confirmationDialog(
            "Switch folders?",
            isPresented: Binding(
                get: { pendingSwitch != nil },
                set: { if !$0 { pendingSwitch = nil } }
            ),
            titleVisibility: .visible
        ) {
            // `viewModel` here is `content(viewModel:)`'s non-optional
            // parameter, not the optional `@State` property — no unwrap
            // needed to reach it. The count is `filesToTrash`, not
            // `stagedForCommit`: confirmCommit only ever trashes the
            // former, and a file unticked in a since-dismissed commit
            // sheet stays staged-but-excluded (SessionViewModel.swift:49-52)
            // — counting the latter here would label the button with more
            // files than it's about to trash.
            Button("Trash \(viewModel.filesToTrash.count) File\(viewModel.filesToTrash.count == 1 ? "" : "s")", role: .destructive) {
                viewModel.confirmCommit()
                // Only leave if it worked. confirmCommit keeps the error
                // on the view model when a file could not be trashed, and
                // switching away would take that message off screen along
                // with the folder it belongs to. On failure, present the
                // commit sheet so the error and the still-staged files are
                // visible — silently returning to the card would look
                // identical to success.
                if viewModel.commitError == nil, let target = pendingSwitch {
                    switchFolder(to: target)
                } else if viewModel.commitError != nil {
                    // Deferred a pass: this update also dismisses the
                    // switch dialog (pendingSwitch below), and presenting a
                    // sheet in the same runloop pass that dismisses a
                    // confirmationDialog typically drops the sheet
                    // entirely. That would make a partial trash failure
                    // invisible — the exact outcome the comment above
                    // exists to prevent — so the sheet has to go up on the
                    // next pass instead.
                    Task { @MainActor in
                        viewModel.showCommitSheet = true
                    }
                }
                pendingSwitch = nil
            }
            Button("Leave Them Staged") {
                if let target = pendingSwitch { switchFolder(to: target) }
                pendingSwitch = nil
            }
            // Same focus hole as showResetConfirm's Cancel, and the same
            // fix: nothing else here reclaims it on dismissal.
            Button("Cancel", role: .cancel) { pendingSwitch = nil; isFocused = true }
        } message: {
            Text("\(viewModel.filesToTrash.count) file\(viewModel.filesToTrash.count == 1 ? " is" : "s are") staged for trash. Files you already filed into folders stay where they are either way.")
        }
        .sheet(isPresented: Bindable(viewModel).showCommitSheet) {
            CommitSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.showCommitSheet) { _, isPresented in
            if !isPresented { isFocused = true }
        }
    }

    private func workspace(viewModel: SessionViewModel, context: QueueContext) -> some View {
        GeometryReader { geometry in
            // Window size controls the well, so every file has the same
            // frame and the actions remain visible at the minimum size.
            let previewHeight = max(100, min(340, geometry.size.height - 330))
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if let current = viewModel.current {
                        CardView(candidate: current, context: context,
                            entrance: entrance,
                            exiting: exitingCardID == current.id ? exitingDirection : nil,
                            exitFraction: exitingCardID == current.id ? exitFraction : 0,
                            onOpen: { viewModel.openCurrentInDefaultApp() },
                            swipeOffset: swipeProgress,
                            onReveal: { viewModel.revealCurrentInFinder() },
                            onRename: { beginRename(viewModel: viewModel) },
                            onCopyName: { viewModel.copyCurrentName() },
                            previewHeight: previewHeight)
                            .scaleEffect(shelfOpen ? 0.85 : 1)
                            .opacity(shelfOpen ? 0.35 : 1)
                            .allowsHitTesting(!shelfOpen)
                            .animation(.easeOut(duration: 0.2), value: shelfOpen)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 36, weight: .light))
                            Text("All caught up").font(.system(size: 22, weight: .medium))
                            Text(viewModel.stagedForCommit.isEmpty
                                ? "Every file in this queue has a decision."
                                : "Review your staged files when you're ready.")
                                .font(.system(size: 13))
                                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 260)
                    }
                    Spacer(minLength: 16)
                    decisionBar(viewModel: viewModel)
                        .opacity(shelfOpen ? 0.35 : 1)
                        .disabled(shelfOpen || viewModel.current == nil || inputIsBlocked(viewModel))
                }
                .frame(maxWidth: 760, maxHeight: .infinity)
                .frame(maxWidth: .infinity)

                if shelfOpen {
                    destinationPanel(viewModel: viewModel)
                        .frame(maxWidth: 760)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: shelfOpen)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private func destinationPanel(viewModel: SessionViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("File into a folder").font(.system(size: 14, weight: .medium))
                    Text("← → to choose · Return to file · Esc to cancel")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                }
                Spacer()
                TriageIconButton(title: "Close destinations", symbol: "xmark", shortcut: "Esc") {
                    shelfOpen = false
                    swipeMonitor.endShelfSteering()
                    isFocused = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            DestinationShelf(
                destinations: viewModel.destinations,
                revealed: 1,
                highlighted: selectedBin,
                onChooseFolder: { chooseDestinationFolder(viewModel: viewModel) },
                onRemove: { index in
                    viewModel.removeDestination(at: index)
                    selectedBin = min(selectedBin, max(binCount(viewModel) - 1, 0))
                },
                onSelect: { index in
                    selectedBin = index
                    confirmShelf(viewModel: viewModel)
                }
            )
            .frame(maxWidth: .infinity)

            if confirmAddFolder && selectedBin >= viewModel.destinations.count {
                Text("Press Return or click “Add folder…” to choose a folder.")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(DesignTokens.ColorToken.cardSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(DesignTokens.ColorToken.hairline))
    }

    /// Says what Start Over will actually do to files on disk. A count
    /// matters here in a way it doesn't for a single undo: nobody can
    /// eyeball twenty files coming back.
    private func resetMessage(viewModel: SessionViewModel) -> String {
        let filed = viewModel.filedThisSessionCount
        var lines = ["Every keep, trash and skip decision becomes undecided again."]
        if filed == 1 {
            lines.append("1 file you filed into a folder moves back to Downloads.")
        } else if filed > 1 {
            lines.append("\(filed) files you filed into folders move back to Downloads.")
        }
        if viewModel.trashedCount > 0 {
            lines.append("Files already in the Trash stay there — committing to the Trash ends a session.")
        }
        return lines.joined(separator: " ")
    }

    private func openShelf(viewModel: SessionViewModel) {
        heldDecision.stop()
        finishExit()
        guard viewModel.current != nil else { return }
        selectedBin = min(selectedBin, max(binCount(viewModel) - 1, 0))
        shelfOpen = true
    }

    /// The row may end with an "Add folder…" bin, so selection runs one
    /// past the configured destinations whenever there is room for another.
    private func binCount(_ viewModel: SessionViewModel) -> Int {
        let extra = viewModel.destinations.count < DestinationStore.maximumDestinations ? 1 : 0
        return viewModel.destinations.count + extra
    }

    private func stepBin(by step: Int, viewModel: SessionViewModel) {
        guard shelfOpen else { return }
        selectedBin = min(max(selectedBin + step, 0), max(binCount(viewModel) - 1, 0))
    }

    private func confirmShelf(viewModel: SessionViewModel, fromGesture: Bool = false) {
        guard shelfOpen else { return }
        swipeMonitor.endShelfSteering()
        if fromGesture && confirmAddFolder && selectedBin >= viewModel.destinations.count {
            // Keep the highlighted bin visible until an explicit Return
            // or click confirms it. Existing destinations still file on lift.
            isFocused = true
            return
        }
        shelfOpen = false
        if selectedBin >= viewModel.destinations.count {
            chooseDestinationFolder(viewModel: viewModel)
        } else {
            fileAway(selectedBin, viewModel: viewModel)
        }
        isFocused = true
    }

    private func chooseDestinationFolder(viewModel: SessionViewModel) {
        heldDecision.stop()
        finishExit()
        shelfOpen = false
        swipeMonitor.endShelfSteering()
        viewModel.chooseDestinationFolder()
        isFocused = true
    }

    private func fileAway(_ index: Int, viewModel: SessionViewModel) {
        heldDecision.stop()
        finishExit()
        guard viewModel.destinations.indices.contains(index) else { return }
        // Up, toward the shelf: the card leaves the way the user just
        // reached, so the file visibly goes into the bin they chose rather
        // than fading out of a decision they never appeared to make.
        record(.up)
        playExit(.up, of: viewModel.current?.id) {
            withAnimation(.easeOut(duration: 0.19)) {
                entrance = .rise
                swipeProgress = 0
                viewModel.moveCurrent(toDestinationAt: index)
            }
        }
    }

    private func beginRename(viewModel: SessionViewModel) {
        heldDecision.stop()
        finishExit()
        guard let current = viewModel.current else { return }
        // Stem only — the extension is preserved automatically and is not
        // the user's to accidentally delete.
        draftName = current.url.deletingPathExtension().lastPathComponent
        viewModel.renameError = nil
        viewModel.isRenaming = true
        renameFieldFocused = true
    }

    private func inputIsBlocked(_ viewModel: SessionViewModel) -> Bool {
        viewModel.isRenaming || viewModel.isChoosingDestinationFolder || viewModel.showCommitSheet
            || showSettings || showResetConfirm || pendingSwitch != nil
    }

    private func openSettings(_ section: SettingsSection) {
        heldDecision.stop()
        finishExit()
        shelfOpen = false
        swipeMonitor.endShelfSteering()
        settingsSection = section
        showSettings = true
    }

    private func handle(_ press: KeyPress, viewModel: SessionViewModel) -> KeyPress.Result {
        let direction: DecisionDirection? = press.key == .leftArrow ? .stage : press.key == .rightArrow ? .keep : nil
        if press.phase == .up {
            if let direction { heldDecision.stop(ifHeld: direction); return .handled }
            return .ignored
        }
        if press.phase == .down { heldDecision.stop() }
        // The rename field owns the keyboard while it is open: Space is a
        // space, not a skip, and every other binding would act on the very
        // file being renamed. Esc is handled by the field's own exit command.
        if inputIsBlocked(viewModel) {
            return .ignored
        }
        // A message about destinations has been read by the time the user
        // presses anything else; leaving it up makes it look like a
        // permanent state rather than a reply to what they just did.
        if viewModel.moveError != nil { viewModel.moveError = nil }
        // Lowercased so Caps Lock doesn't break the letter bindings below.
        let letter = press.key.character.lowercased()
        // Exact modifier set, not `.contains(.command)` — otherwise e.g.
        // ⌥⌘Z would also count as undo. Caps Lock is subtracted because it
        // rides along in the modifier set whenever it happens to be on,
        // which would otherwise silently kill ⌘Z and ⌘⏎.
        if press.modifiers.subtracting(.capsLock) == .command {
            switch press.key {
            case .return: viewModel.showCommitSheet = true; return .handled
            default: break
            }
            if letter == "z" { undo(viewModel); return .handled }
            // ⌘Y mirrors ⇧⌘Z for anyone arriving from Windows.
            if letter == "y" { redo(viewModel); return .handled }
            // §6: add a destination mid-session, so hitting an
            // unclassifiable file doesn't send the user to Finder.
            if letter == "n" { chooseDestinationFolder(viewModel: viewModel); return .handled }
            if letter == "," { openSettings(.general); return .handled }
            return .ignored
        }
        // ⇧⌘Z is the macOS redo convention (⌘Y is the Windows one).
        if press.modifiers.subtracting(.capsLock) == [.command, .shift] {
            if letter == "z" { redo(viewModel); return .handled }
            return .ignored
        }
        // While the shelf is open the arrows steer it rather than deciding,
        // and Return files into the highlighted bin.
        if shelfOpen {
            switch press.key {
            case .leftArrow: stepBin(by: -1, viewModel: viewModel); return .handled
            case .rightArrow: stepBin(by: 1, viewModel: viewModel); return .handled
            case .return: confirmShelf(viewModel: viewModel); return .handled
            case .escape, .upArrow, .downArrow:
                shelfOpen = false
                swipeMonitor.endShelfSteering()
                return .handled
            default: break
            }
            // The Mac's Backspace reports U+0008 while KeyEquivalent.delete
            // is U+007F, so matching the constant alone never fired.
            if press.key == .delete || press.key == .deleteForward
                || press.characters == "\u{8}" || press.characters == "\u{7F}" {
                // Frees a slot for a replacement. Removing a destination
                // only forgets the folder — nothing already filed there
                // moves, and the folder itself is untouched.
                guard selectedBin < viewModel.destinations.count else { return .handled }
                viewModel.removeDestination(at: selectedBin)
                selectedBin = min(selectedBin, max(binCount(viewModel) - 1, 0))
                return .handled
            }
            return .ignored
        }
        // Arrow events also carry system flags such as numericPad and
        // function. Only the four shortcut modifiers change this binding.
        if let direction, press.modifiers.intersection([.command, .control, .option, .shift]).isEmpty {
            // Native repeats are consumed; our own clock supplies the pace.
            if press.phase == .down {
                let speed = InteractionSettings.boundedSpeed(holdSpeed)
                heldDecision.start(direction, speed: speed) { repeating in
                    guard !inputIsBlocked(viewModel), isFocused, !shelfOpen,
                          swipeMonitor.canHandleInput, viewModel.current != nil else { return false }
                    // At the fast end, finish the exit before the next tick.
                    decide(direction, using: viewModel, exitDuration: repeating ? min(0.14, 0.6 / speed) : 0.14)
                    return true
                }
            }
            return .handled
        }
        switch press.key {
        case .rightArrow: decide(.keep, using: viewModel); return .handled
        case .leftArrow: decide(.stage, using: viewModel); return .handled
        case .upArrow: openShelf(viewModel: viewModel); return .handled
        case .downArrow:
            beginRename(viewModel: viewModel)
            return .handled
        case .space: decide(.skip, using: viewModel); return .handled
        // Opening the file is otherwise mouse-only; ⏎ is the obvious key
        // for "show me this one properly" and nothing else claims it here.
        case .return: viewModel.openCurrentInDefaultApp(); return .handled
        default: break
        }
        if press.key.character == "?" { openSettings(.controls); return .handled }
        if let slot = Int(letter), (1...DestinationStore.maximumDestinations).contains(slot) {
            fileAway(slot - 1, viewModel: viewModel)
            return .handled
        }
        return .ignored
    }

    private func controlBar(viewModel: SessionViewModel) -> some View {
        HStack(spacing: 12) {
            TriageIconButton(title: "Settings", symbol: "gearshape", shortcut: "⌘,") {
                openSettings(.general)
            }
            .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                TriageSettingsView(holdSpeed: $holdSpeed, confirmAddFolder: $confirmAddFolder, section: $settingsSection) {
                    helpCard
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                FolderField(
                    url: folder,
                    recents: recentFolders,
                    onPick: { requestSwitch(to: $0) },
                    onChoose: { chooseSourceFolder() }
                )
                Text(FolderField.displayPath(for: folder))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                TriageIconButton(title: "Undo", symbol: "arrow.uturn.backward", shortcut: "⌘Z") { undo(viewModel) }
                    .disabled(!viewModel.canUndo)
                TriageIconButton(title: "Redo", symbol: "arrow.uturn.forward", shortcut: "⇧⌘Z or ⌘Y") { redo(viewModel) }
                    .disabled(!viewModel.canRedo)
            }

            Button { viewModel.showCommitSheet = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tray.full")
                    Text("Review trash")
                    Text("\(viewModel.stagedForCommit.count)")
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(DesignTokens.ColorToken.textPrimary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .frame(height: 32)
                .foregroundStyle(viewModel.stagedForCommit.isEmpty
                    ? DesignTokens.ColorToken.textSecondary : DesignTokens.ColorToken.consequence)
                .background(DesignTokens.ColorToken.consequence.opacity(viewModel.stagedForCommit.isEmpty ? 0 : 0.1), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DesignTokens.ColorToken.hairline))
            }
            .buttonStyle(.plain)
            .focusable(false)
            .fixedSize()
            .disabled(viewModel.stagedForCommit.isEmpty)
            .help("Review staged files before moving anything to Trash  (⌘⏎)")

            Menu {
                Button("Start Over…", systemImage: "arrow.counterclockwise") { showResetConfirm = true }
                Divider()
                Button("Controls & gestures", systemImage: "keyboard") { openSettings(.controls) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .frame(width: 24, height: 32)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Session options")
            .help("Session options")
        }
    }

    private func decisionBar(viewModel: SessionViewModel) -> some View {
        HStack(spacing: 8) {
            TriageDecisionButton(title: "Stage", symbol: "trash", key: "←", consequential: true) {
                decide(.stage, using: viewModel)
            }
            TriageDecisionButton(title: "Skip", symbol: "arrow.uturn.right", key: "␣") {
                decide(.skip, using: viewModel)
            }
            TriageDecisionButton(title: "File", symbol: "folder", key: "↑") {
                openShelf(viewModel: viewModel)
            }
            TriageDecisionButton(title: "Keep", symbol: "checkmark", key: "→") {
                decide(.keep, using: viewModel)
            }
        }
    }

    private func statusBar(viewModel: SessionViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let moveError = viewModel.moveError {
                Text(moveError)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.ColorToken.consequence)
            }
            HStack(spacing: 10) {
                Text("\(viewModel.remainingCount)")
                    .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                    + Text(" left")
                Text("·")
                Text("\(viewModel.sortedSinceLastCommit) sorted")
                Spacer(minLength: 8)

            }
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
        }
    }

    /// §2 principle 2 warns that a text field mid-session kills the loop,
    /// so this is deliberately cheap to leave: Return commits, Esc cancels,
    /// and it replaces the status bar rather than displacing the card.
    @ViewBuilder
    private func renameField(viewModel: SessionViewModel) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.unit) {
            HStack(spacing: DesignTokens.Spacing.small) {
                Text("RENAME")
                    .font(.system(size: 11, design: .monospaced))
                    .kerning(0.5)
                    .foregroundStyle(DesignTokens.ColorToken.textTertiary)
                TextField("", text: $draftName)
                    .onExitCommand {
                        viewModel.isRenaming = false
                        viewModel.renameError = nil
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .focused($renameFieldFocused)
                    .onSubmit { viewModel.renameCurrent(to: draftName) }
                Text("↩ rename · esc cancel")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textTertiary)
            }
            if let error = viewModel.renameError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.ColorToken.consequence)
            }
        }
        .onExitCommand {
            viewModel.isRenaming = false
            viewModel.renameError = nil
            isFocused = true
        }
    }

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            helpSection("Keyboard", rows: Self.keyboardHelp)
            helpSection("Trackpad & mouse", rows: Self.pointerHelp)
        }
    }

    private func helpSection(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(title)
                .font(.system(size: 11, design: .monospaced))
                .kerning(0.5)
                .foregroundStyle(DesignTokens.ColorToken.textTertiary)
            Grid(alignment: .leading, horizontalSpacing: DesignTokens.Spacing.large, verticalSpacing: 7) {
                ForEach(rows, id: \.0) { key, action in
                    GridRow {
                        Text(key)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                            .gridColumnAlignment(.leading)
                            .fixedSize()
                        Text(action)
                            .font(.system(size: 12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    /// Ordered by how often a hand actually reaches for them, not by the
    /// order they were built.
    private static let keyboardHelp: [(String, String)] = [
        ("→", "Keep, next card"),
        ("←", "Stage for trash, next card"),
        ("Hold ←  →", "Repeat at the speed set in Settings"),
        ("Space", "Skip — comes back at the end"),
        ("1 – 3", "File into a destination folder"),
        ("↑", "Open the destination shelf"),
        ("← →", "Choose a folder, then ⏎ to file it"),
        ("⌫", "Remove the highlighted folder"),
        ("Esc  ↓", "Close the shelf"),
        ("⏎", "Open this file"),
        ("↓", "Rename this file"),
        ("⌘Z", "Undo"),
        ("⇧⌘Z  ⌘Y", "Redo"),
        ("⌘⏎", "Review and trash staged files"),
        ("⌘N", "Add a destination folder"),
        ("⌘,", "Settings"),
        ("?", "Show this list"),
    ]

    private static let pointerHelp: [(String, String)] = [
        ("Swipe right", "Keep"),
        ("Swipe left", "Stage for trash"),
        ("Two fingers up", "Open the shelf, slide across, let go"),
        ("Drag back down", "Close the shelf without filing"),
        ("Click File", "Open destination folders"),
        ("Click a folder", "File into that destination"),
        ("Double-click", "Open this file"),
        ("Right-click", "Reveal in Finder, rename, copy name"),
    ]

    private func decide(_ direction: DecisionDirection, using viewModel: SessionViewModel, exitDuration: TimeInterval = 0.14) {
        finishExit()
        guard viewModel.current != nil else { return }
        record(direction.exit)
        playExit(direction.exit, of: viewModel.current?.id, duration: exitDuration) {
            performDecision(direction, using: viewModel)
        }
    }

    /// Animates the current card off-screen, then runs `work` to swap it.
    ///
    /// This is the whole reason exits are not transitions. A removal
    /// transition is fixed when the view is *inserted*, and a card is
    /// inserted before the user has decided anything, so no amount of
    /// re-rendering it with a new `.transition()` can steer its exit. An
    /// earlier attempt did exactly that and only appeared to work when the
    /// same direction was pressed twice in a row, because the second press
    /// reused a card that had been inserted under that direction already.
    ///
    /// `exitingCardID` scopes the travel to the card that is leaving, so
    /// the card arriving behind it is never offset by a value meant for
    /// its predecessor.
    private func playExit(_ exit: CardExit, of id: FileCandidate.ID?, duration: TimeInterval = 0.14, then work: @escaping () -> Void) {
        guard exit != .fade, let id else { work(); return }
        let generation = UUID()
        exitGeneration = generation
        exitCompletion = work
        exitingCardID = id
        exitingDirection = exit
        withAnimation(.easeIn(duration: duration)) {
            exitFraction = 1
        } completion: {
            guard exitGeneration == generation else { return }
            finishExit()
        }
    }

    /// A fast tap may arrive before the previous exit completes. Finish
    /// its accepted decision once, and invalidate the old animation callback.
    private func finishExit() {
        let completion = exitCompletion
        exitCompletion = nil
        exitGeneration = UUID()
        exitingCardID = nil
        exitingDirection = nil
        exitFraction = 0
        completion?()
    }

    /// A fresh decision invalidates the redo path, exactly as it does in
    /// `DClutterSession`.
    private func record(_ exit: CardExit) {
        motionHistory.append(exit)
        redoMotionHistory.removeAll()
    }

    /// Forgets how the current queue got here. A different folder is a
    /// different queue, so the last card's exit says nothing about the
    /// next one, and a stale entry would send the first undo the wrong way.
    private func resetMotion() {
        heldDecision.stop()
        exitCompletion = nil
        exitGeneration = UUID()
        exitingCardID = nil
        exitingDirection = nil
        exitFraction = 0
        entrance = .rise
        motionHistory.removeAll()
        redoMotionHistory.removeAll()
    }

    /// Undo brings the card back the way it left: the file that was sent
    /// away returns from the edge it went toward. Unlike an exit this needs
    /// no staging — an entrance is a transition, and a transition is
    /// resolved when the view is inserted, so setting `entrance` in the
    /// same pass as the mutation is exactly right.
    ///
    /// A session restored from disk has no view-local history, so it rises
    /// instead. The decisions are still undoable; they just have no
    /// recorded direction to replay.
    private func undo(_ viewModel: SessionViewModel) {
        heldDecision.stop()
        finishExit()
        let undone = motionHistory.popLast()
        if let undone { redoMotionHistory.append(undone) }
        withAnimation(.easeInOut(duration: 0.19)) {
            // Inside the transaction, not before it. Assigning `entrance`
            // outside and mutating inside lets SwiftUI coalesce both into
            // one un-animated update, and the card swaps instantly — the
            // flash this replaces.
            entrance = undone.map(CardEntrance.from) ?? .rise
            // Same reason as performDecision: a swipe may have left an
            // offset behind, and clearing it outside this transaction
            // leaves the arriving card's slide unanimated.
            swipeProgress = 0
            viewModel.undo()
        }
        // Reclaim focus: an undo can leave the triage surface without it,
        // and every binding here is dead the moment that happens.
        isFocused = true
    }

    private func redo(_ viewModel: SessionViewModel) {
        heldDecision.stop()
        finishExit()
        let redone = redoMotionHistory.popLast()
        if let redone { motionHistory.append(redone) }
        playExit(redone ?? .fade, of: viewModel.current?.id) {
            withAnimation(.easeInOut(duration: 0.19)) {
                entrance = .rise
                swipeProgress = 0
                viewModel.redo()
            }
            isFocused = true
        }
        isFocused = true
    }

    private func performDecision(_ direction: DecisionDirection, using viewModel: SessionViewModel) {
        withAnimation(.easeInOut(duration: 0.19)) {
            // Set here rather than by the caller: every state change the
            // arriving card depends on has to be inside this transaction,
            // or SwiftUI coalesces them into an un-animated update.
            entrance = .rise
            // Cleared in the same transaction as the swap: the departing
            // card keeps the offset it was rendered with, and the arriving
            // one starts at rest. Clearing it a pass earlier snapped the
            // card back to centre before the exit — the hesitation a key
            // press doesn't have — and left the incoming card's slide
            // outside the animated transaction.
            swipeProgress = 0
            switch direction {
            case .keep: viewModel.keep()
            case .stage: viewModel.stage()
            case .skip: viewModel.skip()
            }
        }
    }

    private func loadSession() async {
        // Snapshot the folder this scan is for, and read only the snapshot
        // from here on. `folder` is `@State`, and `switchFolder` can retarget
        // it while `provider.candidates(in:)` is still running — that scan
        // has no suspension point SwiftUI's cancellation reaches, so it runs
        // to completion regardless. Without the snapshot, a stale scan would
        // resolve its filename and Downloads check against wherever `folder`
        // has since moved to, wiring folder A's candidates to folder B's
        // persistence file.
        let targetFolder = folder
        let provider = DirectoryMetadataProvider()
        let candidates: [FileCandidate]
        do {
            candidates = try await provider.candidates(in: targetFolder)
        } catch {
            loadError = error.localizedDescription
            return
        }
        let ranked = QueueScorer.rank(candidates).map(\.candidate)
        let supportDir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("DClutter", isDirectory: true)
        if let supportDir {
            try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        }
        let stateDir = supportDir ?? FileManager.default.temporaryDirectory
        let persistenceURL = stateDir
            .appendingPathComponent(SessionPersistence.filename(for: targetFolder))

        // Anyone upgrading from ≤0.4.0 has an in-progress session in the
        // old fixed filename. It can only ever have been Downloads, so
        // carry it onto Downloads' new name rather than silently dropping
        // someone's half-finished run.
        let legacy = stateDir.appendingPathComponent("session.json")
        let targetIsDownloads = Self.isDownloadsFolder(targetFolder)
        if targetIsDownloads,
           FileManager.default.fileExists(atPath: legacy.path),
           !FileManager.default.fileExists(atPath: persistenceURL.path) {
            try? FileManager.default.moveItem(at: legacy, to: persistenceURL)
        }
        let session = DClutterSession(candidates: ranked, persistenceURL: persistenceURL)
        // The folder can have moved on again while the scan above was in
        // flight. Only apply this result if it is still the one showing —
        // otherwise it's a stale scan clobbering the in-flight replacement.
        guard folder == targetFolder else { return }
        self.context = QueueContext(candidates: ranked)
        self.viewModel = SessionViewModel(session: session)
    }

    /// Points the app at a different folder. The previous folder's scope is
    /// released only after the new one is held, and the session is torn
    /// down so `.task(id:)` rebuilds it against the new candidates.
    ///
    /// Decisions already carried out on disk are left alone — a move is a
    /// finished action, and having twenty of them fly back to Downloads
    /// because you glanced at another folder is a worse surprise than
    /// leaving them where you put them. Only staged trash is pending, and
    /// `confirmSwitch` resolves that before calling this.
    private func switchFolder(to url: URL) {
        guard url.standardizedFileURL != folder.standardizedFileURL else { return }
        access = ScopedFolderAccess(url: url)
        if !Self.isDownloadsFolder(url) {
            sourceFolderStore.remember(url)
            recentFolders = sourceFolderStore.recents()
        }
        viewModel = nil
        context = nil
        loadError = nil
        shelfOpen = false
        resetMotion()
        swipeMonitor.endShelfSteering()
        folder = url
        isFocused = true
    }

    /// Asks for a folder. The sandbox grants access only through the panel
    /// or a bookmark it minted — a typed path grants nothing — so this is
    /// the only way in.
    private func chooseSourceFolder() {
        heldDecision.stop()
        finishExit()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        // Same affordance as the destination picker, for consistency — a
        // panel that cannot make a folder is a surprise in one place if it
        // can in the other.
        panel.canCreateDirectories = true
        panel.prompt = "Triage Folder"
        panel.message = "Pick a folder to sort through."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        requestSwitch(to: url)
    }

    /// Staged trash is the only genuinely pending state — a move already
    /// happened on disk and stays done. So a switch asks about staged files
    /// and nothing else — and only when there's actually something the
    /// dialog's destructive button would trash; a file staged but already
    /// excluded from commit isn't going anywhere, so it's not worth a
    /// confirmation of its own.
    private func requestSwitch(to url: URL) {
        heldDecision.stop()
        finishExit()
        guard let viewModel, !viewModel.filesToTrash.isEmpty else {
            switchFolder(to: url)
            return
        }
        pendingSwitch = url
    }
}

// Now-playing popover for the SketchyBar side bar.
//
// The bar itself is only 40px wide, so a readable track preview cannot live
// inside it. This draws a small panel immediately to the LEFT of the bar,
// like a tooltip anchored to the music-note button.
//
// It does no polling of its own. The bar plugin (now_playing.sh) already runs
// on a timer and publishes two files that this watches:
//
//   $TMPDIR/sketchybar-nowplaying.track    "title\nartist", absent when idle
//   $TMPDIR/sketchybar-nowplaying.dismiss  present -> stay hidden
//   $TMPDIR/sketchybar-nowplaying.exit     touched  -> quit
//
// So every new track makes the panel appear on its own, without a click, and
// clicking the button dismisses it until the next track change.

import AppKit
import Foundation

let tmp = ProcessInfo.processInfo.environment["TMPDIR"] ?? "/tmp"
let trackPath = tmp + "/sketchybar-nowplaying.track"
let dismissPath = tmp + "/sketchybar-nowplaying.dismiss"
let exitPath = tmp + "/sketchybar-nowplaying.exit"
// Written by now_playing.sh: "x y w h" of the music-note button in
// SketchyBar's top-left-origin coordinates.
let posPath = tmp + "/sketchybar-nowplaying.pos"

// Matches the bar: a 40px strip inset by margin=10 from the right edge.
let barWidth: CGFloat = 40
let barMargin: CGFloat = 10
let gap: CGFloat = 8
// Track info on top, transport controls in a row underneath, so the popup
// stays narrow instead of stretching out sideways to fit them.
let popWidth: CGFloat = 280
let popHeight: CGFloat = 94

// Info block.
let infoX: CGFloat = 42
let infoW: CGFloat = popWidth - 56

// Control row, centred under the info.
let controlStripW: CGFloat = 150
let controlStripX: CGFloat = (popWidth - controlStripW) / 2
let controlStripH: CGFloat = 36
let controlStripY: CGFloat = 10
let controlW: CGFloat = controlStripW / 3

let cornerRadius: CGFloat = 10
// Fallback only, used until the first position file lands.
let fallbackButtonCentreY: CGFloat = 902
let fallbackBarRightX: CGFloat = 1462

/// Reads the button rect published by the plugin. SketchyBar reports
/// coordinates with the origin at the top-left of the desktop and y growing
/// downwards, while AppKit uses the bottom-left with y growing upwards, so the
/// y axis is flipped through the height of the whole desktop.
func buttonRect() -> (x: CGFloat, centreY: CGFloat)? {
    guard let raw = try? String(contentsOfFile: posPath, encoding: .utf8) else { return nil }
    let parts = raw.split(whereSeparator: { $0 == " " || $0 == "\n" }).compactMap { Double($0) }
    guard parts.count >= 4 else { return nil }
    let desktop = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    guard desktop.height > 0 else { return nil }
    return (parts[0], desktop.maxY - (parts[1] + parts[3] / 2))
}


/// Runs a command, discarding what it prints.
func run(_ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return "" }
    let out = (pipe.fileHandleForReading.readDataToEndOfFile())
    p.waitUntilExit()
    return String(data: out, encoding: .utf8) ?? ""
}

struct NowPlaying {
    let title: String
    let artist: String
    let state: String
}

/// Asks the plugin for the current track and whether it is playing. Uses
/// get-raw underneath, which is a 20KB dump because of the artwork, so this
/// is only called when the popover is up or a control was pressed -- never on
/// the poller's timer.
func queryNowPlaying() -> NowPlaying? {
    let env = ProcessInfo.processInfo.environment
    let base = env["CONFIG_DIR"] ?? (NSHomeDirectory() + "/.config/sketchybar")
    let pluginDir = base + "/plugins"
    let script = pluginDir + "/np_query.sh"
    guard FileManager.default.isExecutableFile(atPath: script) else { return nil }
    let out = run(["/bin/sh", script])
    let lines = out.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard lines.count >= 3 else { return nil }
    return NowPlaying(title: lines[0], artist: lines[1], state: lines[2])
}

/// The three transport controls, left to right.
enum Control: CaseIterable {
    case previous, toggle, next

    var glyph: String {
        switch self {
        case .previous: return "\u{F04A}"   // md_skip_previous
        case .next:     return "\u{F04B}"   // md_skip_next
        case .toggle:   return Control.isPlaying ? "\u{F03E}" : "\u{F040}"  // md_pause : md_play
        }
    }

    var argument: String {
        switch self {
        case .previous: return "previous"
        case .next:     return "next"
        case .toggle:   return "togglePlayPause"
        }
    }

    /// Set by the owner; only .toggle cares.
    static var isPlaying = true
}

let bgColor = NSColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 0.94)
let titleColor = NSColor.white
let artistColor = NSColor(white: 0.62, alpha: 1.0)

func mono(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    NSFont(name: "JetBrainsMono Nerd Font", size: size)
        ?? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
}


/// The transport controls. A plain view that works out which third was clicked
/// from the mouse position: on a non-activating panel a button would swallow
/// the first click while trying to take focus.
final class ControlStrip: NSView {
    var onPress: ((Control) -> Void)?
    private var labels: [Control: NSTextField] = [:]
    private var hover: Control?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let i = Int((p.x / controlW).rounded(.down))
        guard i >= 0, i < Control.allCases.count else { return }
        onPress?(Control.allCases[i])
    }

    override func mouseExited(with event: NSEvent) {
        hover = nil
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                      options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
                                      owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let i = Int((p.x / controlW).rounded(.down))
        let c = (i >= 0 && i < Control.allCases.count) ? Control.allCases[i] : nil
        if c != hover { hover = c; needsDisplay = true }
        window?.invalidateCursorRects(for: self)
    }

    /// Called when a press starts, so the pressed one can be lit up.
    private var pressed: Control?
    func setPressed(_ c: Control?) { pressed = c; needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        NSColor.white.setFill()
        for (i, c) in Control.allCases.enumerated() {
            let r = NSRect(x: CGFloat(i) * controlW, y: 0, width: controlW, height: bounds.height)
            let bg: NSColor
            if pressed == c { bg = NSColor(white: 1.0, alpha: 0.30) }
            else if hover == c { bg = NSColor(white: 1.0, alpha: 0.14) }
            else { bg = .clear }
            if bg != .clear {
                let path = NSBezierPath(roundedRect: r.insetBy(dx: 3, dy: 8), xRadius: 7, yRadius: 7)
                bg.setFill(); path.fill()
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        for (i, c) in Control.allCases.enumerated() {
            let label = labels[c] ?? NSTextField(labelWithString: "")
            if labels[c] == nil {
                label.font = mono(15, .medium)
                label.textColor = titleColor
                label.alignment = .center
                label.isBezeled = false
                label.drawsBackground = false
                labels[c] = label
                addSubview(label)
            }
            label.stringValue = c.glyph
            label.frame = NSRect(x: CGFloat(i) * controlW, y: (bounds.height - 20) / 2,
                                 width: controlW, height: 20)
        }
    }
}

final class Popover {
    private let panel: NSPanel
    private let titleLabel = NSTextField(labelWithString: "")
    private let artistLabel = NSTextField(labelWithString: "")
    private let iconLabel = NSTextField(labelWithString: "\u{F0387}")   // md_music_note
    private let controls = ControlStrip()

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: popWidth, height: popHeight),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered,
                        defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false

        let box = NSView(frame: NSRect(x: 0, y: 0, width: popWidth, height: popHeight))
        box.wantsLayer = true
        box.layer?.cornerRadius = cornerRadius
        box.layer?.backgroundColor = bgColor.cgColor
        box.layer?.masksToBounds = true

        iconLabel.font = mono(15, .medium)
        iconLabel.textColor = titleColor
        iconLabel.frame = NSRect(x: 14, y: 60, width: 22, height: 22)

        titleLabel.font = mono(13, .semibold)
        titleLabel.textColor = titleColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.frame = NSRect(x: infoX, y: 68, width: infoW, height: 17)

        artistLabel.font = mono(11, .regular)
        artistLabel.textColor = artistColor
        artistLabel.lineBreakMode = .byTruncatingTail
        artistLabel.frame = NSRect(x: infoX, y: 52, width: infoW, height: 14)

        controls.frame = NSRect(x: controlStripX, y: controlStripY,
                                width: controlStripW, height: controlStripH)
        controls.onPress = { [weak self] c in self?.press(c) }
        box.addSubview(iconLabel)
        box.addSubview(titleLabel)
        box.addSubview(artistLabel)
        box.addSubview(controls)
        panel.contentView = box
    }

    /// Anchors the panel to the left of the bar, vertically centred on the
    /// music-note button.
    func place() {
        if let r = buttonRect() {
            // Sit just left of the button, vertically centred on it.
            panel.setFrameOrigin(NSPoint(x: r.x - gap - popWidth,
                                         y: max(12, r.centreY - popHeight / 2)))
            return
        }
        // No position file yet: fall back to the old hardcoded geometry.
        let screen = NSScreen.screens.first?.frame ?? CGRect(x: 0, y: 0, width: 1512, height: 982)
        let x = fallbackBarRightX - gap - popWidth
        let centreFromBottom = screen.height - fallbackButtonCentreY
        panel.setFrameOrigin(NSPoint(x: x, y: max(12, centreFromBottom - popHeight / 2)))
    }

    /// A transport control was pressed. Briefly light it, hand the command to
    /// nowplaying-cli, then re-read the track so the text follows along
    /// without waiting for the poller's next tick.
    private func press(_ c: Control) {
        controls.setPressed(c)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.controls.setPressed(nil)
        }
        DispatchQueue.global(qos: .userInitiated).async {
            _ = run(["nowplaying-cli", c.argument])
            // Let the player settle before asking what it is doing now.
            Thread.sleep(forTimeInterval: 0.45)
            if let info = queryNowPlaying() {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    Control.isPlaying = (info.state == "playing")
                    self.titleLabel.stringValue = info.title.isEmpty ? "—" : info.title
                    self.artistLabel.stringValue = info.artist
                    self.artistLabel.isHidden = info.artist.isEmpty
                    self.controls.needsDisplay = true
                }
            }
        }
    }

    func show(title: String, artist: String) {
        titleLabel.stringValue = title.isEmpty ? "—" : title
        artistLabel.stringValue = artist
        artistLabel.isHidden = artist.isEmpty
        place()
        panel.orderFrontRegardless()
        // The poller does not publish play/pause, so ask once here to get the
        // middle glyph the right way round. Off the main thread: get-raw is a
        // 20KB dump and would otherwise stall the run loop mid-animation.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let info = queryNowPlaying() else { return }
            DispatchQueue.main.async {
                Control.isPlaying = (info.state == "playing")
                self?.controls.needsDisplay = true
            }
        }
    }

    func hide() { panel.orderOut(nil) }
    var isVisible: Bool { panel.isVisible }
}

// The main thread must own the AppKit run loop, otherwise the panel is never
// painted promptly. So the app runs here and the watching happens elsewhere.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock tile, no menu bar

let pop = Popover()
pop.hide()

// Owned by this thread only. Writing it from the main thread (inside
// DispatchQueue.main.async) meant the watcher never observed it flip, and the
// popover never went away.
var wasShown = false

// The click concern.
let heldPath = tmp + "/sketchybar-nowplaying.held"
var wasHeld = false

// The new-song concern.
let toastDuration: TimeInterval = 2.0
var toastAt: Date? = nil

var missingSince: Date? = nil
var lastTrack: (String, String)?
var lastExit = (try? FileManager.default.attributesOfItem(atPath: exitPath)[.modificationDate]) as? Date

/// Reads the title/artist the bar plugin published, or nil when nothing plays.
func readTrack() -> (String, String)? {
    guard let raw = try? String(contentsOfFile: trackPath, encoding: .utf8) else { return nil }
    let parts = raw.components(separatedBy: "\n")
    guard parts.count == 2, !(parts[0] + parts[1]).isEmpty else { return nil }
    return (parts[0], parts[1])
}

let watcher = Thread {
    // Self-terminate when nothing has been playing for a while. Relying on the
    // plugin to kill us was unreliable (a pkill from a SketchyBar-spawned
    // script does not always land), and an idle popover has nothing to show.
    var idleSince: Date? = nil
    let idleLimit: TimeInterval = 10

    // Both concerns put the panel up and take it down through these, which is
    // what keeps wasShown owned by this thread.
    func show(_ t: (String, String)) {
        DispatchQueue.main.async { pop.show(title: t.0, artist: t.1) }
        wasShown = true
    }
    func hideIfUp() {
        if wasShown { DispatchQueue.main.async { pop.hide() } }
        wasShown = false
        toastAt = nil
    }

    while true {
        let exitTouched = (try? FileManager.default.attributesOfItem(atPath: exitPath)[.modificationDate]) as? Date
        if let e = exitTouched, let w = lastExit, e > w { break }
        lastExit = exitTouched

        let track = readTrack()
        let dismissed = FileManager.default.fileExists(atPath: dismissPath)

        if track != nil {
            idleSince = nil
        } else {
            if idleSince == nil { idleSince = Date() }
            if let since = idleSince, Date().timeIntervalSince(since) > idleLimit { break }
        }

        // The two things the popover reacts to, kept deliberately separate:
        //
        //   1. a new song  -> put the info up for a moment (see "new song")
        //   2. the click   -> hold it open, or close it at once (see "click")
        //
        // Each owns its own state. The song change is the trigger for the
        // toast, so nothing has to remember "already toasted" -- a track that
        // has not changed cannot re-show it, and the next new song will.

        // nowplaying-cli occasionally returns nothing for a beat, and the
        // plugin deletes the track file when it does. Hiding on that single
        // miss made the popup drop out on its own, so wait for it to stick.
        var goneForAWhile = false
        if track == nil {
            if missingSince == nil { missingSince = Date() }
            goneForAWhile = Date().timeIntervalSince(missingSince!) > 0.8
        } else {
            missingSince = nil
        }

        // A new song is simply the title/artist differing from what we last
        // saw. Only redraw on that: show() ends in orderFrontRegardless(), and
        // calling it every poll re-orders a visible window, which flickers.
        var newSong = false
        if let t = track {
            if lastTrack?.0 != t.0 || lastTrack?.1 != t.1 {
                lastTrack = t
                newSong = true
            }
        }

        // The click concern's own state, read independently of the song.
        let held = FileManager.default.fileExists(atPath: heldPath)

        // Nothing to show, or turned off: get out of the way.
        if dismissed || goneForAWhile {
            hideIfUp()
            wasHeld = held
        } else if let t = track {
            // 2. the click: a click holds it open, a second click closes it
            //    on the spot rather than waiting out the toast timer.
            if held != wasHeld {
                wasHeld = held
                if held {
                    show(t)
                } else if wasShown {
                    hideIfUp()
                }
            }

            if held {
                // Held open: stay up, but follow along to the new song.
                if newSong && !wasShown { show(t) }
            } else {
                // 1. a new song: up for a moment, then back down by itself.
                if newSong {
                    show(t)
                    toastAt = Date()
                } else if wasShown, let since = toastAt,
                          Date().timeIntervalSince(since) > toastDuration {
                    hideIfUp()
                }
            }
        }

        // Cheap: this only stats a few files, no subprocesses.
        Thread.sleep(forTimeInterval: 0.1)
    }
    DispatchQueue.main.async { NSApp.terminate(nil) }
}
watcher.start()

app.run()

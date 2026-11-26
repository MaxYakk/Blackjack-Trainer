import Foundation
#if canImport(AudioToolbox)
import AudioToolbox
#endif

/// Lightweight sound cues built from the system sound library (no bundled assets).
///
/// The cues are deliberately quiet and short: soft key-click "tock" and "tink"
/// sounds for cards and chips, one gentle tink for a win. A loss and a push
/// make no sound at all, so a bad hand never gets a buzzer on top of it.
enum Sound {
    static var enabled = true

    enum Cue {
        case card, chip, win, lose, push

        #if canImport(AudioToolbox)
        /// The system sound for this cue, or nil when the cue is silent.
        var systemID: SystemSoundID? {
            switch self {
            case .card: return 1104   // soft "tock": a card landing
            case .chip: return 1103   // light "tink": a chip placed
            case .win:  return 1057   // single gentle tink
            case .lose: return nil    // silent on purpose
            case .push: return nil    // silent on purpose
            }
        }
        #endif

        /// Whether the cue makes any sound at all.
        var isAudible: Bool {
            switch self {
            case .card, .chip, .win: return true
            case .lose, .push: return false
            }
        }
    }

    static func play(_ cue: Cue) {
        guard enabled else { return }
        #if canImport(AudioToolbox)
        guard let id = cue.systemID else { return }
        AudioServicesPlaySystemSound(id)
        #endif
    }
}

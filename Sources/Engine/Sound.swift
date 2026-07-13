import Foundation
#if canImport(AudioToolbox)
import AudioToolbox
#endif

/// Lightweight sound cues built from the system sound library (no bundled assets).
enum Sound {
    static var enabled = true

    enum Cue {
        case card, chip, win, lose, push

        #if canImport(AudioToolbox)
        var systemID: SystemSoundID {
            switch self {
            case .card: return 1104   // short "tock" — card landing
            case .chip: return 1105   // "tink" — chip placed
            case .win:  return 1025   // bright positive
            case .lose: return 1073   // muted negative
            case .push: return 1103
            }
        }
        #endif
    }

    static func play(_ cue: Cue) {
        guard enabled else { return }
        #if canImport(AudioToolbox)
        AudioServicesPlaySystemSound(cue.systemID)
        #endif
    }
}

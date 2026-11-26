import Foundation

// Helpers for reading saved progress that may be old, partial or damaged.
// Each value that can't be read falls back to its default on its own, so one
// bad entry costs that entry, not the player's whole history.

/// A coding key for dictionaries keyed by arbitrary strings.
struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

extension KeyedDecodingContainer {
    /// The value if present and readable; nil if missing OR the wrong type.
    func tolerant<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }

    /// A string-keyed dictionary, skipping any entry that can't be read.
    /// Nil only when the key is missing or isn't a dictionary at all.
    func lossyDictionary<V: Decodable>(_ type: V.Type, forKey key: Key) -> [String: V]? {
        guard let nested = try? nestedContainer(keyedBy: AnyCodingKey.self, forKey: key) else { return nil }
        var out: [String: V] = [:]
        for entryKey in nested.allKeys {
            if let value = try? nested.decode(V.self, forKey: entryKey) {
                out[entryKey.stringValue] = value
            }
        }
        return out
    }

    /// An array, skipping any element that can't be read.
    func lossyArray<V: Decodable>(_ type: V.Type, forKey key: Key) -> [V]? {
        guard var nested = try? nestedUnkeyedContainer(forKey: key) else { return nil }
        var out: [V] = []
        while !nested.isAtEnd {
            if let value = try? nested.decode(V.self) {
                out.append(value)
            } else if (try? nested.decode(SkipValue.self)) == nil {
                break   // can't even step past it; keep what was read so far
            }
        }
        return out
    }
}

/// Consumes one JSON value of any shape so a lossy array can step past it.
private struct SkipValue: Decodable {
    init(from decoder: Decoder) throws {}
}

/// `SpotStat` read field by field (it lives in ProgressMetrics.swift with a
/// synthesized decoder, which would reject the whole entry on one bad field).
struct TolerantSpotStat: Decodable {
    let value: SpotStat

    private enum Keys: String, CodingKey { case correct, total }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let total = max(0, c.tolerant(Int.self, forKey: .total) ?? 0)
        let correct = min(total, max(0, c.tolerant(Int.self, forKey: .correct) ?? 0))
        value = SpotStat(correct: correct, total: total)
    }
}

/// A `[String: Int]` map that drops unreadable entries.
struct TolerantIntMap: Decodable {
    let value: [String: Int]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        var out: [String: Int] = [:]
        for key in c.allKeys {
            if let n = try? c.decode(Int.self, forKey: key) { out[key.stringValue] = n }
        }
        value = out
    }
}

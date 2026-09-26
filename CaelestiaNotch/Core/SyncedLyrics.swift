import Foundation

struct LyricLine: Equatable, Sendable {
    let time: TimeInterval
    let text: String
}

struct SyncedLyrics: Equatable, Sendable {
    let lines: [LyricLine]

    init(lrc: String) {
        let timestamp = try! NSRegularExpression(pattern: #"\[(\d+):(\d{2})(?:\.(\d{1,3}))?\]"#)
        let offsetPattern = try! NSRegularExpression(pattern: #"(?i)\[offset:([+-]?\d+)\]"#)
        let source = lrc as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let offset: Double
        if let match = offsetPattern.firstMatch(in: lrc, range: fullRange) {
            // LRC's positive offset advances the lyric relative to the audio.
            offset = (Double(source.substring(with: match.range(at: 1))) ?? 0) / 1000
        } else {
            offset = 0
        }

        var parsed: [LyricLine] = []
        for row in lrc.components(separatedBy: .newlines) {
            let string = row as NSString
            let matches = timestamp.matches(in: row, range: NSRange(location: 0, length: string.length))
            guard let last = matches.last else { continue }
            let text = string.substring(from: NSMaxRange(last.range)).trimmingCharacters(in: .whitespaces)
            for match in matches {
                guard let minutes = Double(string.substring(with: match.range(at: 1))),
                      let seconds = Double(string.substring(with: match.range(at: 2))), seconds < 60 else { continue }
                let fractionRange = match.range(at: 3)
                let fraction = fractionRange.location == NSNotFound ? "" : string.substring(with: fractionRange)
                let milliseconds = (Double(fraction) ?? 0) / pow(10, Double(fraction.count))
                let time = minutes * 60 + seconds + milliseconds - offset
                guard time.isFinite else { continue }
                parsed.append(LyricLine(time: max(0, time), text: text))
            }
        }

        // Preserve file order for equal timestamps, with the last entry taking priority.
        let sorted = parsed.enumerated().sorted {
            $0.element.time == $1.element.time ? $0.offset < $1.offset : $0.element.time < $1.element.time
        }
        var unique: [LyricLine] = []
        for item in sorted {
            if unique.last?.time == item.element.time { unique.removeLast() }
            unique.append(item.element)
        }
        lines = unique
    }

    var hasText: Bool { lines.contains { !$0.text.isEmpty } }

    func line(at position: TimeInterval) -> LyricLine? {
        guard position.isFinite, let first = lines.first, position >= first.time else { return nil }
        var lower = 0
        var upper = lines.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if lines[middle].time <= position { lower = middle + 1 }
            else { upper = middle }
        }
        return lines[lower - 1]
    }
}

import Foundation

/// djb2, a small deterministic string hash — mirrors `../web/src/lib/utils.ts`'s `djb2`. Operates
/// entirely in `UInt32` (wrapping multiply + XOR), the same effective arithmetic as the web
/// version's `(hash * 33) ^ charCode` followed by `>>> 0` to force an unsigned 32-bit result.
private func djb2(_ string: String) -> UInt32 {
    var hash: UInt32 = 5381
    for byte in string.utf8 {
        hash = (hash &* 33) ^ UInt32(byte)
    }
    return hash
}

private extension String {
    func leftPadded(to length: Int, with character: Character = "0") -> String {
        count >= length ? self : String(repeating: character, count: length - count) + self
    }
}

/// There is no `users` collection in this app's data model, so an assignee is captured as a
/// free-typed name rather than looked up from a directory. Verified live against the real project:
/// `cards.assigneeId` is schema-typed as an ObjectId reference, not a free-form string — a plain
/// slug is rejected with "Invalid ObjectId format for assigneeId". This derives a stable,
/// valid-looking 24-hex-char id from the typed name (the same name always maps to the same id)
/// purely so `assigneeId` passes that format check and is never left orphaned from
/// `assigneeName` — it is not a real user lookup key. Ports `../web/src/lib/utils.ts`'s
/// `pseudoObjectId` — using this app's own byte encoding (UTF-8 vs. the web version's UTF-16 code
/// units) is fine since the hash only needs to be stable *within* this app's own reads/writes, not
/// bit-identical across every language port.
func pseudoObjectId(_ seed: String) -> String {
    let trimmed = seed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    var hex = ""
    var round = 0
    while hex.count < 24 {
        let hashed = djb2("\(trimmed):\(round)")
        hex += String(hashed, radix: 16).leftPadded(to: 8)
        round += 1
    }
    return String(hex.prefix(24))
}

/// Ports `../web/src/lib/utils.ts`'s `formatRelativeTime`.
func formatRelativeTime(_ date: Date?) -> String {
    guard let date else { return "" }
    let diffSeconds = Int(Date().timeIntervalSince(date).rounded())
    if diffSeconds < 5 { return "just now" }
    if diffSeconds < 60 { return "\(diffSeconds)s" }
    let diffMinutes = Int((Double(diffSeconds) / 60).rounded())
    if diffMinutes < 60 { return "\(diffMinutes)m" }
    let diffHours = Int((Double(diffMinutes) / 60).rounded())
    if diffHours < 24 { return "\(diffHours)h" }
    let diffDays = Int((Double(diffHours) / 24).rounded())
    if diffDays < 7 { return "\(diffDays)d" }
    return date.formatted(date: .abbreviated, time: .omitted)
}

/// Ports `../web/src/lib/utils.ts`'s `initials`.
func initials(_ name: String) -> String {
    let parts = name.trimmingCharacters(in: .whitespaces).split(separator: " ").filter { !$0.isEmpty }
    if parts.isEmpty { return "?" }
    let first = parts[0].first.map(String.init) ?? ""
    let last = parts.count > 1 ? (parts[parts.count - 1].first.map(String.init) ?? "") : ""
    return (first + last).uppercased()
}

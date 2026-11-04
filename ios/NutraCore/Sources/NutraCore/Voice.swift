import Foundation

public enum VoiceCommand: Equatable {
    case scan, add(Meal?), skip, status, exit, none

    static func normalize(_ s: String) -> String {
        let mapped = s.lowercased().replacingOccurrences(of: "\u{2019}", with: "'").map { c -> Character in
            (c.isLetter || c.isNumber || c == "'") ? c : " "
        }
        return String(mapped).split(separator: " ").joined(separator: " ")
    }

    public static func parse(_ text: String) -> VoiceCommand {
        let padded = " " + normalize(text) + " "
        func has(_ phrases: [String]) -> Bool { phrases.contains { padded.contains(" " + $0 + " ") } }
        if has(["stop glasses", "exit"]) { return .exit }
        if has(["how am i doing", "calories left", "remaining"]) { return .status }
        if has(["scan", "what is this", "what's this", "what am i eating"]) { return .scan }
        if has(["skip", "no", "cancel", "nope"]) { return .skip }
        if has(["add", "log", "yes", "yeah"]) {
            let meals: [(String, Meal)] = [("breakfast", .breakfast), ("lunch", .lunch), ("dinner", .dinner),
                                           ("snack", .snack), ("snacks", .snack)]
            return .add(meals.first { padded.contains(" " + $0.0 + " ") }?.1)
        }
        return .none
    }
}

public enum VoiceState: Equatable { case idle, analyzing, awaitingConfirm }

public enum VoiceEffect: Equatable {
    case captureAndAnalyze, log(Meal?), discard, speak(String), speakStatus, stop
}

public enum VoiceFlow {
    public static func next(_ state: VoiceState, _ command: VoiceCommand) -> (VoiceState, [VoiceEffect]) {
        switch (state, command) {
        case (.idle, .scan): return (.analyzing, [.captureAndAnalyze])
        case (.awaitingConfirm, .scan): return (.analyzing, [.discard, .captureAndAnalyze])
        case (.awaitingConfirm, .add(let m)): return (.idle, [.log(m)])
        case (.idle, .add): return (.idle, [.speak(SpokenText.nothingPending)])
        case (.awaitingConfirm, .skip): return (.idle, [.discard, .speak(SpokenText.skipped)])
        case (.idle, .status), (.awaitingConfirm, .status): return (state, [.speakStatus])
        case (.awaitingConfirm, .exit): return (.idle, [.discard, .stop])
        case (_, .exit): return (.idle, [.stop])
        default: return (state, [])
        }
    }
}

public enum SpokenText {
    public static let notFood = "I don't see food. Try again."
    public static let analyzeFailed = "Couldn't analyze. Try again."
    public static let productNotFound = "I couldn't find that product. Try saying scan this."
    public static let nothingPending = "Nothing to add. Say scan this first."
    public static let skipped = "Skipped."
    public static let glassesDisconnected = "Glasses disconnected."

    private static func n(_ x: Double) -> Int { Int(x.rounded()) }

    public static func scanResult(itemNames: [String], total: Nutrients, lowConfidence: Bool,
                                  verdict: Verdict, conditionName: String?) -> String {
        let what: String
        if lowConfidence {
            what = "I think this is " + (itemNames.count == 1 ? itemNames[0] : "\(itemNames.count) items")
        } else {
            what = itemNames.joined(separator: ", ")
        }
        var s = "\(what), about \(n(total.kcal)) calories and \(n(total.proteinG)) grams of protein. \(verdict.level.rawValue)"
        if var name = conditionName {
            if name.hasSuffix(")"), let open = name.range(of: " (", options: .backwards) {
                name = String(name[..<open.lowerBound])
            }
            s += " for your \(name) plan"
        }
        if let r = verdict.reasons.first?.text, let f = r.first {
            s += ": " + String(f).lowercased() + String(r.dropFirst())
        }
        return s + ". Say add it or skip."
    }

    public static func added(consumedKcal: Double, goalKcal: Double) -> String {
        "Added. \(n(consumedKcal)) of \(n(goalKcal)) calories today."
    }

    public static func status(consumedKcal: Double, goalKcal: Double, closestLimit: (name: String, percent: Int)?) -> String {
        let left = n(goalKcal) - n(consumedKcal)
        var s = left >= 0 ? "You have \(left) calories left today." : "You're \(-left) calories over today's goal."
        if let c = closestLimit { s += " \(c.name) is at \(c.percent)% of your limit." }
        return s
    }
}

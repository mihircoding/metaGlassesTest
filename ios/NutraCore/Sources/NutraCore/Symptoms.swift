import Foundation

/// Digestive symptoms a patient can log, for IBS, IBD, celiac disease and EoE.
public enum Symptom: String, Codable, Sendable, CaseIterable {
  case abdominalPain = "abdominal_pain", bloating, gas, diarrhea, constipation, urgency, nausea, heartburn
  case troubleSwallowing = "trouble_swallowing", foodStuck = "food_stuck", fatigue
  case bloodInStool = "blood_in_stool"

  public var title: String {
    switch self {
    case .abdominalPain: return "Belly pain or cramps"
    case .bloating: return "Bloating"
    case .gas: return "Gas"
    case .diarrhea: return "Diarrhea"
    case .constipation: return "Constipation"
    case .urgency: return "Urgent need to go"
    case .nausea: return "Nausea"
    case .heartburn: return "Heartburn or reflux"
    case .troubleSwallowing: return "Trouble swallowing"
    case .foodStuck: return "Food stuck in throat or chest"
    case .fatigue: return "Tiredness"
    case .bloodInStool: return "Blood in stool"
    }
  }

  /// Symptoms a doctor should hear about soon, however mild the rest of the day was.
  public var isRedFlag: Bool { self == .bloodInStool || self == .foodStuck }
}

/// How bad a symptom entry was overall, on a 1–10 scale.
public enum SymptomSeverity {
  public static let range = 1...10
  public static let severe = 8

  public static func title(_ severity: Int) -> String {
    switch severity {
    case ..<4: return "Mild"
    case ..<severe: return "Moderate"
    default: return "Severe"
    }
  }
}

/// The Bristol stool form scale, from 1 (hard lumps) to 7 (watery). 3–4 is typical.
public enum BristolScale {
  public static let range = 1...7

  public static func title(_ type: Int) -> String {
    switch type {
    case 1: return "Type 1: separate hard lumps"
    case 2: return "Type 2: lumpy and sausage-shaped"
    case 3: return "Type 3: sausage-shaped with cracks"
    case 4: return "Type 4: smooth and soft"
    case 5: return "Type 5: soft blobs with clear edges"
    case 6: return "Type 6: mushy, ragged pieces"
    case 7: return "Type 7: watery, no solid pieces"
    default: return "Type \(type)"
    }
  }
}

public struct SymptomEntry: Sendable, Equatable {
  public var time: Date
  public var symptoms: [Symptom]
  public var severity: Int

  public init(time: Date, symptoms: [Symptom], severity: Int) {
    self.time = time
    self.symptoms = symptoms
    self.severity = severity
  }
}

/// Foods that were followed by symptoms much more often than the patient's other meals.
/// A pattern to raise with the doctor or dietitian, not a diagnosis: only an elimination and
/// reintroduction under their guidance can confirm a trigger.
public enum SymptomTriggers {
  public struct Candidate: Equatable, Sendable {
    /// As the patient first logged it.
    public let name: String
    public let eaten: Int
    public let followed: Int
    /// The share of the patient's other meals followed by symptoms.
    public let otherRate: Double
    public var rate: Double { Double(followed) / Double(eaten) }
  }

  public struct Result: Equatable, Sendable {
    public let candidates: [Candidate]
    /// The share of all meals followed by symptoms.
    public let baseline: Double

    public static let empty = Result(candidates: [], baseline: 0)
  }

  /// Symptoms this long after eating count as following that food.
  public static let window: TimeInterval = 6 * 3600

  /// - Parameters:
  ///   - asOf: Meals in the last `window` before this are left out, since their symptoms may not be logged yet.
  ///   - minSeverity: Entries milder than this don't count.
  public static func analyze(meals: [(name: String, time: Date)], symptoms: [SymptomEntry], asOf: Date,
                             minSeverity: Int = 3, minEaten: Int = 3, minFollowed: Int = 3,
                             limit: Int = 3) -> Result {
    let episodes = symptoms.filter { $0.severity >= minSeverity }.map(\.time)
    let meals = meals.filter { $0.time <= asOf.addingTimeInterval(-window) }
    guard !episodes.isEmpty, !meals.isEmpty else { return Result(candidates: [], baseline: 0) }

    func isFollowed(_ t: Date) -> Bool {
      episodes.contains { $0 > t && $0 <= t.addingTimeInterval(window) }
    }
    var order: [String] = []
    var byKey: [String: (name: String, eaten: Int, followed: Int)] = [:]
    var followedTotal = 0
    for meal in meals {
      let key = meal.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      guard !key.isEmpty else { continue }
      let followed = isFollowed(meal.time)
      if followed { followedTotal += 1 }
      if byKey[key] == nil { order.append(key) }
      var entry = byKey[key] ?? (name: meal.name.trimmingCharacters(in: .whitespacesAndNewlines), eaten: 0, followed: 0)
      entry.eaten += 1
      if followed { entry.followed += 1 }
      byKey[key] = entry
    }
    let baseline = Double(followedTotal) / Double(meals.count)
    let candidates = order.compactMap { byKey[$0] }
      .map { food in
        let others = meals.count - food.eaten
        let otherRate = others == 0 ? 0 : Double(followedTotal - food.followed) / Double(others)
        return Candidate(name: food.name, eaten: food.eaten, followed: food.followed, otherRate: otherRate)
      }
      .filter { $0.eaten >= minEaten && $0.followed >= minFollowed && $0.rate >= $0.otherRate * 1.5 }
      .sorted { ($0.rate, $0.followed) > ($1.rate, $1.followed) }
    return Result(candidates: Array(candidates.prefix(limit)), baseline: baseline)
  }
}

/// Doctor-facing flag lines from a patient's recent symptom entries, like `VitalFlags`.
public enum SymptomFlags {
  public static func flags(entries: [SymptomEntry], days: Int, calendar: Calendar = .current) -> [String] {
    var out: [String] = []
    let blood = entries.filter { $0.symptoms.contains(.bloodInStool) }.count
    if blood > 0 { out.append("Blood in stool reported \(times(blood))") }
    let stuck = entries.filter { $0.symptoms.contains(.foodStuck) }.count
    if stuck > 0 { out.append("Food stuck when swallowing \(times(stuck))") }
    let severe = entries.filter { $0.severity >= SymptomSeverity.severe }.count
    if severe > 0 { out.append("Severe symptoms (\(SymptomSeverity.severe)+ of 10) \(times(severe))") }
    let symptomDays = Set(entries.map { calendar.startOfDay(for: $0.time) }).count
    if symptomDays >= 4 { out.append("Symptoms on \(symptomDays) of the last \(days) days") }
    return out
  }

  private static func times(_ n: Int) -> String { n == 1 ? "once" : "\(n) times" }
}

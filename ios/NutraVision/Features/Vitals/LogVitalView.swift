import NutraCore
import SwiftUI

/// Log one blood pressure or blood sugar reading. Readings in a dangerous range say what to do next.
struct LogVitalView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage(GlucoseUnit.storageKey) private var unit = GlucoseUnit.mgDl
    @State private var kind: VitalKind
    @State private var date = Date()
    @State private var systolic = ""
    @State private var diastolic = ""
    @State private var pulse = ""
    @State private var glucose = ""
    @State private var context = GlucoseContext.fasting
    @State private var note = ""
    @State private var saving = false
    @State private var error: String?

    init(kind: VitalKind) {
        _kind = State(initialValue: kind)
    }

    private func int(_ text: String, in range: ClosedRange<Int>) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces)).flatMap { range.contains($0) ? $0 : nil }
    }

    private var sys: Int? { int(systolic, in: 50...300) }
    private var dia: Int? { int(diastolic, in: 30...200) }
    private var pulseValue: Int? { int(pulse, in: 20...250) }
    private var pulseOK: Bool { pulse.trimmingCharacters(in: .whitespaces).isEmpty || pulseValue != nil }

    private var mgDl: Double? {
        guard let v = Double(glucose.replacingOccurrences(of: ",", with: ".")), v > 0 else { return nil }
        let mg = unit.mgDl(fromEntered: v)
        return (10...1000).contains(mg) ? mg : nil
    }

    private var canSave: Bool {
        switch kind {
        case .bloodPressure: return sys != nil && dia != nil && pulseOK
        case .glucose: return mgDl != nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Reading", selection: $kind) {
                    Text("Blood pressure").tag(VitalKind.bloodPressure)
                    Text("Blood sugar").tag(VitalKind.glucose)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                Section {
                    DatePicker("Time", selection: $date, in: ...Date())
                    switch kind {
                    case .bloodPressure:
                        number("Systolic (top)", "120", $systolic, "mmHg", label: "Systolic in millimeters of mercury")
                        number("Diastolic (bottom)", "80", $diastolic, "mmHg", label: "Diastolic in millimeters of mercury")
                        number("Pulse", "optional", $pulse, "bpm", label: "Pulse in beats per minute")
                    case .glucose:
                        HStack {
                            Text("Blood sugar")
                            Spacer()
                            TextField(unit == .mgDl ? "110" : "6.1", text: $glucose)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                                .accessibilityLabel("Blood sugar in \(unit.rawValue)")
                            Picker("Unit", selection: $unit) {
                                ForEach(GlucoseUnit.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.menu).labelsHidden()
                        }
                        Picker("When", selection: $context) {
                            ForEach(GlucoseContext.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                    }
                }

                if let advice {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            CategoryChip(title: advice.title, color: advice.color)
                            if let text = advice.text { Text(text).font(.subheadline) }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                Section("Note") {
                    TextField("Optional, e.g. after a walk", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if let error {
                    Section { Text(error).font(.footnote).foregroundStyle(Theme.bad) }
                }
            }
            .navigationTitle("Log \(kind.title.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(saving || !canSave) }
            }
        }
    }

    private func number(_ title: String, _ placeholder: String, _ text: Binding<String>, _ unit: String,
                        label: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80)
                .accessibilityLabel(label)
            Text(unit).foregroundStyle(.secondary).lineLimit(1).fixedSize().frame(minWidth: 44, alignment: .leading)
        }
    }

    /// The category of what's typed so far, and for dangerous readings what to do.
    private var advice: (title: String, color: Color, text: String?)? {
        switch kind {
        case .bloodPressure:
            guard let sys, let dia else { return nil }
            let c = BloodPressureCategory.classify(systolic: sys, diastolic: dia)
            let text: String? = c == .crisis
                ? "Wait 5 minutes and measure again. If it's still over 180/120, contact your doctor now. If you also have chest pain, shortness of breath, back pain, numbness, weakness, trouble speaking or vision changes, call 911."
                : nil
            return (c.title, c.color, text)
        case .glucose:
            guard let mgDl else { return nil }
            let c = GlucoseCategory.classify(mgDl: mgDl, context: context)
            let text: String?
            switch c {
            case .low:
                text = "Follow your care plan. For most people that's 15 g of fast-acting carbs, such as half a cup of juice, then check again in 15 minutes."
            case .veryLow:
                text = "Treat it now: 15 g of fast-acting carbs, then check again in 15 minutes. If you can't safely eat or drink, someone should give glucagon or call 911."
            case .veryHigh:
                text = "Follow your care plan. Check for ketones if you've been told to, and contact your doctor if it stays this high."
            case .inRange, .high:
                text = nil
            }
            return (c.title, c.color, text)
        }
    }

    private func save() {
        guard let userId = Backend.shared.userId, canSave else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var row = VitalLogRow(userId: userId, measuredAt: date, kind: kind)
        row.note = trimmedNote.isEmpty ? nil : String(trimmedNote.prefix(500))
        switch kind {
        case .bloodPressure:
            row.systolic = sys
            row.diastolic = dia
            row.pulse = pulseValue
        case .glucose:
            row.glucoseMgDl = mgDl.map { ($0 * 10).rounded() / 10 }
            row.glucoseContext = context
        }
        saving = true
        error = nil
        Task {
            defer { saving = false }
            do {
                try await Backend.shared.insertVital(row)
                app.vitalsVersion += 1
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

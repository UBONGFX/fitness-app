import SwiftUI

/// A numeric field bound to an optional `Double`.
///
/// Deliberately text-based rather than `TextField(value:format:)`: a formatted
/// number field accepts grouping separators, so "79" typed into "80" silently
/// becomes 7.980. Here the input is parsed explicitly and anything unparseable
/// is simply no value.
///
/// Accepts both "83,5" and "83.5" — the decimal keyboard shows whichever
/// separator the locale uses, and typing the other one should not silently fail.
struct DecimalField: View {
    /// Nothing measured here — kilograms, centimetres, percent, FFMI — is ever
    /// four digits. Rejecting them outright is simpler than explaining a typo
    /// later, and it stops a slip like "1005" from becoming a stored goal.
    static let defaultMaximum: Double = 999

    /// How many decimal places this field accepts and shows.
    ///
    /// One is right for kilograms and centimetres. A height in **metres** needs
    /// two, and with one it was not merely rounded on screen — 1,83 could not be
    /// typed at all, because the third character was rejected as it was entered.
    static let defaultFractionDigits = 1

    let label: String
    var unit: String = ""
    var identifier: String?
    var maximum: Double = DecimalField.defaultMaximum
    var fractionDigits: Int = DecimalField.defaultFractionDigits
    /// A suggested value shown greyed out instead of as real text.
    ///
    /// Prefilling the field with actual text is a trap: tapping it puts the
    /// cursor wherever you touched, so typing *inserts* into the old number
    /// rather than replacing it — "65" typed into "60" became "660". As a
    /// placeholder the suggestion is visible, saving without typing adopts it,
    /// and typing starts from empty.
    var placeholderValue: Double?
    @Binding var value: Double?

    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @ScaledMetric(relativeTo: .subheadline) private var unitWidth: CGFloat = 28


    init(
        label: String,
        unit: String = "",
        identifier: String? = nil,
        maximum: Double = DecimalField.defaultMaximum,
        fractionDigits: Int = DecimalField.defaultFractionDigits,
        placeholderValue: Double? = nil,
        value: Binding<Double?>
    ) {
        self.label = label
        self.unit = unit
        self.identifier = identifier
        self.maximum = maximum
        self.fractionDigits = fractionDigits
        self.placeholderValue = placeholderValue
        self._value = value
    }

    init(metric: BodyMetric, value: Binding<Double?>) {
        self.init(
            label: metric.displayName,
            unit: metric.unit,
            identifier: "metric-\(metric.rawValue)",
            value: value
        )
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer(minLength: Theme.Spacing.tight)
            TextField(placeholderValue.map { Self.format($0, fractionDigits: fractionDigits) } ?? "—", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
                .onChange(of: text) { _, new in
                    // Keep the longest acceptable run instead of restoring the
                    // previous text: the extra digit is dropped, everything valid
                    // before it survives, and no stale state is involved.
                    let accepted = Self.acceptablePrefix(new, maximum: maximum, fractionDigits: fractionDigits)
                    if accepted != new { text = accepted }
                    value = Self.parse(accepted)
                }
                // The label must sit on the field itself. Combining the row into
                // one element makes it unreachable for VoiceOver editing and for
                // UI tests alike.
                .accessibilityLabel(label)
                .accessibilityIdentifier(identifier ?? label)
                .focused($isFocused)

            // Correcting a value is otherwise oddly hard: this field filters out
            // characters it does not understand, and backspace is one of them,
            // so the only way to change 80 into 79 was to double-tap the number
            // to select it and hope the selection took. A clear button makes it
            // one deliberate tap.
            if isFocused, !text.isEmpty {
                Button {
                    text = ""
                    value = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label) leeren")
                .accessibilityIdentifier("clear-\(identifier ?? label)")
            }

            if !unit.isEmpty {
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: unitWidth, alignment: .leading)
            }
        }
        .onAppear {
            if let value {
                text = Self.format(value, fractionDigits: fractionDigits)
            }
        }
    }

    static func format(_ value: Double, fractionDigits: Int = DecimalField.defaultFractionDigits) -> String {
        // No grouping separator: this is an entry field, not a readout.
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...fractionDigits)))
    }

    /// Whether this text may stand in the field.
    ///
    /// Refused: anything but digits and one separator, more decimal places than
    /// `fractionDigits`, more than three integer digits, or a value above
    /// `maximum`.
    /// A trailing separator ("62,") is allowed — it is a legitimate halfway
    /// state while typing, even though it parses to no value yet.
    static func isAcceptable(
        _ input: String,
        maximum: Double = DecimalField.defaultMaximum,
        fractionDigits: Int = DecimalField.defaultFractionDigits
    ) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }

        let maximumFractionDigits = fractionDigits
        var separatorSeen = false
        var integerDigits = 0
        var fractionDigits = 0

        for character in trimmed {
            if character.isNumber {
                if separatorSeen { fractionDigits += 1 } else { integerDigits += 1 }
                continue
            }
            if character == "," || character == "." {
                if separatorSeen { return false }
                separatorSeen = true
                continue
            }
            return false
        }

        guard integerDigits <= 3, fractionDigits <= maximumFractionDigits else { return false }
        if let parsed = parse(trimmed), parsed > maximum { return false }
        return true
    }

    /// The longest acceptable run of the given text, character by character.
    ///
    /// Replaces the old "reject the edit and restore the previous text" approach,
    /// which lost a valid character when SwiftUI coalesced fast keystrokes: the
    /// "previous text" it restored was already stale, so typing "1000" could end
    /// up as "10". Building forward has no such state to go stale.
    static func acceptablePrefix(
        _ input: String,
        maximum: Double = DecimalField.defaultMaximum,
        fractionDigits: Int = DecimalField.defaultFractionDigits
    ) -> String {
        var result = ""
        for character in input {
            let candidate = result + String(character)
            if isAcceptable(candidate, maximum: maximum, fractionDigits: fractionDigits) {
                result = candidate
            }
        }
        return result
    }

    static func parse(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
}

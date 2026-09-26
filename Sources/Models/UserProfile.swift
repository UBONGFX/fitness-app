import Foundation

/// Settings that belong to the person, not to a measurement.
///
/// Height lived as a constant in `SeedData` because only the FFMI needed it.
/// That was fine until it wasn't: it is a personal value, it can be wrong, and
/// nobody could correct it without editing source. Stored in `UserDefaults`
/// rather than SwiftData — these are single scalars, not something to version or
/// relate to anything.
///
/// Note what is deliberately **not** here: no account, no e-mail, no password.
/// Nothing in this app talks to a server, so there is nothing to log in to and
/// nothing to log out of. The profile is this device's, and the export is how it
/// travels.
nonisolated enum UserProfile {
    /// A generic fallback. Local signed builds may set their own default in the
    /// generated Info.plist without committing a personal measurement.
    static var defaultHeightMeters: Double {
        let raw = Bundle.main.object(forInfoDictionaryKey: "FitnessDefaultHeightMeters")
        let value = (raw as? NSNumber)?.doubleValue
            ?? (raw as? String).flatMap(Double.init)
            ?? 1.75
        return isPlausible(value) ? value : 1.75
    }

    private enum Key {
        static let height = "bodyHeightMeters"
        static let name = "profileName"
        static let birthday = "profileBirthday"
        static let restNotifications = "wantsRestNotifications"
        static let appearance = "appearance"
    }

    /// Height in metres. Falls back to the documented default when unset or
    /// implausible, so a stray value cannot silently break every FFMI.
    static var heightMeters: Double {
        get {
            let stored = UserDefaults.standard.double(forKey: Key.height)
            return isPlausible(stored) ? stored : defaultHeightMeters
        }
        set {
            guard isPlausible(newValue) else { return }
            UserDefaults.standard.set(newValue, forKey: Key.height)
        }
    }

    /// 1.20 m to 2.30 m. Wide enough for anyone, narrow enough to catch a
    /// centimetre value typed into a metre field.
    static func isPlausible(_ value: Double) -> Bool {
        (1.20...2.30).contains(value)
    }

    /// Height in whole centimetres — the way anyone actually says it.
    ///
    /// Metres with a comma was the wrong shape for this value: it invites "1,8"
    /// where 183 was meant, and a tenth of a metre is ten centimetres of error in
    /// every FFMI. Stored in metres as before, because that is what the FFMI
    /// formula takes; only the way it is entered and shown changed.
    static var heightCentimetres: Int {
        get { Int((heightMeters * 100).rounded()) }
        set { heightMeters = Double(newValue) / 100 }
    }

    /// The range the picker offers, matching what `isPlausible` allows.
    static let centimetreRange = 120...230

    /// "183 cm"
    static var heightText: String { "\(heightCentimetres) cm" }

    static func heightText(centimetres: Int) -> String { "\(centimetres) cm" }

    // MARK: - Name

    /// Empty until someone fills it in — the app works perfectly well without a
    /// name, so it is never demanded.
    static var name: String {
        get { UserDefaults.standard.string(forKey: Key.name) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Key.name) }
    }

    /// One or two letters for the account button.
    ///
    /// Falls back to a person glyph rather than to a placeholder letter: a wrong
    /// initial looks like someone else's account.
    static var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }

    // MARK: - Birthday

    static var birthday: Date? {
        get { UserDefaults.standard.object(forKey: Key.birthday) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Key.birthday) }
    }

    /// Completed years, counted the way a birthday is: the year only turns over
    /// on the day itself, not on 1 January.
    static func age(birthday: Date?, on date: Date = Date(), calendar: Calendar = GoalPeriod.calendar) -> Int? {
        guard let birthday, birthday <= date else { return nil }
        return calendar.dateComponents([.year], from: birthday, to: date).year
    }

    static func ageText(birthday: Date?, on date: Date = Date()) -> String? {
        guard let years = age(birthday: birthday, on: date) else { return nil }
        return years == 1 ? "1 Jahr" : "\(years) Jahre"
    }

    /// Wipes every stored preference.
    ///
    /// The SwiftData store is rebuilt for each UI test, but `UserDefaults` are
    /// not — so a name typed by one test was still there for the next, and a
    /// height changed by another shifted what a third expected. Called at launch
    /// under `-uiTesting`, and by "Alle Einstellungen zurücksetzen".
    static func reset() {
        for key in [Key.height, Key.name, Key.birthday, Key.restNotifications, Key.appearance] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Appearance

    /// Light, dark, or whatever the system is doing.
    static var appearance: AppAppearance {
        get { AppAppearance(rawValue: UserDefaults.standard.string(forKey: Key.appearance) ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.appearance) }
    }

    // MARK: - Notifications

    /// Whether the pause timer may send a notification when it runs out.
    ///
    /// Defaults to on, because a pause you cannot see end is the reason the
    /// notification exists — the screen is usually off by then. This is the
    /// app's own switch and sits **on top of** the system permission: turning it
    /// off here stops the notifications without touching iOS settings.
    static var wantsRestNotifications: Bool {
        get {
            guard UserDefaults.standard.object(forKey: Key.restNotifications) != nil else { return true }
            return UserDefaults.standard.bool(forKey: Key.restNotifications)
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.restNotifications) }
    }
}

/// Which colour scheme the app forces, if any.
nonisolated enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    /// Follows iOS, which is what most people expect and what the app shipped as.
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Automatisch"
        case .light: "Hell"
        case .dark: "Dunkel"
        }
    }

    var detail: String {
        switch self {
        case .system: "Folgt der Einstellung des iPhones"
        case .light: "Immer hell, unabhängig vom iPhone"
        case .dark: "Immer dunkel, unabhängig vom iPhone"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

import SwiftUI

extension AppAppearance {
    /// `nil` means "leave it to iOS", which is what `preferredColorScheme`
    /// expects for the automatic case.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

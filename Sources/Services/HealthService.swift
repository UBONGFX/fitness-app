import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Why an import from Health cannot run right now.
nonisolated enum HealthUnavailableReason: Equatable, Sendable {
    /// No Apple Developer team, so the HealthKit entitlement is not in the build.
    case notEnabled
    /// iPad or Mac without a health store.
    case notSupportedOnDevice
    case notAuthorised

    var message: String {
        switch self {
        case .notEnabled:
            "HealthKit ist noch nicht freigeschaltet. Dafür braucht die App ein "
                + "Apple-Developer-Team, weil die Berechtigung Teil der Signierung ist."
        case .notSupportedOnDevice:
            "Dieses Gerät hat keine Health-Daten."
        case .notAuthorised:
            "Kein Zugriff auf Health. Das lässt sich in den Einstellungen unter "
                + "Datenschutz → Health ändern."
        }
    }
}

protocol HealthProviding: AnyObject, Sendable {
    var unavailableReason: HealthUnavailableReason? { get }
    func requestAuthorisation() async throws
    /// Weight and body-fat readings since a date.
    func readBodyComposition(since: Date) async throws -> [HealthSample]
    func writeWorkout(start: Date, end: Date, category: TrainingCategory) async throws
}

/// The real implementation.
///
/// Every entry point checks `unavailableReason` first, so an unsigned build
/// reports a clear cause instead of throwing an opaque HealthKit error. The
/// whole type compiles and is reachable today — only the entitlement is missing.
final class HealthKitService: HealthProviding, @unchecked Sendable {

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    var unavailableReason: HealthUnavailableReason? {
        guard AppConfig.healthKitEnabled else { return .notEnabled }
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return .notSupportedOnDevice }
        return nil
        #else
        return .notSupportedOnDevice
        #endif
    }

    func requestAuthorisation() async throws {
        if let unavailableReason { throw HealthError.unavailable(unavailableReason) }
        #if canImport(HealthKit)
        let read: Set<HKObjectType> = [
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
        ]
        let write: Set<HKSampleType> = [HKObjectType.workoutType()]
        try await store.requestAuthorization(toShare: write, read: read)
        #endif
    }

    func readBodyComposition(since date: Date) async throws -> [HealthSample] {
        if let unavailableReason { throw HealthError.unavailable(unavailableReason) }
        #if canImport(HealthKit)
        async let weights = samples(of: HKQuantityType(.bodyMass), unit: .gramUnit(with: .kilo), since: date)
        async let fats = samples(of: HKQuantityType(.bodyFatPercentage), unit: .percent(), since: date)
        let (weightSamples, fatSamples) = try await (weights, fats)

        // Both series are keyed by their own timestamps; pairing them by day is
        // left to `HealthImport`, which is where that rule is tested.
        var combined: [HealthSample] = weightSamples.map {
            HealthSample(date: $0.date, weightKg: $0.value)
        }
        combined += fatSamples.map {
            // HealthKit reports a fraction; the app works in percent.
            HealthSample(date: $0.date, bodyFatPercent: $0.value * 100)
        }
        return combined.sorted { $0.date < $1.date }
        #else
        return []
        #endif
    }

    func writeWorkout(start: Date, end: Date, category: TrainingCategory) async throws {
        if let unavailableReason { throw HealthError.unavailable(unavailableReason) }
        #if canImport(HealthKit)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = Self.activityType(for: category)
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)
        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
        #endif
    }

    #if canImport(HealthKit)
    /// Everything in this plan is resistance training; the day only says which
    /// muscles, not a different sport.
    static func activityType(for category: TrainingCategory) -> HKWorkoutActivityType {
        switch category {
        case .push, .pull, .legs: .traditionalStrengthTraining
        case .general, .rest: .other
        }
    }

    private func samples(
        of type: HKQuantityType,
        unit: HKUnit,
        since date: Date
    ) async throws -> [(date: Date, value: Double)] {
        let predicate = HKQuery.predicateForSamples(withStart: date, end: nil)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let results = try await descriptor.result(for: store)
        return results.map { (date: $0.startDate, value: $0.quantity.doubleValue(for: unit)) }
    }
    #endif

    enum HealthError: LocalizedError {
        case unavailable(HealthUnavailableReason)

        var errorDescription: String? {
            switch self {
            case .unavailable(let reason): reason.message
            }
        }
    }
}

/// Returns canned samples. Used by the tests.
final class StubHealthService: HealthProviding, @unchecked Sendable {
    var unavailableReason: HealthUnavailableReason?
    var samples: [HealthSample]
    private(set) var authorisationRequests = 0
    private(set) var writtenWorkouts: [(start: Date, end: Date, category: TrainingCategory)] = []

    init(unavailableReason: HealthUnavailableReason? = nil, samples: [HealthSample] = []) {
        self.unavailableReason = unavailableReason
        self.samples = samples
    }

    func requestAuthorisation() async throws {
        authorisationRequests += 1
    }

    func readBodyComposition(since date: Date) async throws -> [HealthSample] {
        samples.filter { $0.date >= date }
    }

    func writeWorkout(start: Date, end: Date, category: TrainingCategory) async throws {
        writtenWorkouts.append((start, end, category))
    }
}

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataView: View {
    @Query private var exercises: [Exercise]
    @Query private var plans: [WorkoutPlan]
    @Query private var allDays: [PlanDay]
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]
    @Query(sort: \BodyMeasurement.date) private var measurements: [BodyMeasurement]
    @Query private var goals: [MetricGoal]

    @Environment(\.modelContext) private var context

    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showingImporter = false
    @State private var pendingImport: (document: ExportDocument, preview: DataImport.Preview)?
    @State private var importResult: String?
    @State private var healthResult: String?

    private let healthService: HealthProviding = HealthKitService()

    /// A store holding nothing worth exporting. Seeded exercises and goals alone
    /// do not count — they are the app's own scaffolding, not the user's data.
    private var isStoreEmpty: Bool {
        measurements.isEmpty && sessions.isEmpty && plans.isEmpty
            && WorkoutLibrary.templates(in: allDays).isEmpty
    }

    private var document: ExportDocument {
        DataExport.makeDocument(
            exercises: exercises,
            plans: plans,
            workouts: WorkoutLibrary.templates(in: allDays),
            sessions: sessions,
            measurements: measurements,
            goals: goals
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: Theme.Spacing.regular) {
                    VStack(spacing: Theme.Spacing.regular) {
                        exportCard
                        importCard
                        healthCard
                        contentCard
                        if let exportError {
                            GlassCard(tint: .orange) {
                                Label(exportError, systemImage: "exclamationmark.triangle")
                                    .font(.footnote)
                            }
                        }
                    }
                    .padding(Theme.Spacing.regular)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .clearsBottomAccessory()
            .background(AppBackground())
            .navigationTitle("Daten")
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json]
            ) { result in
                loadImport(result)
            }
            .alert(
                "Import übernehmen?",
                isPresented: Binding(
                    get: { pendingImport != nil },
                    set: { if !$0 { pendingImport = nil } }
                )
            ) {
                Button("Übernehmen") { applyImport() }
                Button("Abbrechen", role: .cancel) { pendingImport = nil }
            } message: {
                // The preview is shown before anything is written — an import
                // that silently overwrites months of logs is not recoverable.
                Text(pendingImport.map { previewText($0.preview) } ?? "")
            }
        }
    }

    private var importCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                SectionHeader(
                    title: "Import",
                    subtitle: "JSON aus einem früheren Export"
                )
                Button {
                    importResult = nil
                    showingImporter = true
                } label: {
                    Label("Datei auswählen", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("chooseImport")

                if let importResult {
                    Text(importResult)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("importResult")
                }

                Text("Vorhandenes wird anhand der UUID aktualisiert, Unbekanntes ergänzt. "
                     + "Nichts wird gelöscht, was in der Datei fehlt.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// HealthKit is built but cannot run without the entitlement. Saying why,
    /// in place, beats a button that fails with an opaque error when tapped.
    private var healthCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                SectionHeader(
                    title: "Health",
                    subtitle: "Gewicht und Körperfett übernehmen, Workouts zurückschreiben"
                )
                if let reason = healthService.unavailableReason {
                    Label {
                        Text(reason.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "lock")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    .accessibilityIdentifier("healthUnavailable")
                } else {
                    Button {
                        Task { await importFromHealth() }
                    } label: {
                        Label("Aus Health übernehmen", systemImage: "heart")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("importHealth")
                }

                if let healthResult {
                    Text(healthResult)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("healthResult")
                }
            }
        }
    }

    private func importFromHealth() async {
        do {
            try await healthService.requestAuthorisation()
            let since = measurements.map(\.date).max() ?? Date(timeIntervalSince1970: 0)
            let samples = try await healthService.readBodyComposition(since: since)
            let plan = HealthImport.plan(samples: samples, existing: measurements)

            for sample in plan.creations {
                context.insert(
                    HealthImport.makeMeasurement(from: sample, heightMeters: UserProfile.heightMeters)
                )
            }
            for measurement in measurements {
                guard let update = plan.updates[measurement.id] else { continue }
                HealthImport.apply(update, to: measurement, heightMeters: UserProfile.heightMeters)
            }
            try context.save()
            healthResult = plan.summary
        } catch {
            healthResult = error.localizedDescription
        }
    }

    private func previewText(_ preview: DataImport.Preview) -> String {
        preview.isEmpty
            ? "Die Datei enthält nichts, was geändert werden müsste."
            : preview.lines.joined(separator: "\n")
    }

    private func loadImport(_ result: Result<URL, Error>) {
        exportError = nil
        do {
            let url = try result.get()
            // A file from outside the app's container needs its security scope
            // opened first, otherwise reading it fails with a permission error.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else {
                throw DataImport.LoadFailure.unreadable
            }
            let document = try DataImport.load(from: data)
            let existing = DataImport.ExistingData(
                exercises: exercises,
                measurements: measurements,
                goals: goals,
                plans: plans,
                workouts: WorkoutLibrary.templates(in: allDays),
                sessions: sessions
            )
            pendingImport = (document, DataImport.preview(document, against: existing))
        } catch {
            exportError = "Import fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func applyImport() {
        guard let pending = pendingImport else { return }
        pendingImport = nil
        do {
            try DataImportApply.apply(
                pending.document,
                exercises: exercises,
                measurements: measurements,
                goals: goals,
                plans: plans,
                workouts: WorkoutLibrary.templates(in: allDays),
                sessions: sessions,
                into: context
            )
            importResult = "Übernommen: \(pending.preview.totalNew) neu, "
                + "\(pending.preview.totalUpdated) aktualisiert."
        } catch {
            exportError = "Import fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private var exportCard: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alles als JSON")
                        .font(.title3.weight(.semibold))
                    Text(DataExport.summary(document))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("exportSummary")
                }

                if isStoreEmpty {
                    // Offering a download of an empty file would be a button that
                    // technically works and helps nobody.
                    Text("Noch nichts zu exportieren. Erfasse eine Messung oder logge ein Training.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("exportEmpty")
                } else if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Datei teilen", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("shareExport")
                    Text(exportURL.lastPathComponent)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Export erstellen", systemImage: "arrow.down.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("createExport")
                }
            }
        }
    }

    private var contentCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                SectionHeader(
                    title: "Was drin ist",
                    subtitle: "Schema-Version \(ExportDocument.currentSchemaVersion)"
                )
                row("Körpermessungen", measurements.count)
                row("Ziele", goals.count)
                row("Gespeicherte Workouts", WorkoutLibrary.templates(in: allDays).count)
                if !plans.isEmpty { row("Ältere Trainingspläne", plans.count) }
                row("Übungen", exercises.count)
                row("Einheiten", sessions.count)
                row("Geloggte Sätze", sessions.reduce(0) { $0 + $1.completedSets })

                Text("Daten und Zeitpunkte im ISO-8601-Format, jede Entität mit fester UUID — "
                     + "ein erneuter Import aktualisiert, statt zu verdoppeln.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ label: String, _ count: Int) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("\(count)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }

    /// Writes the export to a temporary file, because `ShareLink` shares a file
    /// URL with a real name — sharing raw `Data` would arrive as "Unbenannt".
    private func prepareExport() {
        exportError = nil
        do {
            let data = try DataExport.encode(document)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(DataExport.fileName())
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            exportError = "Export fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

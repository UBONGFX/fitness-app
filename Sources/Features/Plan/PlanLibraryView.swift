import SwiftData
import SwiftUI

/// Every plan you have, and which one the app follows.
///
/// The point of keeping several is switching without losing: moving to full body
/// should leave the split intact for the day you go back to it.
struct PlanLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter
    @Query private var plans: [WorkoutPlan]

    @State private var creating = false
    @State private var newName = ""
    @State private var copySource: WorkoutPlan?
    @State private var deleting: WorkoutPlan?
    @State private var renaming: WorkoutPlan?

    private var ordered: [WorkoutPlan] { PlanLibrary.ordered(plans) }

    var body: some View {
        List {
            Section {
                ForEach(Array(ordered.enumerated()), id: \.element.id) { index, plan in
                    row(plan)
                        .glassRow(.of(index, count: ordered.count))
                }
            } header: {
                Text("\(plans.count) \(plans.count == 1 ? "Plan" : "Pläne")")
            } footer: {
                Text("Nur der aktive Plan bestimmt Woche, Training und Volumen. "
                     + "Die anderen bleiben erhalten, bis du sie löschst.")
            }

            Section {
                Button("Neuen Plan anlegen", systemImage: "plus") {
                    newName = PlanLibrary.availableName("Neuer Plan", in: plans)
                    creating = true
                }
                .accessibilityIdentifier("newPlan")
                .glassRow()
            } footer: {
                Text("Ein neuer Plan startet mit sieben Ruhetagen. "
                     + "Die Tage stellst du danach einzeln ein.")
            }
        }
        .glassFormBackground()
        .navigationTitle("Pläne")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Neuer Plan", isPresented: $creating) {
            TextField("Name", text: $newName)
                .accessibilityIdentifier("newPlanName")
            Button("Anlegen") { create() }
                .accessibilityIdentifier("newPlanConfirm")
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Sieben Ruhetage, die du danach einzeln einstellst.")
        }
        .alert("Plan umbenennen", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Name", text: $newName)
                .accessibilityIdentifier("renamePlanName")
            Button("Sichern") { rename() }
                .accessibilityIdentifier("renamePlanConfirm")
            Button("Abbrechen", role: .cancel) { renaming = nil }
        }
        .confirmationDialog(
            deleting.map { "„\($0.name)" + "\" löschen?" } ?? "Plan löschen?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Plan löschen", role: .destructive) { confirmDelete() }
                .accessibilityIdentifier("confirmDeletePlan")
            Button("Behalten", role: .cancel) { deleting = nil }
        } message: {
            // Named rather than implied: the days go with it, and that is not
            // obvious from a list that shows only names.
            Text(deleting.map { "Alle \($0.sortedDays.count) Tage dieses Plans werden gelöscht. "
                 + "Deine Trainings bleiben erhalten." } ?? "")
        }
    }

    /// Three separate controls, because they do three different things: the
    /// circle switches which plan the app follows, the name opens it for editing,
    /// and the menu holds the rest. Making the whole row activate meant a plan
    /// had to be switched to before it could be built.
    private func row(_ plan: WorkoutPlan) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.tight) {
            Button {
                activate(plan)
            } label: {
                Image(systemName: plan.isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(plan.isActive ? Color.accentColor : .secondary)
                    .font(.body)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("selectPlan-\(plan.name)")
            .accessibilityLabel("\(plan.name), \(plan.summaryText)")
            .accessibilityValue(plan.isActive ? "aktiv" : "nicht aktiv")
            .accessibilityHint(plan.isActive ? "" : "Zum Aktivieren antippen")

            NavigationLink {
                PlanDetailView(plan: plan, showsThisWeek: plan.isActive)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.name)
                            .font(.subheadline.weight(plan.isActive ? .semibold : .regular))
                        Text(plan.summaryText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Theme.Spacing.tight)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("openPlan-\(plan.name)")
            .accessibilityLabel("\(plan.name) bearbeiten")

            Menu {
                Button("Umbenennen", systemImage: "pencil") {
                    newName = plan.name
                    renaming = plan
                }
                Button("Duplizieren", systemImage: "doc.on.doc") { duplicate(plan) }
                // Deleting the last plan is refused rather than hidden, so the
                // reason is visible instead of the button silently missing.
                Button("Löschen", systemImage: "trash", role: .destructive) { deleting = plan }
                    .disabled(plans.count <= 1)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 30)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Aktionen für \(plan.name)")
            .accessibilityIdentifier("planMenu-\(plan.name)")
        }
    }

    // MARK: - Actions

    private func activate(_ plan: WorkoutPlan) {
        guard !plan.isActive else { return }
        PlanLibrary.activate(plan, in: plans)
        saveReporter.perform("Plan aktivieren") { try context.save() }
    }

    private func create() {
        let name = PlanLibrary.availableName(
            newName.isEmpty ? "Neuer Plan" : newName,
            in: plans
        )
        let plan = PlanLibrary.makeEmptyPlan(name: name)
        context.insert(plan)
        saveReporter.perform("Plan anlegen") { try context.save() }
    }

    private func duplicate(_ plan: WorkoutPlan) {
        let copy = PlanLibrary.duplicate(
            plan,
            name: PlanLibrary.availableName("\(plan.name) Kopie", in: plans)
        )
        context.insert(copy)
        saveReporter.perform("Plan duplizieren") { try context.save() }
    }

    private func rename() {
        guard let renaming else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed.lowercased() != renaming.name.lowercased() {
            renaming.name = PlanLibrary.availableName(trimmed, in: plans.filter { $0.id != renaming.id })
        }
        self.renaming = nil
        saveReporter.perform("Plan umbenennen") { try context.save() }
    }

    private func confirmDelete() {
        guard let plan = deleting else { return }
        // Hand over before deleting: without an active plan the training screen
        // shows an empty week and nothing that explains why.
        if let successor = PlanLibrary.successor(after: plan, in: plans) {
            PlanLibrary.activate(successor, in: plans.filter { $0.id != plan.id })
        }
        context.delete(plan)
        deleting = nil
        saveReporter.perform("Plan löschen") { try context.save() }
    }
}

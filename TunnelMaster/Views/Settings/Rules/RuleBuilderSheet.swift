//
//  RuleBuilderSheet.swift
//  TunnelMaster
//
//  Multi-step visual rule builder with category selection.
//

import SwiftUI

struct RuleBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var step: BuilderStep = .category
    @State private var selectedCategory: RuleCategory?
    @State private var selectedRuleType: RuleType = .domain
    @State private var ruleValue = ""
    @State private var outbound: RuleOutbound = .proxy
    @State private var note = ""

    // NEW: Organization fields
    @State private var selectedGroupId: UUID?
    @State private var tags: [String] = []
    @State private var newTag = ""

    /// Sub-sheet
    @State private var activeSheet: PickerSheet?

    private let existingRule: RoutingRule?

    enum PickerSheet: Identifiable {
        case app
        case domain
        case geoSite
        case geoIP
        case ipRange
        var id: Self {
            self
        }
    }

    enum BuilderStep {
        case category
        case value
        case action
    }

    init(existingRule: RoutingRule? = nil) {
        self.existingRule = existingRule

        if let rule = existingRule {
            _selectedCategory = State(initialValue: rule.type.category)
            _selectedRuleType = State(initialValue: rule.type)
            _ruleValue = State(initialValue: rule.value)
            _outbound = State(initialValue: rule.outbound)
            _note = State(initialValue: rule.note ?? "")
            _selectedGroupId = State(initialValue: rule.groupId)
            _tags = State(initialValue: rule.tags)
            _step = State(initialValue: .value)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            stepIndicator
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 500, height: 450)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .app:
                AppPickerView { processName, type in
                    ruleValue = processName
                    selectedRuleType = type
                    step = .action
                }
            case .domain:
                DomainInputView { domain, type in
                    ruleValue = domain
                    selectedRuleType = type
                    step = .action
                }
            case .geoSite:
                GeoSiteBrowserView { category in
                    ruleValue = category
                    selectedRuleType = .geosite
                    step = .action
                }
            case .geoIP:
                GeoIPBrowserView { country in
                    ruleValue = country
                    selectedRuleType = .geoip
                    step = .action
                }
            case .ipRange:
                IPRangeInputView { cidr in
                    ruleValue = cidr
                    selectedRuleType = .ipCidr
                    step = .action
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if step != .category {
                Button {
                    withAnimation {
                        goBack()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
            }

            Text(existingRule == nil ? "Add Routing Rule" : "Edit Routing Rule")
                .font(.headline)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            stepDot(step: .category, label: "Type", current: step)
            stepLine(active: step != .category)
            stepDot(step: .value, label: "Value", current: step)
            stepLine(active: step == .action)
            stepDot(step: .action, label: "Action", current: step)
        }
        .padding()
    }

    private func stepDot(step: BuilderStep, label: String, current: BuilderStep) -> some View {
        let isActive = stepOrder(step) <= stepOrder(current)
        let isCurrent = step == current

        return VStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: isCurrent ? 12 : 10, height: isCurrent ? 12 : 10)
            Text(label)
                .font(.caption2)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
    }

    private func stepLine(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.blue : Color.gray.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: 60)
    }

    private func stepOrder(_ step: BuilderStep) -> Int {
        switch step {
        case .category: 0
        case .value: 1
        case .action: 2
        }
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        switch step {
        case .category:
            categorySelection
        case .value:
            valueInput
        case .action:
            actionSelection
        }
    }

    // MARK: - Category Selection

    private var categorySelection: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                ForEach(RuleCategory.allCases) { category in
                    categoryCard(category)
                }
            }
            .padding()
        }
    }

    private func categoryCard(_ category: RuleCategory) -> some View {
        Button {
            selectedCategory = category
            if category.ruleTypes.count == 1 {
                selectedRuleType = category.ruleTypes[0]
            }
            withAnimation {
                openValueInput(for: category)
            }
        } label: {
            VStack(spacing: 12) {
                Image(systemName: category.systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(colorForCategory(category))

                VStack(spacing: 4) {
                    Text(category.displayName)
                        .font(.headline)
                    Text(category.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedCategory == category ? colorForCategory(category).opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedCategory == category ? colorForCategory(category) : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func colorForCategory(_ category: RuleCategory) -> Color {
        switch category {
        case .app: .gray
        case .domain: .purple
        case .ip: .orange
        case .geoSite: .teal
        case .geoIP: .teal
        }
    }

    private func openValueInput(for category: RuleCategory) {
        switch category {
        case .app:
            activeSheet = .app
        case .domain:
            activeSheet = .domain
        case .geoSite:
            activeSheet = .geoSite
        case .geoIP:
            activeSheet = .geoIP
        case .ip:
            activeSheet = .ipRange
        }
    }

    // MARK: - Value Input (fallback for editing)

    private var valueInput: some View {
        VStack(spacing: 16) {
            // Category indicator
            if let category = selectedCategory {
                HStack {
                    Image(systemName: category.systemImage)
                        .foregroundStyle(colorForCategory(category))
                    Text(category.displayName)
                        .font(.headline)
                }
                .padding(.top)
            }

            // Rule type picker (if multiple types in category)
            if let category = selectedCategory, category.ruleTypes.count > 1 {
                Picker("Type", selection: $selectedRuleType) {
                    ForEach(category.ruleTypes, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            // Value input
            VStack(alignment: .leading, spacing: 8) {
                Text("Value")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(selectedRuleType.placeholder, text: $ruleValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())

                Text(ruleTypeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Visual picker button
            if let category = selectedCategory {
                Button {
                    openValueInput(for: category)
                } label: {
                    Label("Use Visual Picker", systemImage: "rectangle.and.hand.point.up.left")
                }
                .buttonStyle(.link)
            }

            Spacer()
        }
    }

    private var ruleTypeDescription: String {
        switch selectedRuleType {
        case .processName:
            "Match traffic from apps by process name (e.g., 'Safari')"
        case .processPath:
            "Match traffic from apps by full executable path"
        case .domain:
            "Match exact domain name only"
        case .domainSuffix:
            "Match domain and all its subdomains"
        case .domainKeyword:
            "Match any domain containing this keyword"
        case .ipCidr:
            "Match IP addresses in this CIDR range"
        case .geoip:
            "Match traffic to this country (requires geoip.db)"
        case .geosite:
            "Match traffic to this site category (requires geosite.db)"
        }
    }

    // MARK: - Action Selection

    private var actionSelection: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: selectedRuleType.systemImage)
                            .foregroundStyle(colorForCategory(selectedCategory ?? .domain))
                        Text(selectedRuleType.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(ruleValue)
                        .font(.headline)
                        .fontDesign(.monospaced)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top)

                // Action picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Route To")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        ForEach(RuleOutbound.allCases) { action in
                            actionButton(action)
                        }
                    }
                }
                .padding(.horizontal)

                // Organization
                VStack(alignment: .leading, spacing: 8) {
                    Text("Organization")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Group picker
                    Picker("Group", selection: $selectedGroupId) {
                        Text("Ungrouped").tag(UUID?.none)
                        if !appState.tunnelConfig.groups.isEmpty {
                            Divider()
                            ForEach(appState.tunnelConfig.sortedGroups) { group in
                                Label {
                                    Text(group.name)
                                } icon: {
                                    Image(systemName: group.icon)
                                }
                                .tag(UUID?.some(group.id))
                            }
                        }
                    }

                    // Tag input
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Add tag", text: $newTag)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    addTag()
                                }

                            Button("Add") {
                                addTag()
                            }
                            .disabled(newTag.isEmpty)
                        }

                        // Tag chips
                        if !tags.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    TagChip(tag: tag, onRemove: {
                                        tags.removeAll { $0 == tag }
                                    })
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Note field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Add a note to remember why...", text: $note)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                // Conflict warning
                if let conflict = potentialConflict {
                    conflictWarning(conflict)
                        .padding(.horizontal)
                }

                Spacer()
            }
        }
    }

    // MARK: - Tag Management

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, !tags.contains(trimmed) {
            tags.append(trimmed)
            newTag = ""
        }
    }

    // MARK: - Conflict Detection

    private var potentialConflict: RuleConflictDetector.Conflict? {
        guard step == .action, !ruleValue.isEmpty else { return nil }

        let tempRule = RoutingRule(
            type: selectedRuleType,
            value: ruleValue,
            outbound: outbound,
            isEnabled: true
        )

        // Exclude the rule being edited
        let rulesToCheck = appState.tunnelConfig.rules.filter {
            $0.id != existingRule?.id
        }

        return RuleConflictDetector.detectConflictForNewRule(tempRule, in: rulesToCheck)
    }

    private func conflictWarning(_ conflict: RuleConflictDetector.Conflict) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: conflict.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(conflict.severity == .error ? .red : .orange)
                Text(conflict.explanation)
                    .font(.caption)
            }
            Text(conflict.suggestion)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(conflict.severity == .error ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func actionButton(_ action: RuleOutbound) -> some View {
        Button {
            outbound = action
        } label: {
            VStack(spacing: 8) {
                Image(systemName: action.systemImage)
                    .font(.title2)
                Text(action.displayName)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(outbound == action ? actionColor(action).opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundStyle(outbound == action ? actionColor(action) : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(outbound == action ? actionColor(action) : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func actionColor(_ action: RuleOutbound) -> Color {
        switch action {
        case .direct: .green
        case .proxy: .blue
        case .block: .red
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if step == .action {
                Button("Save Rule") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            } else if step == .value {
                Button("Next") {
                    withAnimation {
                        step = .action
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(ruleValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !ruleValue.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func goBack() {
        switch step {
        case .category:
            break
        case .value:
            step = .category
        case .action:
            step = .value
        }
    }

    private func save() {
        let rule = RoutingRule(
            id: existingRule?.id ?? UUID(),
            type: selectedRuleType,
            value: ruleValue.trimmingCharacters(in: .whitespaces),
            outbound: outbound,
            isEnabled: existingRule?.isEnabled ?? true,
            note: note.isEmpty ? nil : note,
            groupId: selectedGroupId,
            tags: tags,
            createdAt: existingRule?.createdAt ?? Date(),
            lastModified: Date()
        )

        // Sheet now owns the save action
        if let existing = existingRule {
            // Edit existing rule
            if let index = appState.tunnelConfig.rules.firstIndex(where: { $0.id == existing.id }) {
                appState.tunnelConfig.rules[index] = rule
            } else {
                // Rule was deleted while sheet was open - treat as create
                appState.tunnelConfig.rules.append(rule)
            }
        } else {
            // Create new rule
            appState.tunnelConfig.rules.append(rule)
        }

        dismiss()
    }
}

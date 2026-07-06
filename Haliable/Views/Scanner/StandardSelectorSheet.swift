//
//  StandardSelectorSheet.swift
//  Haliable
//
//  The medium-detent bottom sheet for picking a halal standard. One clean
//  single-select list; each option is a card with a one-liner and an expandable
//  "what this means". Selecting springs, taps a haptic, updates the bound value
//  immediately, and dismisses. Doubles as the first-run "how strict?" chooser.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct StandardSelectorSheet: View {
    /// Bound to AppSettings.halalStandard — the single source of truth.
    @Binding var selected: HalalStandard
    /// First-run framing + a "decide later" escape hatch.
    var isFirstRun: Bool = false
    /// Called when the user commits a choice (parent marks `hasChosenStandard`).
    var onCommit: (HalalStandard) -> Void
    /// Called when the user taps "Decide later" (keeps the default).
    var onDecideLater: () -> Void = {}

    @State private var expanded: Set<HalalStandard> = []
    @State private var showInfo = false
    @Environment(\.dismiss) private var dismiss

    /// Strictest first, so the list reads strict → lenient.
    private var ordered: [HalalStandard] {
        HalalStandard.allCases.sorted { $0.strictnessRank > $1.strictnessRank }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.md) {
                    if isFirstRun { firstRunHeader }
                    ForEach(ordered) { card($0) }
                }
                .padding(DSSpacing.md)
            }
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .navigationTitle(isFirstRun ? "How strict should we be?" : "Halal Standard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showInfo = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("Learn about halal standards")
                }
                if isFirstRun {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Decide later") { onDecideLater(); dismiss() }
                    }
                }
            }
            .sheet(isPresented: $showInfo) {
                NavigationStack { HalalStandardEducationView() }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var firstRunHeader: some View {
        VStack(spacing: DSSpacing.xs) {
            Text("Pick the position you follow. You can change it any time — from here or in Settings — and every scan uses it consistently.")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
            Text("Default: General Halal")
                .font(DSFont.caption.weight(.semibold))
                .foregroundStyle(DSColor.accent)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, DSSpacing.xs)
    }

    private func card(_ std: HalalStandard) -> some View {
        let isSelected = std == selected
        let isExpanded = expanded.contains(std)

        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Button { select(std) } label: {
                HStack(alignment: .top, spacing: DSSpacing.sm) {
                    Image(systemName: std.symbol)
                        .font(.headline)
                        .foregroundStyle(DSColor.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        Text(std.displayName)
                            .font(DSFont.headline)
                            .foregroundStyle(DSColor.textPrimary)
                        Text(std.shortDescription)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: DSSpacing.xs)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? DSColor.accent : DSColor.textSecondary)
                        .symbolEffect(.bounce, value: isSelected)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(std.displayName). \(std.shortDescription)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityHint("Double-tap to choose this standard")

            Button {
                withAnimation(.easeInOut(duration: 0.22)) { toggleExpanded(std) }
            } label: {
                HStack(spacing: DSSpacing.xxs) {
                    Text(isExpanded ? "Hide details" : "What this means")
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .font(DSFont.caption.weight(.semibold))
                .foregroundStyle(DSColor.accent)
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Collapses the explanation" : "Expands a plain-language explanation")

            if isExpanded {
                Text(std.whatThisMeans)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DSSpacing.md)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .strokeBorder(isSelected ? DSColor.accent : DSColor.outline,
                              lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected ? DSColor.accent.opacity(0.25) : .clear, radius: 10)
    }

    private func toggleExpanded(_ std: HalalStandard) {
        if expanded.contains(std) { expanded.remove(std) } else { expanded.insert(std) }
    }

    private func select(_ std: HalalStandard) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selected = std
        }
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
        onCommit(std)
        // Let the spring + checkmark land before the sheet slides away.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dismiss() }
    }
}

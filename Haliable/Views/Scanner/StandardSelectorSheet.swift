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
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                header
                ForEach(ordered) { card($0) }
                if isFirstRun {
                    Button("Decide later — keep General Halal") { onDecideLater(); dismiss() }
                        .font(DSFont.caption.weight(.semibold))
                        .foregroundStyle(DSColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, DSSpacing.xs)
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.top, DSSpacing.lg)
            .padding(.bottom, DSSpacing.lg)
        }
        .background(DSColor.surface)
        .sheet(isPresented: $showInfo) {
            NavigationStack { HalalStandardEducationView() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .presentationBackground(DSColor.surface)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isFirstRun ? "How strict should we be?" : "Which standard?")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(DSColor.textPrimary)
                Text("Haliable reports what scholars ruled. Stricter settings flag more.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer(minLength: DSSpacing.sm)
            Button { showInfo = true } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DSColor.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(DSColor.surfaceElevated, in: Circle())
                    .overlay(Circle().strokeBorder(DSColor.outlineStrong, lineWidth: 1))
            }
            .pressable()
            .accessibilityLabel("Learn about halal standards")
        }
        .padding(.bottom, DSSpacing.xs)
    }

    private func card(_ std: HalalStandard) -> some View {
        let isSelected = std == selected
        let isExpanded = expanded.contains(std)
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Button { select(std) } label: {
                HStack(alignment: .top, spacing: DSSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(std.displayName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(DSColor.textPrimary)
                            if std == .fallback {
                                Text("· DEFAULT")
                                    .font(.system(size: 9, weight: .heavy))
                                    .tracking(1)
                                    .foregroundStyle(DSColor.textTertiary)
                            }
                        }
                        Text(std.shortDescription)
                            .font(.system(size: 12))
                            .foregroundStyle(DSColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    tick(isSelected)
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
                withAnimation(DSMotion.move) { toggleExpanded(std) }
            } label: {
                HStack(spacing: DSSpacing.xxs) {
                    Text(isExpanded ? "Hide details" : "What this means")
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(DSColor.accent)
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Collapses the explanation" : "Expands a plain-language explanation")

            if isExpanded {
                Text(std.whatThisMeans)
                    .font(.system(size: 12.5))
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DSSpacing.sm)
        .background {
            if isSelected {
                shape.fill(LinearGradient(colors: [DSColor.accent.opacity(0.18), DSColor.accentGradientEnd.opacity(0.12)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            } else {
                shape.fill(DSColor.surfaceElevated)
            }
        }
        .overlay(shape.strokeBorder(isSelected ? DSColor.accent : DSColor.outline,
                                    lineWidth: isSelected ? 1.5 : 1))
        .animation(DSMotion.move, value: isSelected)
    }

    private func tick(_ on: Bool) -> some View {
        ZStack {
            if on {
                Circle().fill(LinearGradient(colors: [DSColor.accent, DSColor.accentGradientEnd],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle().strokeBorder(DSColor.outlineStrong, lineWidth: 1.5)
            }
        }
        .frame(width: 22, height: 22)
        .padding(.top, 2)
        .accessibilityHidden(true)
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

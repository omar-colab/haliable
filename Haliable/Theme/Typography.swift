//
//  Typography.swift
//  Haliable
//
//  The type scale for the "Editorial Refined" (v4) language. Three voices:
//
//    • SERIF (display) — Spectral (Production Type). Screen titles, card/row
//      headers, the wordmark "Ha", numerals, the verdict reveal. Weights bundled:
//      Light / Regular / Medium (the design leans on Medium ≈ 500).
//    • EDITORIAL ITALIC — Instrument Serif Italic (Instrument). The flowing accent
//      on "liable", the green "Halal" tail, taglines, the safety stance, the streak
//      line.
//    • SANS (UI) — San Francisco (SF Pro Display). Body, eyebrows, section labels,
//      buttons, metadata.
//
//  Both serifs are SIL Open Font License 1.1 and therefore shippable. They replaced
//  Romie Trial and Ernest Trial, which were evaluation-only licences (Oct 2026).
//  Everything funnels through this one file.
//
//  Font files live in Resources/Fonts and are registered via Info.plist
//  (UIAppFonts). Role tokens use `relativeTo:` so they scale with Dynamic Type.
//

import SwiftUI

enum DSFont {

    // MARK: Font family PostScript names
    private static let serifLight   = "Spectral-Light"
    private static let serifRegular = "Spectral-Regular"
    private static let serifMedium  = "Spectral-Medium"
    private static let ed           = "InstrumentSerif-Italic"

    // MARK: Serif — the editorial display voice (Spectral)

    /// Screen-defining headers ("Find", "History"). Large editorial serif.
    static let display  = Font.custom(serifMedium, size: 36, relativeTo: .largeTitle)
    /// Section / card titles a step down from the hero.
    static let title    = Font.custom(serifMedium, size: 23, relativeTo: .title2)
    /// Row headers, card titles, place/product names — the serif "h4".
    static let headline = Font.custom(serifMedium, size: 18, relativeTo: .headline)

    // MARK: Sans — the UI voice (San Francisco / SF Pro Display)

    /// Default running text.
    static let body     = Font.system(.body,    design: .default)
    /// Captions, metadata, timestamps.
    static let caption  = Font.system(.caption, design: .default, weight: .medium)
    /// Eyebrows + section labels — small, heavy, tracked uppercase.
    static let label    = Font.system(.caption, design: .default, weight: .bold)
    /// Button / primary-action text.
    static let button   = Font.system(.callout, design: .default, weight: .semibold)

    // MARK: Editorial italic accent (Instrument Serif)

    /// The italic serif accent — taglines, the verdict subtitle, the streak line,
    /// the green "em" phrases. Pair with `DSColor.accentDeep`.
    static func editorial(_ style: Font.TextStyle = .title3) -> Font {
        Font.custom(ed, size: editorialSize(style), relativeTo: style)
    }
    /// Editorial italic at the display size — the green accent tail on a screen
    /// title ("Find · Halal") and the "liable" of the wordmark.
    static let displayAccent = Font.custom(ed, size: 36, relativeTo: .largeTitle)

    private static func editorialSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title:      return 26
        case .title2:     return 22
        case .title3:     return 20
        case .headline, .body: return 17
        case .callout:    return 16
        case .subheadline: return 15
        case .footnote:   return 13
        default:          return 17
        }
    }

    // MARK: Serif at an explicit size (numerals, the streak "12", verdict title)

    /// Fixed-size serif for bespoke figures. Weight picks the bundled Spectral cut.
    static func serif(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let name: String
        switch weight {
        case .ultraLight, .thin, .light: name = serifLight
        case .regular:                   name = serifRegular
        default:                         name = serifMedium   // medium/semibold/bold…
        }
        return Font.custom(name, fixedSize: size)
    }

    // MARK: Brand wordmark — "Ha" Spectral + "liable" Instrument Serif italic

    /// The "Ha" half of the wordmark: Spectral serif medium.
    static func wordmark(_ size: CGFloat = 27) -> Font {
        Font.custom(serifMedium, fixedSize: size)
    }
    /// The "liable" half: Instrument Serif italic — rendered in `DSColor.accentDeep`.
    static func wordmarkAccent(_ size: CGFloat = 27) -> Font {
        Font.custom(ed, fixedSize: size)
    }
}

extension View {
    /// Sugar so views read `.dsFont(.headline)` alongside the color tokens.
    func dsFont(_ font: Font) -> some View { self.font(font) }
}

// MARK: - Editorial runs (mixed serif + italic on one baseline)

// A line that mixes the display serif with the editorial italic — "Ha" + "liable",
// "Find " + "Halal" — has to share one baseline and wrap as one block, which two
// adjacent SwiftUI `Text`s won't do. Build the line as `[EditorialRun]` and hand it
// to `ObliqueText`, which lays it out in a single `UILabel`.
//
// `obliqueness` now defaults to 0: Instrument Serif ships a real italic face, so no
// synthetic shear is needed. (It was 0.2 when the accent was Ernest Trial, an
// upright-only cut. The knob stays for any future upright-only accent face.)

#if canImport(UIKit)
import UIKit

/// One styled span of editorial text.
struct EditorialRun {
    let text: String
    var italic: Bool = false
    var size: CGFloat = 17
    /// Asset-catalog color token name (e.g. "AccentDeep").
    var color: String = "TextPrimary"
    /// Spectral weight PostScript name for the upright (non-italic) runs.
    var serif: String = "Spectral-Medium"

    static func serif(_ t: String, size: CGFloat, color: String = "TextPrimary",
                      ps: String = "Spectral-Medium") -> EditorialRun {
        EditorialRun(text: t, italic: false, size: size, color: color, serif: ps)
    }
    static func italic(_ t: String, size: CGFloat, color: String = "TextPrimary") -> EditorialRun {
        EditorialRun(text: t, italic: true, size: size, color: color)
    }
}

/// Renders editorial runs through a single `UILabel` so mixed serif/italic spans
/// share a baseline and wrap correctly across lines.
struct ObliqueText: View {
    let runs: [EditorialRun]
    var alignment: NSTextAlignment = .natural
    var lineSpacing: CGFloat = 2
    /// Synthetic forward shear for italic runs (≈ tan of the slant angle). 0 for a
    /// face that already has a real italic, as Instrument Serif does.
    var obliqueness: CGFloat = 0

    var body: some View {
        _ObliqueLabel(string: attributed, alignment: alignment)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(runs.map(\.text).joined())
    }

    private var attributed: NSAttributedString {
        let out = NSMutableAttributedString()
        let para = NSMutableParagraphStyle()
        para.alignment = alignment
        para.lineSpacing = lineSpacing
        for run in runs {
            let font: UIFont = run.italic
                ? (UIFont(name: "InstrumentSerif-Italic", size: run.size) ?? .systemFont(ofSize: run.size))
                : (UIFont(name: run.serif, size: run.size) ?? .systemFont(ofSize: run.size))
            var attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(named: run.color) ?? .label,
                .paragraphStyle: para,
            ]
            if run.italic { attrs[.obliqueness] = obliqueness }
            out.append(NSAttributedString(string: run.text, attributes: attrs))
        }
        return out
    }
}

private struct _ObliqueLabel: UIViewRepresentable {
    let string: NSAttributedString
    let alignment: NSTextAlignment

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.backgroundColor = .clear
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = string
        label.textAlignment = alignment
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? UIView.layoutFittingExpandedSize.width
        uiView.preferredMaxLayoutWidth = width
        let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: min(fit.width, width), height: fit.height)
    }
}
#endif

//
//  SatisfactionClaim.swift
//  Haliable
//
//  Puts the certifier "meets your standard?" badge behind the SAME citation gate
//  as a grade cell, so the whole verdict surface obeys one rule (REPORT, DON'T
//  RULE). A `CertificationBody → HalalStandard` satisfaction claim may present as
//  a confident "meets your standard" ONLY when backed by ≥1 tier-1/2 well-formed
//  citation (the body's own recognition / accreditation document). Uncited
//  positive claims are pending, never confident.
//
//  Citations are data: they come from the `certifiers` section of Citations.json
//  via `CitationStore`. Ships empty → every positive claim is pending until cited.
//

import Foundation

/// A single body→standard satisfaction claim + the citations backing it.
struct SatisfactionClaim: Hashable {
    let body: CertificationBody
    let standard: HalalStandard
    /// The draft mapping's "yes, this body satisfies this position".
    let draftSatisfies: Bool
    let citations: [Citation]

    /// Citations strong enough to back the claim: tier 1/2 AND well-formed (§8).
    var clearingCitations: [Citation] { citations.filter { $0.clears } }

    /// At least one citation backs the claim.
    var isCited: Bool { !clearingCitations.isEmpty }

    /// A POSITIVE satisfaction claim that isn't yet cited → pending, not confident.
    /// (A negative claim — body doesn't meet the standard — is the conservative
    /// direction and needs no citation, just like a non-halal grade.)
    var needsReview: Bool { draftSatisfies && !isCited }

    /// May the badge / overlay present a confident "meets your standard"? Only
    /// when the draft says it satisfies AND that claim is cited.
    var isClearedSatisfaction: Bool { draftSatisfies && isCited }

    /// Build a claim by pulling the body's draft mapping + any citations on file.
    static func make(body: CertificationBody, standard: HalalStandard) -> SatisfactionClaim {
        SatisfactionClaim(
            body: body,
            standard: standard,
            draftSatisfies: body.confidentlySatisfies.contains(standard),
            citations: CitationStore.shared.citations(body: body.rawValue, position: standard.rawValue)
        )
    }
}

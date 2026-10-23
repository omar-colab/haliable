//
//  LabelTextReader.swift
//  Haliable
//
//  Reads an ingredients list off a label photo with Apple's on-device Vision
//  text recognition, for products neither USDA nor Open Food Facts knows.
//  Nothing leaves the phone. The text it returns is only a draft: the person
//  checks it against the pack before Haliable grades it (LabelScanView).
//

import UIKit
import Vision

enum LabelTextReader {
    enum ReadError: LocalizedError {
        case noText
        var errorDescription: String? { "Couldn't read any text. Retake the photo closer, in good light." }
    }

    /// All recognised text, top to bottom, one line per text line.
    static func read(_ image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { throw ReadError.noText }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        // Recognition is slow (~0.5 s); keep it off the main thread.
        let lines = try await Task.detached(priority: .userInitiated) { () -> [String] in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([request])
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        }.value
        let text = lines.joined(separator: "\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ReadError.noText }
        return ingredientsSection(of: text)
    }

    /// Labels carry nutrition panels, addresses and marketing too. Keep the text
    /// from the word "ingredients" on, when the photo has it; otherwise all of it.
    /// Lines are joined into one statement, as USDA/OFF give it.
    static func ingredientsSection(of text: String) -> String {
        var body = text
        if let r = body.range(of: "ingredients", options: .caseInsensitive) { body = String(body[r.lowerBound...]) }
        return body.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Too little text to stand for a whole ingredients list → ask for a retake
    /// rather than grade a fragment (a fragment can miss the one ingredient
    /// that matters).
    static func looksLikeAnIngredientList(_ text: String) -> Bool {
        let letters = text.filter(\.isLetter).count
        let items = text.split(whereSeparator: { ",;".contains($0) }).count
        return letters >= 20 && items >= 2
    }
}

private extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

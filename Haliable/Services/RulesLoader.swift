//
//  RulesLoader.swift
//  Haliable
//
//  Created by Omar O on 5/27/26.
//

import Foundation

// An error type for the two ways loading can fail.
enum RulesLoaderError: Error {
    case fileMissing
    case decodeFailed(Error)
}

// RulesLoader's job: read the bundled JSON files and turn them into Swift types.
struct RulesLoader {

    // 'static' means you call this as RulesLoader.loadRules() —
    // no need to create a RulesLoader instance first.
    // 'throws' means this function can fail and will hand the error
    // back to whoever called it, instead of crashing.
    static func loadRules() throws -> [IngredientRule] {
        // Bundle.main is your app's own package of files.
        // We ask it for the file named "rules-v1.json".
        guard let url = Bundle.main.url(forResource: "rules-v1", withExtension: "json") else {
            throw RulesLoaderError.fileMissing   // file isn't there → fail clearly
        }

        let data = try Data(contentsOf: url)     // read the raw bytes

        // Try to turn the JSON bytes into an array of IngredientRule.
        do {
            return try JSONDecoder().decode([IngredientRule].self, from: data)
        } catch {
            // If the JSON shape doesn't match our structs, wrap the error
            // so the caller knows decoding specifically was the problem.
            throw RulesLoaderError.decodeFailed(error)
        }
    }

    // Same pattern for the E-number lookup file.
    // [String: String] is a dictionary — exactly what you practiced on Day 3.
    static func loadENumbers() throws -> [String: String] {
        guard let url = Bundle.main.url(forResource: "e-numbers", withExtension: "json") else {
            throw RulesLoaderError.fileMissing
        }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            throw RulesLoaderError.decodeFailed(error)
        }
    }
}

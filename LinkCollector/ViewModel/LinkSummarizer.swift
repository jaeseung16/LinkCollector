//
//  LinkSummarizer.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 9/4/26.
//

import Foundation
import FoundationModels
import os

actor LinkSummarizer {
    // A session holds SystemLanguageModel.contextSize tokens - 4096 on the current on-device model -
    // and instructions, prompt and response all draw from it, so the page text has to be budgeted.
    private static let responseTokenBudget = 300
    private static let overheadTokenBudget = 250
    // A token is three to four characters in Latin scripts but about one character in Chinese,
    // Japanese and Korean, so the token budget is converted to characters per page.
    private static let charactersPerTokenLatin = 3
    private static let charactersPerTokenDense = 1
    private static let denseScriptRatio = 0.2
    private static let denseScriptSampleLength = 2000
    private static let denseScriptRanges: [ClosedRange<UInt32>] = [
        0x1100...0x11FF,    // Hangul Jamo
        0x3040...0x30FF,    // Hiragana and Katakana
        0x3400...0x4DBF,    // CJK Unified Ideographs Extension A
        0x4E00...0x9FFF,    // CJK Unified Ideographs
        0xAC00...0xD7A3     // Hangul syllables
    ]
    // Each chunk costs one model call, so the cap bounds how long summarizing a single link can take.
    // Anything past the last chunk is dropped.
    private static let maximumChunkCount = 4
    private static let minimumCharacterBudget = 500
    
    // "Reply with ... and nothing else" earns its keep: without it the model tends to answer with a
    // preamble and a bullet list long enough to run into responseTokenBudget and be cut off mid-word.
    private static let pageInstructions = """
        Summarize this web page for someone who saved the link and wants to recall what it covers. \
        Use only what the text says. Reply with at most three sentences and nothing else: no \
        preamble, no heading, no bullet list, no code.
        """
    private static let sectionInstructions = """
        Summarize one section of a longer web page for someone who saved the link and wants to \
        recall what it covers. Use only what the section says. Reply with at most three sentences \
        and nothing else: no preamble, no heading, no bullet list, no code.
        """
    private static let combineInstructions = """
        Merge these summaries of the sections of one web page into a single summary. State each \
        point once and drop whatever the sections repeat. Reply with at most three sentences and \
        nothing else: no preamble, no heading, no bullet list, no code.
        """
    
    private let logger = Logger()
    private let model = SystemLanguageModel.default
    
    var availability: SystemLanguageModel.Availability {
        model.availability
    }
    
    func summarize(text: String) async throws -> String {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !content.isEmpty else {
            throw LinkSummarizerError.noContent
        }
        
        if case .unavailable(let reason) = model.availability {
            logger.log("The system language model is unavailable: \(String(describing: reason), privacy: .public)")
            throw LinkSummarizerError.unavailable(reason)
        }
        
        let chunks = split(content)
        
        guard let onlyChunk = chunks.first else {
            throw LinkSummarizerError.noContent
        }
        
        if chunks.count == 1 {
            do {
                return try await summarize(chunk: onlyChunk, instructions: LinkSummarizer.pageInstructions)
            } catch let error as LanguageModelSession.GenerationError {
                throw LinkSummarizerError.generationFailed(error)
            }
        }
        
        logger.log("Summarizing \(chunks.count, privacy: .public) chunks of \(content.count, privacy: .public) characters")
        
        var sectionSummaries = [String]()
        var failure: LanguageModelSession.GenerationError?
        
        for chunk in chunks {
            do {
                sectionSummaries.append(try await summarize(chunk: chunk, instructions: LinkSummarizer.sectionInstructions))
            } catch let error as LanguageModelSession.GenerationError {
                // A chunk the model won't touch - leftover boilerplate, a block of another language -
                // shouldn't cost the summary of the rest of the page.
                logger.log("Skipping a chunk: \(error.localizedDescription, privacy: .public)")
                failure = error
            }
        }
        
        guard let firstSummary = sectionSummaries.first else {
            throw failure.map { LinkSummarizerError.generationFailed($0) } ?? LinkSummarizerError.noContent
        }
        
        guard sectionSummaries.count > 1 else {
            return firstSummary
        }
        
        do {
            return try await summarize(chunk: sectionSummaries.joined(separator: "\n\n"),
                                       instructions: LinkSummarizer.combineInstructions)
        } catch let error as LanguageModelSession.GenerationError {
            throw LinkSummarizerError.generationFailed(error)
        }
    }
    
    // Every call gets its own session: a session accumulates each prompt and response in its
    // transcript, so reusing one across chunks would spend the context window on earlier chunks.
    private func summarize(chunk: String, instructions: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(maximumResponseTokens: LinkSummarizer.responseTokenBudget)
        
        do {
            let response = try await session.respond(to: chunk, options: options)
            return LinkSummarizer.cleaned(response.content)
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize(let context) {
            // The character budget is an estimate of how the page tokenizes. When it turns out to
            // have been too generous, halve the prompt and try again instead of giving up.
            logger.log("Exceeded the context window: \(context.debugDescription, privacy: .public)")
            
            guard chunk.count > LinkSummarizer.minimumCharacterBudget else {
                throw LanguageModelSession.GenerationError.exceededContextWindowSize(context)
            }
            
            return try await summarize(chunk: String(chunk.prefix(chunk.count / 2)), instructions: instructions)
        }
    }
    
    // The instructions ask for the summary alone, and mostly get it. When the model leads with a
    // "Here is a summary:" line anyway, drop it rather than store it.
    private static func cleaned(_ summary: String) -> String {
        let lines = summary
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard let first = lines.first else {
            return ""
        }
        
        let body = (lines.count > 1 && first.hasSuffix(":")) ? Array(lines.dropFirst()) : lines
        return body.joined(separator: " ")
    }
    
    private func split(_ text: String) -> [String] {
        let budget = characterBudget(for: text)
        
        var chunks = [String]()
        var remainder = Substring(text)
        
        while !remainder.isEmpty && chunks.count < LinkSummarizer.maximumChunkCount {
            guard remainder.count > budget else {
                chunks.append(String(remainder))
                break
            }
            
            let limit = remainder.index(remainder.startIndex, offsetBy: budget)
            // Break on whitespace so a chunk doesn't end mid-word. Scripts written without spaces
            // have none to break on, and a break at the very start would make no progress at all.
            let whitespace = remainder[..<limit].lastIndex(where: { $0.isWhitespace })
            let boundary = (whitespace != nil && whitespace! > remainder.startIndex) ? whitespace! : limit
            
            chunks.append(String(remainder[..<boundary]).trimmingCharacters(in: .whitespacesAndNewlines))
            remainder = remainder[boundary...]
        }
        
        return chunks
    }
    
    private func characterBudget(for text: String) -> Int {
        let tokens = model.contextSize - LinkSummarizer.responseTokenBudget - LinkSummarizer.overheadTokenBudget
        return max(tokens * charactersPerToken(for: text), LinkSummarizer.minimumCharacterBudget)
    }
    
    private func charactersPerToken(for text: String) -> Int {
        let sample = text.prefix(LinkSummarizer.denseScriptSampleLength).unicodeScalars.filter { !$0.properties.isWhitespace }
        
        guard !sample.isEmpty else {
            return LinkSummarizer.charactersPerTokenLatin
        }
        
        let dense = sample.filter { scalar in
            LinkSummarizer.denseScriptRanges.contains { $0.contains(scalar.value) }
        }
        
        return Double(dense.count) / Double(sample.count) >= LinkSummarizer.denseScriptRatio
            ? LinkSummarizer.charactersPerTokenDense
            : LinkSummarizer.charactersPerTokenLatin
    }
}

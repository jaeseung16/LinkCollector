//
//  LinkSummarizerError.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 9/4/26.
//

import Foundation
import FoundationModels

enum LinkSummarizerError: Error {
    case unavailable(SystemLanguageModel.Availability.UnavailableReason)
    case noContent
    case generationFailed(LanguageModelSession.GenerationError)
}

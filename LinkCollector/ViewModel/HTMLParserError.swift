//
//  HTMLParserError.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 8/26/23.
//

import Foundation

enum HTMLParserError: Error {
    case invalidURL
    case invalidServerResponse
    case cannotParseData
}

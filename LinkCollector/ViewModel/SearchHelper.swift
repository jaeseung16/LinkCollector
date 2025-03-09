//
//  SearchHelper.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 3/9/25.
//

import Foundation
import CoreSpotlight
import CoreData
import os
import Persistence

enum QueryAttribute: String {
    case title

}

actor SearchHelper {
    private let logger = Logger()
    
    private let spotlightIndexer: LinkSpotlightDelegate?
    
    init(persistence: Persistence) {
        self.spotlightIndexer = persistence.createCoreSpotlightDelegate()
    }
    
    
    func isReady() -> Bool {
        return spotlightIndexer != nil
    }
    
    func toggleIndexing() {
        guard let spotlightIndexer = spotlightIndexer else { return }
        if spotlightIndexer.isIndexingEnabled {
            spotlightIndexer.stopSpotlightIndexing()
        } else {
            spotlightIndexer.startSpotlightIndexing()
        }
    }
    
    func startIndexing() {
        guard let spotlightIndexer = spotlightIndexer else { return }
        if !spotlightIndexer.isIndexingEnabled {
            spotlightIndexer.startSpotlightIndexing()
        }
    }
    
    private func stopIndexing() {
        guard let spotlightIndexer = spotlightIndexer else { return }
        if spotlightIndexer.isIndexingEnabled {
            spotlightIndexer.stopSpotlightIndexing()
        }
    }
    
    func refresh() {
        stopIndexing()
        deleteIndex()
        startIndexing()
    }
    
    private func deleteIndex() {
        Task {
            let index = CSSearchableIndex(name: LinkPilerConstants.linkIndexName.rawValue)
            
            do {
                try await index.deleteAllSearchableItems()
            } catch {
                self.logger.log("Error while deleting index=\(LinkPilerConstants.linkIndexName.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    func remove(with identifier: String) {
        guard let spotlightIndexer = spotlightIndexer, let indexName = spotlightIndexer.indexName() else { return }
        
        CSSearchableIndex(name: indexName).deleteSearchableItems(withIdentifiers: [identifier]) { error in
            self.logger.log("Can't delete an item with identifier=\(identifier, privacy: .public)")
        }
    }
    
    func index(_ attributeSet: SearchAttributeSet) {
        Task {
            guard let spotlightIndexer = spotlightIndexer, let indexName = spotlightIndexer.indexName() else { return }
            
            let searchableItem: CSSearchableItem = CSSearchableItem(uniqueIdentifier: attributeSet.uid,
                                                                    domainIdentifier: spotlightIndexer.domainIdentifier(),
                                                                    attributeSet: attributeSet.getCSSearchableItemAttributeSet())
            do {
                try await CSSearchableIndex(name: indexName).indexSearchableItems([searchableItem])
                logger.log("Indexed successfully: \(String(describing: attributeSet), privacy: .public)")
            } catch {
                self.logger.log("Error while indexing \(String(describing: attributeSet), privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    func prepareSearchQuery(_ text: String) -> CSSearchQuery {
        let escapedText = escape(text: text)
        let queryString = "\(QueryAttribute.title.rawValue) == \"*\(escapedText)*\"cd)"
        logger.log("queryString=\(queryString)")
        
        let queryContext = CSSearchQueryContext()
        queryContext.fetchAttributes = [QueryAttribute.title.rawValue]
        
        return CSSearchQuery(queryString: queryString, queryContext: queryContext)
    }
    
    private func escape(text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
    
    func search(_ text: String) async -> [String] {
        var results: [String] = []
        do {
            results = try await search(with: prepareSearchQuery(text))
        } catch {
            self.logger.log("Caught an error while searching notes with search string \(text): \(error.localizedDescription, privacy: .public)")
        }
        return results
    }
    
    private func search(with query: CSSearchQuery) async throws -> [String] {
        var results: [String] = []
        for try await result in query.results {
            results.append(result.item.uniqueIdentifier)
        }
        return results
    }
    
}

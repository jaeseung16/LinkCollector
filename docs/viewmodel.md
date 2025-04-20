```mermaid
classDiagram

LinkCollectorViewModel --> PersistenceHelper
LinkCollectorViewModel --> LinkSpotlightDelegate

LinkCollectorViewModel -- LinkCollectorDownloader

LinkCollectorDownloader --> FaviconFinder

```
```mermaid
classDiagram

SceneDelegate --> ContentView

ContentView -- LinkListView
ContentView "1" --> "*" LinkDetailView

LinkListView -- AddLinkView
LinkListView -- SelectTagsView
LinkListView -- DateRangePickerView

LinkDetailView -- WebView
LinkDetailView -- EditLinkView

AddLinkView -- AddTagView
```
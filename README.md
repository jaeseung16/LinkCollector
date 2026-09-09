# Description

Link Piler — a SwiftUI app to organize web links, syncing across devices via iCloud/CloudKit.

* Native for iOS, iPadOS, and macOS (AppKit, not Mac Catalyst) from one codebase, on Swift 6 with strict concurrency.
* The app is available on the App Store.

[<img src="./docs/assets/images/App_Store_Badge.svg">](https://apps.apple.com/us/app/link-piler/id1583309712)

# Installation

1. Clone or download the repository: [https://github.com/jaeseung16/LinkCollector.git](https://github.com/jaeseung16/LinkCollector.git)
2. Open `LinkPiler.xcodeproj` in Xcode 26 or later
3. Build and run (schemes: `LinkPiler`, `LinkPilerShareExtension`, `LinkPilerShareExtensionMac`, `LinkPilerWidgetExtension`)

## Requirements

1. A user may need to grant access to use location services.
2. With a valid iCloud account, the stored data can be shared across the iOS, iPadOS, and macOS platforms.
3. Summarizing a page's content uses Apple Intelligence on-device; on a device or region where it isn't available, the page's own description is shown instead.

# How to Use

### List of links

The list can be filtered by date range and by selected tags, chosen from the filter button in the tool bar. Select an entry to see the details. Pull down the list (or, on macOS, click the refresh button / press ⌘R) to pick up changes made on other devices.

### Detail scene

The scene displays the stored information on a selected entry and the loaded web content. Clicking "Open in Browser" opens the link in the user's default browser. Clicking "note" displays the stored note. Clicking "summary" displays an AI-generated summary of the page, generating one if there isn't one yet — this can take a while. Click "EDIT" to update title, note, and tags.

### Add a new entry

Click **Add**. Copy a URL into the text field below *URL* and hit ⏎. If possible, the *TITLE* and *LOCATION* will be populated. One may add a *note* and select *tags*. Click **Save**.

### Edit an entry

Once an entry is selected, a detailed view will appear. By clicking **EDIT**, *TITLE*, *NOTE*, *TAGS* can be updated. When updates are done, click **Save** to store the changes.

### Tags

When adding/editing an entry, tags can be attached and updated. Clicking **ADD TAGS** or **EDIT TAGS** will bring up the sheet to add, remove, create, and delete tags.

### Share links

Click the Share button to generate a bookmark file from the displayed links.

### Share Extension

If available, **Link Piler Share Extension** will appear among the share options. It may be found under **More**. Depending on devices and apps, some of URL, title, and location can be posted from the share extension. Note, tags, and summary can be edited in the main app.

### Widget

The widget presents randomly chosen items. Tapping one opens the app to that item.

## Version History

#### ver 2.0 (Sep 2026)
#### ver 1.6 (Apr 2025)
#### ver 1.5 (Sep 2024)
#### ver 1.4 (May 2022)
#### ver 1.0 (Aug 2021)

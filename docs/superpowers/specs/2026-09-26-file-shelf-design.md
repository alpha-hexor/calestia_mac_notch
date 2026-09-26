# Temporary file Shelf

Approved: fourth tab, Shelf, with AirDrop on the left and a temporary file tray
on the right, matching the existing cream/peach design.

- Store references to local files/folders in memory only. No copies or clipboard
  monitoring; quitting clears the shelf. Remove/Clear never delete original files.
- Accept multiple file URLs from Finder; deduplicate canonical paths. Show icons,
  names and missing-file states. Drag actual file URLs out to Telegram/Finder/etc.
- AirDrop drops open the native recipient chooser; clicking offers a file picker.
- Dragging files onto the compact notch expands/selects Shelf. Keep it open during
  inbound/outbound drag sessions and native chooser interactions.
- Handle missing files and unavailable AirDrop with visible messages.
- Test reference/deduplication/removal semantics, build both configurations, and
  document interactive Finder → Shelf → Telegram and AirDrop checks.

Implementation: pure reference store; main-actor Shelf service; native AppKit
drop/drag bridges and sharing service; SwiftUI Shelf tab; drag-aware window logic.

import SwiftUI

struct ShelfView: View {
    @ObservedObject var shelf: ShelfService
    @State private var overAirDrop = false
    @State private var overTray = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                FileDropContainer(onTargetChanged: { overAirDrop = $0 }, onDrop: { urls, window in
                    shelf.airDrop(urls, from: window)
                }) {
                    airDropZone
                }.frame(width: 180)

                FileDropContainer(onTargetChanged: { overTray = $0 }, onDrop: { urls, _ in shelf.add(urls) }) {
                    tray
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(shelf.message ?? "Temporary shelf · drag files into another app · originals stay in place")
                .font(.system(size: 9, design: .rounded)).foregroundStyle(Palette.muted)
                .lineLimit(1).help(shelf.message ?? "The tray clears when you quit. Removing an item never deletes the original file.")
                .frame(height: 14)
        }
        .onAppear { shelf.refreshAvailability() }
    }

    private var airDropZone: some View {
        Button { shelf.chooseFiles(forAirDrop: true) } label: {
            VStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 30, weight: .light))
                    .frame(width: 66, height: 66)
                    .background(Palette.peach.opacity(overAirDrop ? 0.85 : 0.45), in: Circle())
                Text(shelf.isSharing ? "Sharing…" : "AirDrop")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("Drop files or click to choose")
                    .font(.system(size: 10, design: .rounded)).foregroundStyle(Palette.muted)
            }
            .foregroundStyle(Palette.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(shelf.isSharing || shelf.isChoosingFiles)
        .background(Palette.card.opacity(overAirDrop ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 18))
        .overlay { dropBorder(highlighted: overAirDrop) }
    }

    private var tray: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Label("File tray", systemImage: "tray")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                if !shelf.files.isEmpty {
                    Text("\(shelf.files.count)").font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Palette.peach, in: Capsule())
                }
                Spacer()
                Button { shelf.chooseFiles(forAirDrop: false) } label: { Image(systemName: "plus") }
                    .help("Choose files for the tray").accessibilityLabel("Add files")
                if !shelf.files.isEmpty {
                    Button("Clear", action: shelf.clear).font(.system(size: 10))
                        .help("Remove references from the tray; keep original files")
                }
            }.foregroundStyle(Palette.accent).buttonStyle(.plain)

            if shelf.files.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 27, weight: .light))
                    Text("Drop files here").font(.system(size: 15, weight: .medium, design: .rounded))
                    Text("Then drag them into Telegram, Finder, or another app")
                        .font(.system(size: 10, design: .rounded)).foregroundStyle(Palette.muted)
                }
                .foregroundStyle(Palette.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                        ForEach(shelf.files) { file in
                            FileDragSource(file: file, icon: shelf.icon(for: file), isMissing: shelf.unavailableIDs.contains(file.id),
                                           onDragChanged: { shelf.isDraggingOut = $0 }, onMissing: shelf.reportMissingFile)
                                .frame(height: 83)
                                .overlay(alignment: .topTrailing) {
                                    Button { shelf.remove(file) } label: {
                                        Image(systemName: "xmark").font(.system(size: 8, weight: .semibold))
                                            .foregroundStyle(Palette.muted)
                                            .frame(width: 19, height: 19)
                                            .background(Palette.cream, in: Circle())
                                    }
                                    .buttonStyle(.plain).padding(3)
                                    .help("Remove from tray").accessibilityLabel("Remove \(file.name) from tray")
                                }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(14)
        .background(Palette.card.opacity(overTray ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 18))
        .overlay { dropBorder(highlighted: overTray) }
    }

    private func dropBorder(highlighted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .strokeBorder(highlighted ? Palette.accent : Palette.peach,
                          style: StrokeStyle(lineWidth: highlighted ? 2 : 1.5, dash: [6, 5]))
            .allowsHitTesting(false)
    }
}

import AppKit
import OpenWithCore
import SwiftUI

/// The shared root view: a searchable, filterable table of file types,
/// extensions and URL schemes with their current default app. Embedded by
/// OpenWith.app (`WindowGroup`) and by OpenWithPane (`NSHostingView`).
public struct DefaultsView: View {
  @State private var store: DefaultsStore

  public init(store: DefaultsStore? = nil) {
    _store = State(initialValue: store ?? DefaultsStore())
  }

  public var body: some View {
    @Bindable var store = store
    VStack(spacing: 0) {
      table
      Divider()
      statusBar
    }
    .searchable(
      text: $store.searchText, placement: .toolbar,
      prompt: "Search types, extensions, URL schemes"
    )
    .toolbar {
      ToolbarItemGroup {
        Picker("Filter", selection: $store.filter) {
          ForEach(DefaultsStore.Filter.allCases, id: \.self) { filter in
            Text(filter.rawValue).tag(filter)
          }
        }
        .pickerStyle(.menu)

        Button {
          Task { await store.load() }
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        .help("Re-read the current defaults from LaunchServices")

        Menu {
          Button("Apply or import a config…") { openAndApplyConfig() }
          Button("Export current defaults…") { exportConfig() }
        } label: {
          Label("Config", systemImage: "doc.badge.gearshape")
        }
      }
    }
    .task { await store.load() }
    .frame(minWidth: 640, minHeight: 400)
  }

  private var table: some View {
    Table(store.visibleRows) {
      TableColumn("Type") { (row: DefaultsStore.Row) in
        VStack(alignment: .leading, spacing: 2) {
          Text(row.label)
          Text(row.resolved.value)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .help(row.target.description)
      }

      TableColumn("Opens with") { (row: DefaultsStore.Row) in
        HandlerPicker(row: row) { app in
          Task { await store.setDefault(rowID: row.id, to: app, role: row.role) }
        }
      }

      TableColumn("Role") { (row: DefaultsStore.Row) in
        if row.isScheme {
          Text("—")
            .foregroundStyle(.tertiary)
            .help("URL schemes have no viewer/editor roles")
        } else {
          Picker(
            "Role",
            selection: Binding(
              get: { row.role },
              set: { store.setRole($0, forRowID: row.id) }
            )
          ) {
            ForEach(Role.allCases, id: \.self) { role in
              Text(role.rawValue).tag(role)
            }
          }
          .labelsHidden()
          .help("The LaunchServices role the change applies to")
        }
      }
      .width(min: 80, ideal: 90, max: 110)
    }
    .overlay {
      if store.isLoading && store.rows.isEmpty {
        ProgressView("Reading LaunchServices…")
      }
    }
  }

  private var statusBar: some View {
    HStack(spacing: 8) {
      if store.isLoading {
        ProgressView().controlSize(.small)
      }
      Text(store.statusMessage ?? "")
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer()
      Text("macOS asks you to confirm each change")
        .foregroundStyle(.secondary)
    }
    .font(.callout)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
  }

  // MARK: Config panels

  private func openAndApplyConfig() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.message =
      "Choose an openwith TOML config, a utiluti plist, or a utiluti .mobileconfig profile. "
      + "macOS will ask you to confirm each change."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    Task { _ = await store.applyConfigFile(at: url) }
  }

  private func exportConfig() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "openwith.toml"
    panel.message = "Export the current defaults for the known targets."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try store.exportConfig().write(to: url, atomically: true, encoding: .utf8)
      store.statusMessage = "exported \(url.lastPathComponent)"
    } catch {
      store.statusMessage = "export failed: \(error.localizedDescription)"
    }
  }
}

/// The per-row "Opens with" control: a menu of every registered handler,
/// with the app icons, reflecting the read-back state (not wishful state).
struct HandlerPicker: View {
  var row: DefaultsStore.Row
  var onSelect: (AppInfo) -> Void

  private var options: [AppInfo] {
    guard let current = row.current, !row.handlers.contains(current) else { return row.handlers }
    return [current] + row.handlers
  }

  var body: some View {
    HStack(spacing: 6) {
      if options.isEmpty {
        Text(row.current?.name ?? "—").foregroundStyle(.tertiary)
      } else {
        Picker(
          "Opens with",
          selection: Binding(
            get: { row.current?.bundleID ?? "" },
            set: { bundleID in
              guard bundleID != row.current?.bundleID,
                let app = options.first(where: { $0.bundleID == bundleID })
              else { return }
              onSelect(app)
            }
          )
        ) {
          if row.current == nil {
            Text("None").tag("")
          }
          ForEach(options, id: \.bundleID) { app in
            AppLabel(app: app).tag(app.bundleID)
          }
        }
        .labelsHidden()
      }

      if let outcome = row.lastOutcome {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.yellow)
          .help(outcome)
      }
    }
  }
}

struct AppLabel: View {
  var app: AppInfo

  var body: some View {
    HStack(spacing: 4) {
      Image(nsImage: icon)
      Text(app.name)
    }
  }

  private var icon: NSImage {
    let image = NSWorkspace.shared.icon(forFile: app.path)
    image.size = NSSize(width: 16, height: 16)
    return image
  }
}

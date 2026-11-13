import SwiftUI
import UIKit

struct Shortcut: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var symbol: String
    var url: String
    // Optional to keep existing saved shortcuts compatible after upgrading.
    var fallbackURL: String? = nil
}

struct WheelView: View {
    @AppStorage("savedShortcuts") private var saved = Data()
    @AppStorage("quickwheel.lastLaunchResult") private var lastResult = "Ready to test app launching."

    @State private var shortcuts: [Shortcut] = [
        .init(name: "Shortcuts", symbol: "square.stack.3d.up.fill", url: "shortcuts://"),
        .init(name: "Maps", symbol: "map.fill", url: "maps://", fallbackURL: "https://maps.apple.com"),
        .init(name: "Messages", symbol: "message.fill", url: "sms:"),
        .init(name: "Music", symbol: "music.note", url: "music://", fallbackURL: "https://music.apple.com"),
        .init(name: "ChatGPT (web)", symbol: "bubble.left.and.bubble.right.fill", url: "https://chatgpt.com"),
        .init(name: "Safari test", symbol: "safari.fill", url: "https://www.apple.com")
    ]
    @State private var selection = 0
    @State private var editing = false
    @State private var testing = false
    @State private var showError = false
    @State private var errorDetails = ""
    @State private var lastDrag: CGFloat = 0

    private let haptic = UISelectionFeedbackGenerator()

    private var selected: Shortcut { shortcuts[selection] }

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width - 32, 370.0)
            ZStack {
                LinearGradient(
                    colors: [.black, Color(red: 0.07, green: 0.11, blue: 0.22), .black],
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()
                VStack(spacing: 16) {
                    HStack {
                        Text("QUICKWHEEL").font(.caption.bold()).tracking(3)
                        Spacer()
                        Button { testing = true } label: {
                            Image(systemName: "stethoscope").accessibilityLabel("Launch tests")
                        }
                        Button { editing = true } label: {
                            Image(systemName: "gearshape.fill").accessibilityLabel("Edit shortcuts")
                        }
                    }.padding(.horizontal, 22)
                    Spacer(minLength: 0)
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                            .overlay(Circle().stroke(.cyan.opacity(0.5), lineWidth: 2))
                        ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, item in
                            let angle = Double(index - selection) * 2 * Double.pi / Double(max(shortcuts.count, 1)) - Double.pi / 2
                            Button {
                                selection = index
                                haptic.selectionChanged()
                            } label: {
                                Image(systemName: item.symbol)
                                    .font(.title2)
                                    .frame(width: 52, height: 52)
                                    .background(index == selection ? Color.blue : Color.white.opacity(0.15),
                                                in: RoundedRectangle(cornerRadius: 15))
                            }
                            .position(
                                x: diameter / 2 + cos(angle) * diameter * 0.37,
                                y: diameter / 2 + sin(angle) * diameter * 0.37
                            )
                        }
                        VStack(spacing: 8) {
                            Image(systemName: selected.symbol).font(.system(size: 40))
                            Text(selected.name).font(.headline)
                                .lineLimit(2).multilineTextAlignment(.center)
                        }
                        .frame(width: diameter * 0.45, height: diameter * 0.45)
                        .background(.black.opacity(0.7), in: Circle())
                    }
                    .frame(width: diameter, height: diameter)
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                let diff = value.translation.height - lastDrag
                                if abs(diff) > 30 {
                                    rotate(diff > 0 ? 1 : -1)
                                    lastDrag = value.translation.height
                                }
                            }
                            .onEnded { _ in lastDrag = 0 }
                    )
                    Text("Swipe to rotate · Tap to choose").foregroundStyle(.secondary)
                        .font(.caption)
                    Button { openURL(selected.url, label: selected.name) } label: {
                        Label("Open " + selected.name, systemImage: "arrow.up.right")
                            .frame(maxWidth: .infinity).padding(10)
                    }.buttonStyle(.borderedProminent).padding(.horizontal, 35)

                    if let backup = fallback(for: selected) {
                        Button("Open website fallback") {
                            openURL(backup, label: selected.name + " website")
                        }.buttonStyle(.bordered).font(.caption)
                    }
                    HStack {
                        Button { rotate(-1) } label: { Image(systemName: "chevron.up.circle.fill") }
                        Spacer()
                        Text("\(selection + 1) / \(shortcuts.count)")
                        Spacer()
                        Button { rotate(1) } label: { Image(systemName: "chevron.down.circle.fill") }
                    }.padding(.horizontal, 80)
                    Text(lastResult)
                        .font(.caption2).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 25)
                        .frame(minHeight: 36)
                    Spacer(minLength: 0)
                }.padding(.vertical, 18)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onAppear {
            if let decoded = try? JSONDecoder().decode([Shortcut].self, from: saved), !decoded.isEmpty {
                shortcuts = decoded
            }
            selection = min(selection, shortcuts.count - 1)
        }
        .sheet(isPresented: $editing) { editor }
        .sheet(isPresented: $testing) { tests }
        .alert("iOS could not open this link", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorDetails)
        }
    }

    private var tests: some View {
        NavigationStack {
            Form {
                Section("Check iOS can open links") {
                    Button("Test Safari / web link") {
                        openURL("https://www.apple.com", label: "Safari web test")
                    }
                    Button("Test Apple Shortcuts / app link") {
                        openURL("shortcuts://", label: "Shortcuts app test")
                    }
                    Button("Test Apple Maps / app link") {
                        openURL("maps://", label: "Maps app test")
                    }
                    Button("Test Messages / system link") {
                        openURL("sms:", label: "Messages system test")
                    }
                    Text(lastResult).font(.caption).textSelection(.enabled)
                }
                Section("What is supported") {
                    Text("The iPhone can launch an app if it registers the selected URL scheme, or it can open a supported web link. Apps without public deep links can be opened with a personal Apple Shortcut.")
                    Text("Create a Shortcut containing the Open App action, then use a URL such as shortcuts://run-shortcut?name=Open%20ChatGPT in QuickWheel.")
                    Text("A successful openURL result means iOS accepted the link; it does not prove which app or website appears.")
                }
            }
            .navigationTitle("Launch tests")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { testing = false } } }
        }
    }

    private var editor: some View {
        NavigationStack {
            Form {
                ForEach(shortcuts.indices, id: \.self) { index in
                    Section("Shortcut \(index + 1)") {
                        TextField("Name", text: $shortcuts[index].name)
                        TextField("SF Symbol", text: $shortcuts[index].symbol)
                        TextField("App URL scheme or Shortcuts URL", text: $shortcuts[index].url)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Optional website fallback", text: Binding(
                            get: { shortcuts[index].fallbackURL ?? "" },
                            set: { shortcuts[index].fallbackURL = $0 }
                        ))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Test this shortcut") {
                            openURL(shortcuts[index].url, label: shortcuts[index].name)
                        }
                    }
                }
                if shortcuts.count < 10 {
                    Button("Add shortcut") {
                        shortcuts.append(.init(name: "New App", symbol: "star.fill", url: "shortcuts://"))
                    }
                }
                if shortcuts.count > 1 {
                    Button("Remove last shortcut", role: .destructive) {
                        shortcuts.removeLast()
                        selection = 0
                    }
                }
                Section("Launch instructions") {
                    Text("For apps that don't provide a public URL scheme, open Apple Shortcuts, create a shortcut with the Open App action, name it e.g. Open ChatGPT, then enter shortcuts://run-shortcut?name=Open%20ChatGPT above.")
                    Text("For simple websites use https:// links. Some universal links open the corresponding app, but iOS controls that behavior.")
                }
            }
            .navigationTitle("Customize wheel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saved = (try? JSONEncoder().encode(shortcuts)) ?? Data()
                        editing = false
                    }
                }
            }
        }
    }

    private func rotate(_ direction: Int) {
        selection = (selection + direction + shortcuts.count) % shortcuts.count
        haptic.selectionChanged()
    }

    private func fallback(for item: Shortcut) -> String? {
        if let explicit = item.fallbackURL, !explicit.isEmpty { return explicit }
        switch item.name.lowercased() {
        case "music": return "https://music.apple.com"
        case "maps": return "https://maps.apple.com"
        case "chatgpt": return "https://chatgpt.com"
        default: return nil
        }
    }

    private func openURL(_ raw: String, label: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            failed("Invalid URL: \(raw). Add a valid scheme such as shortcuts:// or https://.")
            return
        }
        lastResult = "Trying \(label): \(trimmed)"
        UIApplication.shared.open(url, options: [:]) { accepted in
            lastResult = accepted
                ? "iOS accepted \(label) (\(url.scheme ?? "link"))."
                : "iOS rejected \(label): \(trimmed)"
            if !accepted {
                failed("No installed handler accepted \(trimmed). Try the website fallback or an Apple Shortcut with an Open App action.")
            }
        }
    }

    private func failed(_ message: String) {
        lastResult = message
        errorDetails = message
        showError = true
    }
}

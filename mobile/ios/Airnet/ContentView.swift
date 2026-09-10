import AirnetCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: FeedModel
    @State private var composing = false

    var body: some View {
        TabView {
            NavigationStack {
                Group {
                    if !model.ready {
                        ContentUnavailableView {
                            Label("Your node couldn’t open", systemImage: "externaldrive.badge.exclamationmark")
                        } description: {
                            Text(model.error ?? "Unlock your iPhone and try again.")
                        } actions: {
                            Button("Try again", action: model.open)
                        }
                    } else {
                        List {
                            Section {
                                Label("Available offline", systemImage: "iphone")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text("Posts stay on this iPhone. Sharing will begin when a transport is connected.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            if model.posts.isEmpty {
                                ContentUnavailableView("Your feed starts here", systemImage: "text.bubble",
                                    description: Text("Write a post. It will be saved even with Wi-Fi and cellular off."))
                                    .listRowBackground(Color.clear)
                            }
                            ForEach(model.posts) { post in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(post.envelope.payload.author == model.publicKey ? "You" : String(post.envelope.payload.author.prefix(12)))
                                            .font(.subheadline.bold())
                                        Spacer()
                                        Text(Date(timeIntervalSince1970: Double(post.envelope.payload.timestamp)), style: .relative)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Text(post.envelope.payload.body).textSelection(.enabled)
                                    Label(post.queued ? "Saved · waiting to share" : "Saved on this phone",
                                          systemImage: post.queued ? "clock" : "checkmark.shield")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                .navigationTitle("airnet")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Write a post", systemImage: "square.and.pencil") { composing = true }
                            .disabled(!model.ready)
                    }
                }
                .sheet(isPresented: $composing) { ComposerView(model: model) }
            }
            .tabItem { Label("Feed", systemImage: "text.bubble") }

            NavigationStack {
                Form {
                    Section("Your identity") {
                        Text("This key identifies your signed posts. No account or internet connection is required.")
                        if !model.publicKey.isEmpty {
                            Text(model.publicKey).font(.caption.monospaced()).textSelection(.enabled)
                            ShareLink("Share public key", item: model.publicKey)
                        }
                    }
                    Section("Stored on this iPhone") {
                        LabeledContent("Posts", value: "\(model.posts.count)")
                        LabeledContent("Waiting to share", value: "\(model.posts.filter(\.queued).count)")
                        Text("Your signing key is kept in Keychain on this device. Identity backup and transfer to another phone are not available yet.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Connection") {
                        Label("Offline · no radio connected", systemImage: "antenna.radiowaves.left.and.right.slash")
                        Text("Bluetooth and mesh synchronization are planned. You can write and read posts now without a Mac or Python server.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Your node")
            }
            .tabItem { Label("Your node", systemImage: "person.crop.circle") }
        }
        .tint(.teal)
        .alert("Couldn’t complete that action", isPresented: Binding(
            get: { model.ready && model.error != nil },
            set: { if !$0 { model.error = nil } }
        )) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
    }
}

struct ComposerView: View {
    @ObservedObject var model: FeedModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool
    private var count: Int { PostText.count(PostText.trimmed(text)) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("What’s happening?").font(.headline)
                TextEditor(text: $text)
                    .focused($focused)
                    .accessibilityLabel("Post text")
                    .frame(minHeight: 160)
                HStack {
                    Label("Saves offline", systemImage: "internaldrive")
                    Spacer()
                    Text("\(count) / 280").foregroundStyle(count > 280 ? Color.red : Color.secondary)
                }
                .font(.footnote).foregroundStyle(.secondary)
                if let error = model.error { Text(error).foregroundStyle(.red).font(.footnote) }
                Spacer()
            }
            .padding()
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { if model.publish(text) { dismiss() } }
                        .disabled(!(1...280).contains(count))
                }
            }
            .onAppear { focused = true }
        }
    }
}

import AirnetCore
import SwiftUI

@main
struct AirnetApp: App {
    @StateObject private var model = FeedModel()

    var body: some Scene {
        WindowGroup { ContentView(model: model) }
    }
}

@MainActor
final class FeedModel: ObservableObject {
    @Published var posts: [StoredPost] = []
    @Published var publicKey = ""
    @Published var error: String?
    @Published var ready = false
    private var identity: Identity?
    private var store: PostStore?

    init() { open() }

    func open() {
        do {
            let identity = try KeychainIdentity.loadOrCreate()
            let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Airnet", isDirectory: true)
            let store = try PostStore(url: directory.appendingPathComponent("posts.sqlite"))
            let posts = try store.posts()
            self.identity = identity
            self.store = store
            self.publicKey = identity.publicKey
            self.posts = posts
            self.ready = true
            self.error = nil
        } catch {
            self.ready = false
            self.error = error.localizedDescription
        }
    }

    func publish(_ text: String) -> Bool {
        guard let identity, let store, ready else { return false }
        do {
            let envelope = try identity.createPost(text)
            try store.save(envelope, queued: true)
            posts = try store.posts()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

import SwiftUI

/// Palette e stili condivisi dell'app.
enum Tema {
    static let primario = Color(red: 0.545, green: 0.227, blue: 0.180)        // #8b3a2e
    static let primarioScuro = Color(red: 0.427, green: 0.165, blue: 0.122)   // #6d2a1f
    static let primarioMorbido = Color(red: 0.953, green: 0.898, blue: 0.882) // #f3e5e1
    static let sfondo = Color(red: 0.965, green: 0.953, blue: 0.925)          // #f6f3ec
}

/// Etichetta capsula per la posizione.
struct EtichettaPosizione: View {
    let testo: String
    var body: some View {
        Label(testo, systemImage: "mappin.circle.fill")
            .font(.callout.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Tema.primarioMorbido)
            .foregroundStyle(Tema.primario)
            .clipShape(Capsule())
    }
}

// Cache immagini in memoria per l'intera sessione (NSCache è thread-safe).
private final class ImageCache {
    static let shared = ImageCache()
    private let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 300
        c.totalCostLimit = 150 * 1024 * 1024 // 150 MB
        return c
    }()
    func get(_ key: String) -> NSImage? { cache.object(forKey: key as NSString) }
    func set(_ img: NSImage, for key: String) { cache.setObject(img, forKey: key as NSString, cost: Int(img.size.width * img.size.height * 4)) }
}

@MainActor
private final class ImageLoader: ObservableObject {
    @Published var image: NSImage?

    func load(_ urlString: String) async {
        guard !urlString.isEmpty else { return }
        // Forza HTTPS per evitare blocchi ATS
        let secured = urlString.hasPrefix("http://") ? "https://" + urlString.dropFirst(7) : urlString
        guard let url = URL(string: secured) else { return }
        if let cached = ImageCache.shared.get(secured) { image = cached; return }
        // Nessun controllo statusCode: URLSession segue i redirect automaticamente
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = NSImage(data: data),
              img.size.width > 10, img.size.height > 10 else { return }
        ImageCache.shared.set(img, for: secured)
        image = img
    }
}

/// Copertina con cache in memoria. Sempre scaledToFill — il chiamante mette frame + .clipped().
struct CopertinaImage: View {
    let url: String
    @StateObject private var loader = ImageLoader()

    var body: some View {
        Group {
            if let img = loader.image {
                Image(nsImage: img).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: url) { await loader.load(url) }
    }

    var placeholder: some View {
        ZStack {
            Color(red: 0.937, green: 0.914, blue: 0.863)
            Image(systemName: "book.closed")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
        }
    }
}

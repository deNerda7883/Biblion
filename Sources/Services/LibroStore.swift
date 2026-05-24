import Foundation
import SwiftUI

@MainActor
final class LibroStore: ObservableObject {
    @Published private(set) var libri: [Libro] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(customURL: URL? = nil) {
        let fm = FileManager.default
        let appSupport = (try? fm.url(for: .applicationSupportDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: true))
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let appDir = appSupport.appendingPathComponent("Libreria", isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = customURL ?? appDir.appendingPathComponent("libreria.json")

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        carica()
    }

    var totale: Int { libri.count }

    // MARK: - Generi e posizioni

    struct GruppoVoce: Identifiable {
        let nome: String
        var id: String { nome }
        let count: Int
    }

    /// Generi unici con conteggio libri, ordinati alfabeticamente. "Senza genere" va in fondo.
    var generiConConteggio: [GruppoVoce] {
        var mappa: [String: Int] = [:]
        for libro in libri {
            let g = libro.genere.isEmpty ? "Senza genere" : libro.genere
            mappa[g, default: 0] += 1
        }
        return mappa
            .map { GruppoVoce(nome: $0.key, count: $0.value) }
            .sorted {
                if $0.nome == "Senza genere" { return false }
                if $1.nome == "Senza genere" { return true }
                return $0.nome.localizedCompare($1.nome) == .orderedAscending
            }
    }

    var posizioniUniche: [String] {
        Array(Set(libri.map(\.posizione)))
            .sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    var ultimoAggiunto: Libro? {
        libri.max(by: { $0.dataInserimento < $1.dataInserimento })
    }

    // MARK: - CRUD

    func aggiungi(_ libro: Libro) { libri.append(libro); salva() }
    func aggiorna(_ libro: Libro) {
        if let i = libri.firstIndex(where: { $0.id == libro.id }) { libri[i] = libro; salva() }
    }
    func elimina(_ libro: Libro) { libri.removeAll { $0.id == libro.id }; salva() }
    func cercaIsbn(_ isbn: String) -> Libro? {
        let p = BookLookup.pulisciISBN(isbn)
        return libri.first { $0.isbn == p && !p.isEmpty }
    }


    // MARK: - Persistenza

    private func carica() {
        do {
            let data = try Data(contentsOf: fileURL)
            libri = try decoder.decode([Libro].self, from: data)
        } catch CocoaError.fileReadNoSuchFile { libri = []
        } catch { print("Errore caricamento: \(error)"); libri = [] }
    }

    private func salva() {
        do {
            let data = try encoder.encode(libri)
            try data.write(to: fileURL, options: [.atomic])
        } catch { print("Errore salvataggio: \(error)") }
    }
}

import Foundation
import AppKit

struct LibroLookup: Equatable {
    var isbn: String
    var titolo: String
    var autore: String
    var editore: String
    var anno: Int?
    var pagine: Int?
    var lingua: String
    var genere: String
    var descrizione: String
    var copertinaURL: String
    var fonte: String
}

enum BookLookupError: LocalizedError {
    case isbnInvalido
    case nessunRisultato
    case rete(String)

    var errorDescription: String? {
        switch self {
        case .isbnInvalido: return "ISBN non valido (deve essere 10 o 13 cifre)."
        case .nessunRisultato: return "Nessuna informazione trovata online per questo ISBN. Compila i campi a mano."
        case .rete(let m): return "Errore di rete: \(m)"
        }
    }
}

enum BookLookup {

    static func pulisciISBN(_ raw: String) -> String {
        raw.uppercased().filter { $0.isNumber || $0 == "X" }
    }

    static func cerca(isbn raw: String) async throws -> LibroLookup {
        let isbn = pulisciISBN(raw)
        guard isbn.count == 10 || isbn.count == 13 else {
            throw BookLookupError.isbnInvalido
        }

        // Prepara anche la versione ISBN-10 (se input è ISBN-13 con prefisso 978)
        let isbn10 = isbn13a10(isbn)

        var risultati: [LibroLookup] = []
        print("[LOOKUP] ISBN: \(isbn)")

        // Fase 1: tutte le fonti in parallelo
        async let r1 = sbnNuovo(isbn: isbn)
        async let r2 = googleBooks(isbn: isbn)
        async let r3 = openLibrary(isbn: isbn)
        async let r4 = openLibraryDiretto(isbn: isbn)
        let fase1 = await [try? r1, try? r2, try? r3, try? r4]
        let nomi1 = ["SBN", "GoogleBooks", "OpenLibrary", "OpenLibraryDiretto"]
        for (r, nome) in zip(fase1, nomi1) {
            if let r, !r.titolo.isEmpty {
                print("[LOOKUP] ✓ \(nome): \(r.titolo)")
                risultati.append(r)
            } else {
                print("[LOOKUP] ✗ \(nome): nessun risultato")
            }
        }

        // Fase 2: riprova con ISBN-10 se nessun risultato
        if risultati.isEmpty, let alt = isbn10 {
            print("[LOOKUP] Riprovo con ISBN-10: \(alt)")
            async let a1 = sbnNuovo(isbn: alt)
            async let a2 = googleBooks(isbn: alt)
            async let a3 = openLibrary(isbn: alt)
            let fase2 = await [try? a1, try? a2, try? a3]
            let nomi2 = ["SBN", "GoogleBooks", "OpenLibrary"]
            for (r, nome) in zip(fase2, nomi2) {
                if let r, !r.titolo.isEmpty {
                    print("[LOOKUP] ✓ \(nome) (ISBN-10): \(r.titolo)")
                    risultati.append(r)
                } else {
                    print("[LOOKUP] ✗ \(nome) (ISBN-10): nessun risultato")
                }
            }
        }

        // Fase 3: Gemini AI come ultima risorsa
        if risultati.isEmpty {
            print("[LOOKUP] Provo Gemini AI...")
            let apiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
            if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let r = try? await geminiAI(isbn: isbn, apiKey: apiKey),
               !r.titolo.isEmpty {
                print("[LOOKUP] ✓ Gemini: \(r.titolo)")
                risultati.append(r)
            } else {
                print("[LOOKUP] ✗ Gemini: nessun risultato o chiave mancante")
            }
        }

        guard var base = risultati.first else {
            print("[LOOKUP] FALLITO: nessuna fonte ha trovato il libro")
            throw BookLookupError.nessunRisultato
        }
        for s in risultati.dropFirst() { base = unisci(base, s) }

        // Fase 4: copertina automatica — Open Library, IBS, Gemini AI
        if base.copertinaURL.isEmpty,
           let coverURL = await fetchCopertinaURL(isbn: isbn, titolo: base.titolo, autore: base.autore) {
            base.copertinaURL = coverURL
            print("[LOOKUP] ✓ Copertina trovata")
        }

        print("[LOOKUP] Risultato finale: \"\(base.titolo)\" — fonte: \(base.fonte) — cover: \(!base.copertinaURL.isEmpty)")
        return base
    }

    // Converte ISBN-13 (prefisso 978) in ISBN-10.
    static func isbn13a10(_ isbn13: String) -> String? {
        guard isbn13.count == 13, isbn13.hasPrefix("978") else { return nil }
        let base = String(isbn13.dropFirst(3).prefix(9))
        var sum = 0
        for (i, c) in base.enumerated() {
            guard let d = c.wholeNumberValue else { return nil }
            sum += d * (10 - i)
        }
        let check = (11 - (sum % 11)) % 11
        let checkChar = check == 10 ? "X" : String(check)
        return base + checkChar
    }

    // MARK: - Google Books

    private static func googleBooks(isbn: String) async throws -> LibroLookup? {
        let apiKey = UserDefaults.standard.string(forKey: "google_books_api_key") ?? ""
        let keyParam = apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "&key=\(apiKey)"
        guard let q = "isbn:\(isbn)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.googleapis.com/books/v1/volumes?q=\(q)&maxResults=5\(keyParam)") else {
            return nil
        }
        var (data, resp) = try await URLSession.shared.data(from: url)
        // Se la chiave dà 403/400 riprova senza chiave (restrizioni mal configurate)
        if let http = resp as? HTTPURLResponse, (http.statusCode == 403 || http.statusCode == 400),
           !keyParam.isEmpty,
           let fallbackURL = URL(string: "https://www.googleapis.com/books/v1/volumes?q=\(q)&maxResults=5") {
            (data, resp) = try await URLSession.shared.data(from: fallbackURL)
        }
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        struct R: Decodable {
            struct Item: Decodable { let volumeInfo: VolumeInfo? }
            struct VolumeInfo: Decodable {
                let title: String?
                let authors: [String]?
                let publisher: String?
                let publishedDate: String?
                let pageCount: Int?
                let language: String?
                let description: String?
                let categories: [String]?
                let imageLinks: ImageLinks?
                let industryIdentifiers: [Identifier]?
            }
            struct ImageLinks: Decodable {
                let thumbnail: String?
                let smallThumbnail: String?
            }
            struct Identifier: Decodable { let identifier: String? }
            let items: [Item]?
        }

        let decoded = try JSONDecoder().decode(R.self, from: data)
        guard let items = decoded.items, !items.isEmpty else { return nil }

        // Varianti ISBN da cercare nella risposta (ISBN-13 e ISBN-10 equivalente)
        let isbnPulito = isbn.filter { $0.isNumber || $0 == "X" }
        var isbnVarianti: Set<String> = [isbnPulito]
        if let alt = isbn13a10(isbnPulito) { isbnVarianti.insert(alt) }

        // Cerca solo risultati il cui ISBN nella risposta corrisponde esattamente
        let info = items.compactMap { $0.volumeInfo }.first { volumeInfo in
            let ids = volumeInfo.industryIdentifiers?
                .compactMap { $0.identifier?.filter { $0.isNumber || $0 == "X" } } ?? []
            return ids.contains(where: { isbnVarianti.contains($0) })
        }

        guard let info, let titolo = info.title, !titolo.isEmpty else { return nil }

        var cover = info.imageLinks?.thumbnail ?? info.imageLinks?.smallThumbnail ?? ""
        if cover.hasPrefix("http://") { cover = "https://" + cover.dropFirst("http://".count) }

        var anno: Int?
        if let s = info.publishedDate, let m = s.range(of: #"^\d{4}"#, options: .regularExpression) {
            anno = Int(s[m])
        }

        return LibroLookup(
            isbn: isbn,
            titolo: titolo,
            autore: (info.authors ?? []).joined(separator: ", "),
            editore: info.publisher ?? "",
            anno: anno,
            pagine: info.pageCount,
            lingua: info.language ?? "",
            genere: (info.categories ?? []).first ?? "",
            descrizione: info.description ?? "",
            copertinaURL: cover,
            fonte: "Google Books"
        )
    }

    // MARK: - Open Library (bibkeys API)

    private static func openLibrary(isbn: String) async throws -> LibroLookup? {
        guard let url = URL(string: "https://openlibrary.org/api/books?bibkeys=ISBN:\(isbn)&format=json&jscmd=data") else {
            return nil
        }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entry = json["ISBN:\(isbn)"] as? [String: Any]
        else { return nil }

        let titolo = entry["title"] as? String ?? ""
        guard !titolo.isEmpty else { return nil }

        let autori = (entry["authors"] as? [[String: Any]] ?? [])
            .compactMap { $0["name"] as? String }.joined(separator: ", ")
        let editori = (entry["publishers"] as? [[String: Any]] ?? [])
            .compactMap { $0["name"] as? String }.joined(separator: ", ")
        let cover = entry["cover"] as? [String: String] ?? [:]
        let copertina = cover["large"] ?? cover["medium"] ?? cover["small"] ?? ""

        var anno: Int?
        if let s = entry["publish_date"] as? String,
           let m = s.range(of: #"\d{4}"#, options: .regularExpression) {
            anno = Int(s[m])
        }

        let soggetti = (entry["subjects"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }

        return LibroLookup(
            isbn: isbn,
            titolo: titolo,
            autore: autori,
            editore: editori,
            anno: anno,
            pagine: entry["number_of_pages"] as? Int,
            lingua: "",
            genere: soggetti.first ?? "",
            descrizione: "",
            copertinaURL: copertina,
            fonte: "Open Library"
        )
    }

    // MARK: - Open Library (endpoint diretto /isbn/)

    private static func openLibraryDiretto(isbn: String) async throws -> LibroLookup? {
        guard let url = URL(string: "https://openlibrary.org/isbn/\(isbn).json") else { return nil }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let titolo = json["title"] as? String ?? ""
        guard !titolo.isEmpty else { return nil }

        var anno: Int?
        if let s = json["publish_date"] as? String,
           let m = s.range(of: #"\d{4}"#, options: .regularExpression) {
            anno = Int(s[m])
        }

        let pagine = json["number_of_pages"] as? Int
        let editore = (json["publishers"] as? [String] ?? []).first ?? ""
        let lingua = (json["languages"] as? [[String: Any]] ?? [])
            .compactMap { ($0["key"] as? String)?.components(separatedBy: "/").last }
            .first ?? ""

        // Copertina tramite covers array
        var copertina = ""
        if let coverID = (json["covers"] as? [Int])?.first {
            copertina = "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg"
        }

        return LibroLookup(
            isbn: isbn,
            titolo: titolo,
            autore: "",
            editore: editore,
            anno: anno,
            pagine: pagine,
            lingua: lingua,
            genere: "",
            descrizione: "",
            copertinaURL: copertina,
            fonte: "Open Library"
        )
    }

    // MARK: - SBN (Servizio Bibliotecario Nazionale italiano)

    private static func sbnNuovo(isbn: String) async throws -> LibroLookup? {
        guard let url = URL(string: "https://opac.sbn.it/o/opac-api/titles-search-full-post") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        req.httpBody = "isbn=\(isbn)".data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseData = json["data"] as? [String: Any],
              let results = responseData["results"] as? [[String: Any]],
              let first = results.first else { return nil }

        guard let titleDict = first["title"] as? [String: Any],
              let titleInfo = titleDict["info"] as? String else { return nil }

        // Titolo: due formati possibili:
        // 1) "{Matematica.blu 2.0}5"            → estrai tra graffe
        // 2) "Oliver Twist / Charles Dickens"   → prendi prima di " / "
        let titolo: String
        if titleInfo.contains("{") && titleInfo.contains("}") {
            titolo = String(titleInfo.drop(while: { $0 != "{" }).dropFirst().prefix(while: { $0 != "}" }))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            titolo = (titleInfo.components(separatedBy: " / ").first ?? titleInfo)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !titolo.isEmpty else { return nil }

        // Estrai dati dai facets
        let facets = responseData["facets"] as? [[String: Any]] ?? []
        func items(_ name: String) -> [[String: Any]] {
            facets.first(where: { ($0["name"] as? String) == name })
                .flatMap { $0["items"] as? [[String: Any]] } ?? []
        }

        // Autori dai facets: "dickens, charles" → "Charles Dickens"
        // Fallback: title.text contiene "Autore, Nome <anno-anno>"
        var autore = items("nomef[]")
            .compactMap { $0["label"] as? String }
            .map { raw -> String in
                let parti = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).capitalized }
                return parti.count >= 2 ? "\(parti[1]) \(parti[0])" : parti[0]
            }
            .joined(separator: ", ")

        if autore.isEmpty, let textField = titleDict["text"] as? String, !textField.isEmpty {
            // "Dickens, Charles <1812-1870>" → "Charles Dickens"
            let pulito = textField.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let parti = pulito.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).capitalized }
            autore = parti.count >= 2 ? "\(parti[1]) \(parti[0])" : parti.first ?? ""
        }

        let anno = items("dataf[]").first.flatMap { $0["label"] as? String }.flatMap { Int($0) }
        let lingua = items("lingua[]").first.flatMap { $0["value"] as? String } ?? "it"

        // Editore da infos[0]: "Palermo : Selino's, 2012"
        let editore: String = {
            let info0 = (first["infos"] as? [String])?.first ?? ""
            if let range = info0.range(of: ": ") {
                let dopo = String(info0[range.upperBound...])
                return dopo.components(separatedBy: ",").first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
            return ""
        }()

        return LibroLookup(
            isbn: isbn, titolo: titolo, autore: autore,
            editore: editore, anno: anno, pagine: nil,
            lingua: lingua, genere: "", descrizione: "",
            copertinaURL: "", fonte: "SBN"
        )
    }

    // MARK: - Gemini AI con Google Search grounding

    private static func geminiAI(isbn: String, apiKey: String) async throws -> LibroLookup? {
        // Modelli che supportano Google Search grounding (dal più leggero al più potente)
        let modelli = [
            "gemini-2.0-flash",
            "gemini-2.5-flash",
            "gemini-2.5-flash-lite"
        ]

        let prompt = """
            Cerca su internet l'ISBN \(isbn) e dimmi quale libro corrisponde.
            Basati sui risultati più frequenti trovati online (librerie, cataloghi, schede libro).
            Rispondi SOLO con JSON valido, nessun testo extra, nessun markdown.
            Formato: {"titolo":"","autore":"","editore":"","anno":0,"pagine":0,"lingua":"it","genere":"","descrizione":""}
            Se non trovi nulla di certo online: {"titolo":""}
            """

        // Google Search grounding: Gemini cerca davvero su internet
        let bodyObj: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "tools": [["google_search": [:]]],
            "generationConfig": ["maxOutputTokens": 500, "temperature": 0]
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: bodyObj) else { return nil }

        var data: Data = Data()
        var trovato = false
        for modello in modelli {
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/\(modello):generateContent?key=\(apiKey)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = bodyData
            guard let (d, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse else { continue }
            if http.statusCode == 200 { data = d; trovato = true; break }
        }
        guard trovato else { return nil }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let testo = parts.first?["text"] as? String
        else { return nil }

        // Estrai il JSON dalla risposta (potrebbe avere ```json ... ```)
        let jsonPulito = testo
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let testoData = jsonPulito.data(using: .utf8),
            let libro = try JSONSerialization.jsonObject(with: testoData) as? [String: Any],
            let titolo = libro["titolo"] as? String, !titolo.isEmpty
        else { return nil }

        var anno: Int? = libro["anno"] as? Int
        if anno == 0 { anno = nil }
        var pagine: Int? = libro["pagine"] as? Int
        if pagine == 0 { pagine = nil }

        return LibroLookup(
            isbn: isbn,
            titolo: titolo,
            autore: libro["autore"] as? String ?? "",
            editore: libro["editore"] as? String ?? "",
            anno: anno,
            pagine: pagine,
            lingua: libro["lingua"] as? String ?? "",
            genere: libro["genere"] as? String ?? "",
            descrizione: libro["descrizione"] as? String ?? "",
            copertinaURL: "",
            fonte: "Gemini AI"
        )
    }

    // MARK: - Helpers copertina

    // Cerca la copertina per un libro già in libreria (per retroattivo su libri esistenti).
    static func fetchCopertinaURL(isbn: String, titolo: String, autore: String) async -> String? {
        // 1. Open Library Search (cover_i dell'opera)
        if let url = try? await openLibraryCoverURL(isbn: isbn, titolo: titolo, autore: autore) {
            return url
        }
        // 2. IBS — URL predicibile per ISBN, ottima copertura su libri italiani e scolastici
        let ibsURL = "https://img.ibs.it/images/\(isbn)_0_536_0_75.jpg"
        if await copertinaDimensioniOk(ibsURL) { return ibsURL }
        // 3. Gemini AI (senza grounding: verifica l'URL con copertinaDimensioniOk)
        let apiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return try? await geminiCopertina(titolo: titolo, autore: autore, isbn: isbn, apiKey: apiKey)
    }

    // Verifica che l'immagine sia reale (>10×10 px) e non un placeholder 1×1.
    private static func copertinaDimensioniOk(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString),
              let (data, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let img = NSImage(data: data),
              img.size.width > 10, img.size.height > 10 else { return false }
        return true
    }

    // Cerca la copertina tramite Open Library Search (cover_i = cover dell'opera, non dell'edizione).
    // Molto più affidabile di covers.openlibrary.org/b/isbn/ che restituisce spesso 1x1 placeholder.
    private static func openLibraryCoverURL(isbn: String, titolo: String, autore: String) async throws -> String? {
        let fields = "cover_i"

        // Prima prova: cerca per ISBN
        if let coverID = try await openLibrarySearchCoverID(query: "isbn=\(isbn)&fields=\(fields)") {
            return "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg"
        }

        // Seconda prova: titolo + primo autore (più autori separati da virgola confondono la ricerca)
        if !titolo.isEmpty {
            let primoAutore = autore.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
            let query = primoAutore.isEmpty ? titolo : "\(titolo) \(primoAutore)"
            if let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let coverID = try await openLibrarySearchCoverID(query: "q=\(q)&fields=\(fields)") {
                return "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg"
            }
        }
        return nil
    }

    private static func openLibrarySearchCoverID(query: String) async throws -> Int? {
        guard let url = URL(string: "https://openlibrary.org/search.json?\(query)&limit=1") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["docs"] as? [[String: Any]],
              let coverID = docs.first?["cover_i"] as? Int else { return nil }
        return coverID
    }

    // Chiede a Gemini di suggerire URL di copertina basandosi sulla sua base di addestramento.
    // Non usa Google Search grounding (richiede piano a pagamento); verifica ogni URL con copertinaDimensioniOk.
    private static func geminiCopertina(titolo: String, autore: String, isbn: String, apiKey: String) async throws -> String? {
        let modelli = ["gemini-2.5-flash-lite", "gemini-2.5-flash", "gemini-2.0-flash"]
        let prompt = """
            Il libro "\(titolo)" di \(autore) ha ISBN \(isbn).
            Elenca fino a 5 URL diretti di immagini di copertina (jpg o png) che potrebbero funzionare, basandoti su quello che conosci.
            Fonti tipiche: covers.openlibrary.org, img.ibs.it, images-na.ssl-images-amazon.com, sito dell'editore.
            Rispondi SOLO con gli URL, uno per riga, nessun altro testo.
            """
        let bodyObj: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["maxOutputTokens": 300, "temperature": 0]
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: bodyObj) else { return nil }

        for modello in modelli {
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/\(modello):generateContent?key=\(apiKey)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = bodyData
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let testo = parts.compactMap({ $0["text"] as? String }).first(where: { !$0.isEmpty })
            else { continue }

            // Estrai tutti gli URL dal testo e provali in parallelo
            let urlPattern = #"https?://[^\s\)\]\"',]+"#
            let candidati = testo.ranges(of: try! Regex(urlPattern)).map {
                String(testo[$0]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
            }
            // Verifica in parallelo — prende il primo che funziona
            let risultati = await withTaskGroup(of: (Int, String?).self) { group in
                for (i, c) in candidati.enumerated() {
                    group.addTask { await (i, copertinaDimensioniOk(c) ? c : nil) }
                }
                var trovati: [(Int, String)] = []
                for await (i, r) in group { if let r { trovati.append((i, r)) } }
                return trovati.sorted { $0.0 < $1.0 }.map(\.1)
            }
            if let first = risultati.first { return first }
        }
        return nil
    }

    // MARK: - Helpers

    private static func unisci(_ a: LibroLookup, _ b: LibroLookup) -> LibroLookup {
        LibroLookup(
            isbn: a.isbn,
            titolo: a.titolo.isEmpty ? b.titolo : a.titolo,
            autore: a.autore.isEmpty ? b.autore : a.autore,
            editore: a.editore.isEmpty ? b.editore : a.editore,
            anno: a.anno ?? b.anno,
            pagine: a.pagine ?? b.pagine,
            lingua: a.lingua.isEmpty ? b.lingua : a.lingua,
            genere: a.genere.isEmpty ? b.genere : a.genere,
            descrizione: a.descrizione.isEmpty ? b.descrizione : a.descrizione,
            copertinaURL: a.copertinaURL.isEmpty ? b.copertinaURL : a.copertinaURL,
            fonte: a.fonte
        )
    }
}

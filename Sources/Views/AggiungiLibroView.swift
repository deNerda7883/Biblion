import SwiftUI

struct AggiungiLibroView: View {
    @EnvironmentObject var store: LibroStore
    @Environment(\.dismiss) private var dismiss

    let posizioniSuggerite: [String]

    @State private var isbn: String = ""
    @State private var titolo: String = ""
    @State private var autore: String = ""
    @State private var editore: String = ""
    @State private var anno: String = ""
    @State private var pagine: String = ""
    @State private var lingua: String = ""
    @State private var genere: String = ""
    @State private var descrizione: String = ""
    @State private var copertinaURL: String = ""
    @State private var posizione: String = ""
    @State private var note: String = ""

    @State private var scannerAttivo: Bool = false
    @State private var lookupInCorso: Bool = false
    @State private var messaggio: MessaggioLookup?
    @State private var errore: String?
    @State private var posizioneErrore: Bool = false

    enum MessaggioLookup: Identifiable {
        case ok(fonte: String)
        case duplicato(titolo: String, posizione: String)
        case erroreApi(String)
        var id: String {
            switch self {
            case .ok(let f): return "ok-\(f)"
            case .duplicato(let t, _): return "dup-\(t)"
            case .erroreApi(let e): return "err-\(e)"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sezioneScanner
                    sezioneDettagli
                    sezionePosizione
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(minWidth: 640, idealWidth: 720, minHeight: 560, idealHeight: 720)
    }

    private var header: some View {
        HStack {
            Text("Aggiungi un libro").font(.title2.weight(.semibold))
            Spacer()
            Button("Annulla") { dismiss() }.keyboardShortcut(.escape)
        }
        .padding(20)
    }

    private var sezioneScanner: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("1. Scansiona il codice a barre (ISBN)", systemImage: "barcode.viewfinder")
                    .font(.headline)

                ScannerCard(attivo: $scannerAttivo) { codice in
                    isbn = codice
                    Task { await eseguiLookup() }
                }

                Text("Oppure digita l'ISBN a mano:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Es. 9788804668237", text: $isbn)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await eseguiLookup() } }
                    Button {
                        Task { await eseguiLookup() }
                    } label: {
                        if lookupInCorso {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Cerca info", systemImage: "magnifyingglass")
                        }
                    }
                    .disabled(isbn.isEmpty || lookupInCorso)
                }

                if let m = messaggio {
                    messaggioView(m)
                }
            }
            .padding(8)
        }
    }

    private var sezioneDettagli: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("2. Dettagli del libro", systemImage: "text.book.closed")
                    .font(.headline)

                campo("Titolo *", testo: $titolo)
                HStack {
                    campo("Autore", testo: $autore)
                    campo("Editore", testo: $editore)
                }
                HStack {
                    campo("Anno", testo: $anno)
                    campo("Pagine", testo: $pagine)
                    campo("Lingua", testo: $lingua)
                }
                campoGenere
                campo("URL copertina", testo: $copertinaURL)
                if !copertinaURL.isEmpty {
                    CopertinaImage(url: copertinaURL)
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Descrizione").font(.callout).foregroundStyle(.secondary)
                    TextEditor(text: $descrizione)
                        .font(.body)
                        .frame(minHeight: 80, maxHeight: 140)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3)))
                }
            }
            .padding(8)
        }
    }

    private var sezionePosizione: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("3. Posizione sulla libreria", systemImage: "mappin.and.ellipse")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Posizione *").font(.callout)
                        .foregroundStyle(posizioneErrore ? Color.red : Color.secondary)
                    TextField("Es. Studio · Scaffale 2 · Ripiano 3", text: $posizione)
                        .textFieldStyle(.roundedBorder)
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(posizioneErrore ? Color.red : Color.clear, lineWidth: 1.5))
                        .onChange(of: posizione) { _, v in if !v.isEmpty { posizioneErrore = false } }
                }

                if !posizioniSuggerite.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Già usate:").font(.caption).foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(posizioniSuggerite, id: \.self) { p in
                                    Button(p) { posizione = p }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Note personali").font(.callout).foregroundStyle(.secondary)
                    TextEditor(text: $note)
                        .font(.body)
                        .frame(minHeight: 60, maxHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3)))
                }
            }
            .padding(8)
        }
    }

    private var footer: some View {
        HStack {
            if let e = errore { Text(e).foregroundStyle(.red).font(.callout) }
            Spacer()
            Button("Annulla") { dismiss() }
            Button {
                salva()
            } label: {
                Label("Salva libro", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(20)
    }

    private var campoGenere: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Genere").font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField("Es. Narrativa, Saggistica…", text: $genere)
                    .textFieldStyle(.roundedBorder)
                Menu {
                    ForEach(Libro.generiSuggeriti, id: \.self) { g in
                        Button(g) { genere = g }
                    }
                } label: {
                    Image(systemName: "chevron.down.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Scegli un genere dalla lista")
            }
        }
    }

    private func campo(_ etichetta: String, testo: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(etichetta).font(.callout).foregroundStyle(.secondary)
            TextField(placeholder, text: testo)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func messaggioView(_ m: MessaggioLookup) -> some View {
        Group {
            switch m {
            case .ok(let fonte):
                if fonte == "Gemini AI" {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Risultato generato da Gemini AI — potrebbe essere impreciso. Verifica titolo e autore prima di salvare.")
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Trovato su \(fonte). Controlla i dati e imposta la posizione.")
                    }
                }
            case .duplicato(let t, let p):
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Già in libreria: \(t) (\(p))")
                }
            case .erroreApi(let e):
                HStack {
                    Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                    Text(e)
                }
            }
        }
        .font(.callout)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @MainActor
    private func eseguiLookup() async {
        errore = nil
        messaggio = nil

        let isbnPulito = BookLookup.pulisciISBN(isbn)
        guard isbnPulito.count == 10 || isbnPulito.count == 13 else {
            messaggio = .erroreApi("ISBN non valido (deve essere 10 o 13 cifre).")
            return
        }

        // Duplicato?
        if let esistente = store.cercaIsbn(isbnPulito) {
            messaggio = .duplicato(titolo: esistente.titolo, posizione: esistente.posizione)
            return
        }

        lookupInCorso = true
        defer { lookupInCorso = false }
        do {
            let r = try await BookLookup.cerca(isbn: isbnPulito)
            isbn = r.isbn
            titolo = r.titolo
            autore = r.autore
            editore = r.editore
            anno = r.anno.map(String.init) ?? ""
            pagine = r.pagine.map(String.init) ?? ""
            lingua = r.lingua
            if genere.isEmpty { genere = r.genere }
            descrizione = r.descrizione
            copertinaURL = r.copertinaURL
            messaggio = .ok(fonte: r.fonte)
        } catch let e as BookLookupError {
            messaggio = .erroreApi(e.errorDescription ?? "Errore lookup")
        } catch {
            messaggio = .erroreApi("Errore di connessione: \(error.localizedDescription)")
        }
    }

    private func salva() {
        errore = nil
        posizioneErrore = false
        let t = titolo.trimmingCharacters(in: .whitespaces)
        let p = posizione.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { errore = "Il titolo è obbligatorio."; return }
        if p.isEmpty { posizioneErrore = true; errore = "Inserisci una posizione prima di salvare."; return }

        let libro = Libro(
            isbn: BookLookup.pulisciISBN(isbn),
            titolo: t,
            autore: autore.trimmingCharacters(in: .whitespaces),
            editore: editore.trimmingCharacters(in: .whitespaces),
            anno: Int(anno),
            pagine: Int(pagine),
            lingua: lingua.trimmingCharacters(in: .whitespaces),
            genere: genere.trimmingCharacters(in: .whitespaces),
            descrizione: descrizione.trimmingCharacters(in: .whitespaces),
            copertinaURL: copertinaURL.trimmingCharacters(in: .whitespaces),
            posizione: p,
            note: note.trimmingCharacters(in: .whitespaces)
        )
        store.aggiungi(libro)
        dismiss()
    }
}

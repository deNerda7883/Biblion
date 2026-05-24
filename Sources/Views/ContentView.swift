import SwiftUI

// MARK: - Tipi

enum ModalitaVista: String, CaseIterable {
    case griglia  = "Griglia"
    case scaffale = "Scaffale"
    case tabella  = "Tabella"
}

enum Ordinamento: String, CaseIterable, Identifiable {
    case dataDesc  = "Più recenti"
    case dataAsc   = "Più vecchi"
    case titolo    = "Titolo"
    case autore    = "Autore"
    case posizione = "Posizione"
    var id: String { rawValue }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var store: LibroStore

    @State private var ricerca: String = ""
    @State private var filtroGenere: String = ""       // "" = tutto
    @State private var ordinamento: Ordinamento = .dataDesc
    @State private var modalita: ModalitaVista = .griglia
    @State private var libroSelezionato: Libro?
    @State private var mostraAggiungi: Bool = false
    @State private var mostraImpostazioni: Bool = false
    @State private var sidebar: NavigationSplitViewVisibility = .all

    var libriFiltrati: [Libro] {
        var r = store.libri
        if !ricerca.isEmpty {
            let q = ricerca.lowercased()
            r = r.filter {
                $0.titolo.lowercased().contains(q)
                || $0.autore.lowercased().contains(q)
                || $0.isbn.contains(q)
                || $0.editore.lowercased().contains(q)
            }
        }
        if !filtroGenere.isEmpty {
            if filtroGenere == "Senza genere" {
                r = r.filter { $0.genere.isEmpty }
            } else {
                r = r.filter { $0.genere == filtroGenere }
            }
        }
        switch ordinamento {
        case .dataDesc:  r.sort { $0.dataInserimento > $1.dataInserimento }
        case .dataAsc:   r.sort { $0.dataInserimento < $1.dataInserimento }
        case .titolo:    r.sort { $0.titolo.localizedCompare($1.titolo) == .orderedAscending }
        case .autore:    r.sort { $0.autore.localizedCompare($1.autore) == .orderedAscending }
        case .posizione: r.sort { $0.posizione.localizedCompare($1.posizione) == .orderedAscending }
        }
        return r
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebar) {
            SidebarView(
                filtroGenere: $filtroGenere,
                ricerca: $ricerca
            )
            .frame(minWidth: 220, idealWidth: 240)
        } detail: {
            VStack(spacing: 0) {
                toolbar
                Divider()
                if libriFiltrati.isEmpty {
                    VuotoView(haFiltri: !ricerca.isEmpty || !filtroGenere.isEmpty) {
                        mostraAggiungi = true
                    }
                } else {
                    Group {
                        switch modalita {
                        case .griglia:
                            GrigliaView(libri: libriFiltrati) { libroSelezionato = $0 }
                        case .scaffale:
                            ScaffaleView(libri: libriFiltrati) { libroSelezionato = $0 }
                        case .tabella:
                            TabellaView(libri: libriFiltrati, ordinamento: $ordinamento) {
                                libroSelezionato = $0
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $mostraAggiungi) {
            AggiungiLibroView(posizioniSuggerite: store.posizioniUniche)
                .environmentObject(store)
        }
        .sheet(item: $libroSelezionato) { libro in
            DettaglioLibroView(libro: libro, posizioniSuggerite: store.posizioniUniche)
                .environmentObject(store)
        }
        .sheet(isPresented: $mostraImpostazioni) {
            ImpostazioniView()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(titoloSezione).font(.headline)
                Text(sottotitoloSezione).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            // Ricerca
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.callout)
                TextField("Cerca titolo, autore, ISBN…", text: $ricerca)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 180, maxWidth: 260)
                if !ricerca.isEmpty {
                    Button { ricerca = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.black.opacity(0.08)))

            // Ordina
            Picker("", selection: $ordinamento) {
                ForEach(Ordinamento.allCases) { o in
                    Text(o.rawValue).tag(o)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 130)

            // Grid / Scaffale / Lista toggle
            Picker("", selection: $modalita) {
                Image(systemName: "square.grid.2x2").tag(ModalitaVista.griglia)
                Image(systemName: "books.vertical").tag(ModalitaVista.scaffale)
                Image(systemName: "list.bullet").tag(ModalitaVista.tabella)
            }
            .pickerStyle(.segmented)
            .frame(width: 96)

            // Impostazioni
            Button {
                mostraImpostazioni = true
            } label: {
                Label("Impostazioni", systemImage: "gearshape")
            }
            .help("Impostazioni")

            // Aggiungi
            Button {
                mostraAggiungi = true
            } label: {
                Label("Aggiungi", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: [.command])
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var titoloSezione: String {
        if !filtroGenere.isEmpty { return filtroGenere }
        if !ricerca.isEmpty { return "Risultati ricerca" }
        return "La mia libreria"
    }

    private var sottotitoloSezione: String {
        let n = libriFiltrati.count
        let tot = store.totale
        if n == tot { return "\(tot) libri" }
        return "\(n) di \(tot) libri"
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var store: LibroStore
    @Binding var filtroGenere: String
    @Binding var ricerca: String

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding<String?>(
                get: { filtroGenere.isEmpty ? nil : filtroGenere },
                set: { filtroGenere = $0 ?? "" }
            )) {
                Label("Tutta la libreria", systemImage: "books.vertical.fill")
                    .badge(store.totale)
                    .tag("")

                Section("Generi") {
                    ForEach(store.generiConConteggio) { voce in
                        HStack(spacing: 6) {
                            Image(systemName: iconaGenere(voce.nome))
                                .foregroundStyle(Tema.primario)
                                .frame(width: 16)
                                .font(.callout)
                            Text(voce.nome)
                                .lineLimit(1)
                            Spacer()
                            Text("\(voce.count)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .tag(voce.nome)
                    }
                }
            }
            .listStyle(.sidebar)

            statistiche
        }
    }

    private var statistiche: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            VStack(alignment: .leading, spacing: 5) {
                statRiga(icona: "books.vertical", label: "Totale libri",  valore: "\(store.totale)")
                statRiga(icona: "mappin.circle",  label: "Posizioni",     valore: "\(store.posizioniUniche.count)")
                if let u = store.ultimoAggiunto {
                    statRiga(icona: "clock", label: "Ultimo aggiunto",
                             valore: u.dataInserimento.formatted(.relative(presentation: .named)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    private func statRiga(icona: String, label: String, valore: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icona).frame(width: 14).foregroundStyle(.secondary).font(.caption)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(valore).font(.caption.weight(.medium))
        }
    }

    private func iconaGenere(_ genere: String) -> String {
        let g = genere.lowercased()
        if g.contains("narrativa") || g.contains("romanzo") || g.contains("racconto") { return "book" }
        if g.contains("giallo") || g.contains("thriller") || g.contains("horror")     { return "eyes" }
        if g.contains("fantasy") || g.contains("fantascienza")                        { return "sparkles" }
        if g.contains("storia") || g.contains("biografie") || g.contains("memorie")   { return "clock.arrow.circlepath" }
        if g.contains("filosofia") || g.contains("psicologia")                        { return "brain" }
        if g.contains("scienze")                                                       { return "flask" }
        if g.contains("economia") || g.contains("diritto") || g.contains("politica")  { return "chart.bar" }
        if g.contains("arte") || g.contains("musica") || g.contains("cinema")         { return "paintpalette" }
        if g.contains("cucina")                                                        { return "fork.knife" }
        if g.contains("viaggi")                                                        { return "map" }
        if g.contains("sport")                                                         { return "figure.run" }
        if g.contains("bambini") || g.contains("ragazzi")                              { return "star" }
        if g.contains("fumetti") || g.contains("graphic")                             { return "bubble.left.and.bubble.right" }
        if g.contains("poesia") || g.contains("teatro")                               { return "theatermasks" }
        if g.contains("saggistica")                                                    { return "doc.text" }
        if g.contains("senza genere")                                                  { return "questionmark.circle" }
        return "book.closed"
    }
}

// MARK: - Griglia

struct GrigliaView: View {
    let libri: [Libro]
    let onTap: (Libro) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)],
                spacing: 16
            ) {
                ForEach(libri) { libro in
                    CardLibro(libro: libro).onTapGesture { onTap(libro) }
                }
            }
            .padding(18)
        }
    }
}

struct CardLibro: View {
    let libro: Libro
    @EnvironmentObject var store: LibroStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Altezza fissa: tutte le card hanno la stessa copertina, cropping centrato
            CopertinaImage(url: libro.copertinaURL)
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 220)
                .clipped()

            VStack(alignment: .leading, spacing: 3) {
                Text(libro.titolo).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(libro.autore.isEmpty ? "—" : libro.autore)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: "mappin.circle.fill").font(.caption2)
                    Text(libro.posizione).lineLimit(1).font(.caption)
                }
                .foregroundStyle(Tema.primario)
                .padding(.top, 2)
            }
            .padding(10)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.black.opacity(0.07)))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        .contentShape(Rectangle())
        .task(id: libro.isbn) {
            guard libro.copertinaURL.isEmpty, !libro.isbn.isEmpty else { return }
            if let url = await BookLookup.fetchCopertinaURL(isbn: libro.isbn, titolo: libro.titolo, autore: libro.autore) {
                var aggiornato = libro
                aggiornato.copertinaURL = url
                store.aggiorna(aggiornato)
            }
        }
    }
}

// MARK: - Tabella

struct TabellaView: View {
    let libri: [Libro]
    @Binding var ordinamento: Ordinamento
    let onTap: (Libro) -> Void

    @State private var selezione: Libro.ID?

    var body: some View {
        Table(libri, selection: $selezione) {
            TableColumn("Copertina") { libro in
                CopertinaImage(url: libro.copertinaURL)
                    .frame(width: 32, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .width(44)

            TableColumn("Titolo") { libro in
                VStack(alignment: .leading, spacing: 1) {
                    Text(libro.titolo).fontWeight(.medium).lineLimit(2)
                    if !libro.autore.isEmpty {
                        Text(libro.autore).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }

            TableColumn("Posizione") { libro in
                Label(libro.posizione, systemImage: "mappin.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Tema.primario)
                    .lineLimit(1)
            }
            .width(min: 140, ideal: 200)

            TableColumn("Editore") { libro in
                Text(libro.editore).font(.callout).foregroundStyle(.secondary).lineLimit(1)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Anno") { libro in
                Text(libro.anno.map(String.init) ?? "—")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .width(50)

            TableColumn("ISBN") { libro in
                Text(libro.isbn).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 130)
        }
        .onChange(of: selezione) { _, newID in
            if let id = newID, let libro = libri.first(where: { $0.id == id }) {
                onTap(libro)
                selezione = nil
            }
        }
        .alternatingRowBackgrounds()
    }
}

// MARK: - Vista Scaffale

struct ScaffaleView: View {
    let libri: [Libro]
    let onTap: (Libro) -> Void

    private let legno      = Color(red: 0.55, green: 0.36, blue: 0.18)
    private let legnoChiaro = Color(red: 0.72, green: 0.52, blue: 0.30)
    private let sfondoScaffale = Color(red: 0.96, green: 0.91, blue: 0.82)

    // Raggruppa per lettera-scaffale, ordina per slot
    var scaffali: [(etichetta: String, libri: [Libro])] {
        var mappa: [String: [Libro]] = [:]
        for libro in libri {
            let lettera = scaffaleLettera(libro.posizione)
            mappa[lettera, default: []].append(libro)
        }
        return mappa
            .sorted { scaffaleOrdine($0.key) < scaffaleOrdine($1.key) }
            .map { (etichetta: $0.key, libri: $0.value.sorted { scaffaleSlot($0.posizione) < scaffaleSlot($1.posizione) }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                ForEach(scaffali, id: \.etichetta) { scaffale in
                    VStack(alignment: .leading, spacing: 0) {
                        // Intestazione scaffale
                        HStack {
                            Text(scaffale.etichetta)
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(legno)
                            Text("— \(scaffale.libri.count) \(scaffale.libri.count == 1 ? "libro" : "libri")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 24)
                        .padding(.bottom, 8)

                        // Pianale con libri
                        ZStack(alignment: .bottom) {
                            // Sfondo scaffale
                            RoundedRectangle(cornerRadius: 10)
                                .fill(sfondoScaffale)

                            VStack(spacing: 0) {
                                // Fila libri
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(alignment: .bottom, spacing: 3) {
                                        ForEach(scaffale.libri) { libro in
                                            SpinLibro(libro: libro)
                                                .onTapGesture { onTap(libro) }
                                        }
                                        Spacer(minLength: 16)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                                }

                                // Plancia di legno
                                ZStack {
                                    Rectangle()
                                        .fill(legno)
                                        .frame(height: 14)
                                    // Riflesso superiore
                                    Rectangle()
                                        .fill(legnoChiaro.opacity(0.4))
                                        .frame(height: 3)
                                        .frame(maxHeight: .infinity, alignment: .top)
                                        .frame(height: 14)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 3)
                    }
                }
            }
            .padding(.vertical, 24)
        }
    }

    // MARK: - Parsing posizione

    private func scaffaleLettera(_ pos: String) -> String {
        // Cerca lettera singola maiuscola seguita da separatore + numero (es. "L-6", "A-1")
        let cleaned = pos.trimmingCharacters(in: .whitespaces)
        if let m = cleaned.range(of: #"^([A-Za-z]+)"#, options: .regularExpression) {
            return String(cleaned[m]).uppercased()
        }
        // Fallback: prima parola
        return String(cleaned.prefix(while: { $0 != "-" && $0 != "·" && $0 != " " })).uppercased()
    }

    private func scaffaleSlot(_ pos: String) -> Int {
        // Estrae il primo numero trovato nella posizione
        if let m = pos.range(of: #"\d+"#, options: .regularExpression) {
            return Int(pos[m]) ?? 0
        }
        return 0
    }

    private func scaffaleOrdine(_ etichetta: String) -> String {
        // Ordine alfabetico, con numeri dopo le lettere
        let primo = etichetta.first
        if primo?.isLetter == true { return "0" + etichetta }
        return "1" + etichetta
    }
}

struct SpinLibro: View {
    let libro: Libro

    private static let palette: [Color] = [
        Color(red: 0.545, green: 0.227, blue: 0.180),
        Color(red: 0.18, green: 0.38, blue: 0.62),
        Color(red: 0.15, green: 0.50, blue: 0.30),
        Color(red: 0.60, green: 0.20, blue: 0.50),
        Color(red: 0.70, green: 0.45, blue: 0.10),
        Color(red: 0.20, green: 0.45, blue: 0.55),
        Color(red: 0.50, green: 0.25, blue: 0.10),
        Color(red: 0.30, green: 0.30, blue: 0.55),
    ]

    var colore: Color {
        let idx = abs(libro.titolo.hashValue) % Self.palette.count
        return Self.palette[idx]
    }

    // Larghezza dorso proporzionale alle pagine (min 22, max 52)
    var larghezza: CGFloat {
        guard let p = libro.pagine, p > 0 else { return 28 }
        return max(22, min(52, CGFloat(p) / 15))
    }

    var altezza: CGFloat { 180 }

    var body: some View {
        ZStack {
            // Corpo del libro
            if !libro.copertinaURL.isEmpty {
                CopertinaImage(url: libro.copertinaURL)
                    .frame(width: larghezza, height: altezza)
                    .clipped()
            } else {
                colore
                    .frame(width: larghezza, height: altezza)
            }

            // Titolo ruotato sul dorso
            Text(libro.titolo)
                .font(.system(size: max(8, larghezza * 0.28), weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: altezza - 24)
                .rotationEffect(.degrees(-90))
                .shadow(color: .black.opacity(0.6), radius: 1)
        }
        .frame(width: larghezza, height: altezza)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.25), radius: 3, x: 2, y: 2)
        .overlay(
            // Riflesso sinistro del dorso
            LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: larghezza * 0.3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        )
        .help("\(libro.titolo)\n\(libro.autore)")
    }
}

// MARK: - Vuoto

struct VuotoView: View {
    let haFiltri: Bool
    let onAggiungi: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: haFiltri ? "magnifyingglass" : "books.vertical")
                .font(.system(size: 56)).foregroundStyle(.tertiary)
            Text(haFiltri ? "Nessun libro corrisponde ai filtri." : "La tua libreria è vuota.")
                .font(.title3).foregroundStyle(.secondary)
            if !haFiltri {
                Button {
                    onAggiungi()
                } label: {
                    Label("Aggiungi il primo libro", systemImage: "plus").padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

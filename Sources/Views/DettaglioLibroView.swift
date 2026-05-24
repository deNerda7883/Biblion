import SwiftUI

struct DettaglioLibroView: View {
    @EnvironmentObject var store: LibroStore
    @Environment(\.dismiss) private var dismiss

    @State var libro: Libro
    let posizioniSuggerite: [String]

    @State private var inModifica: Bool = false
    @State private var confermaElimina: Bool = false
    @State private var annoTesto: String = ""
    @State private var pagineTesto: String = ""

    init(libro: Libro, posizioniSuggerite: [String]) {
        _libro = State(initialValue: libro)
        self.posizioniSuggerite = posizioniSuggerite
        _annoTesto = State(initialValue: libro.anno.map(String.init) ?? "")
        _pagineTesto = State(initialValue: libro.pagine.map(String.init) ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                if inModifica {
                    contenutoModifica
                } else {
                    contenutoLettura
                }
            }
            Divider()
            footer
        }
        .frame(minWidth: 640, idealWidth: 760, minHeight: 560, idealHeight: 700)
    }

    private var header: some View {
        HStack {
            Text(inModifica ? "Modifica libro" : libro.titolo)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
            Spacer()
            Button("Chiudi") { dismiss() }.keyboardShortcut(.escape)
        }
        .padding(20)
    }

    private var contenutoLettura: some View {
        HStack(alignment: .top, spacing: 24) {
            CopertinaImage(url: libro.copertinaURL)
                .frame(width: 220, height: 330)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 12) {
                Text(libro.titolo).font(.title.weight(.semibold))
                if !libro.autore.isEmpty {
                    Text("di \(libro.autore)").font(.title3).foregroundStyle(.secondary)
                }

                EtichettaPosizione(testo: libro.posizione).padding(.vertical, 4)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    if !libro.editore.isEmpty {
                        GridRow { Text("Editore").foregroundStyle(.secondary); Text(libro.editore) }
                    }
                    if let a = libro.anno {
                        GridRow { Text("Anno").foregroundStyle(.secondary); Text(String(a)) }
                    }
                    if let p = libro.pagine {
                        GridRow { Text("Pagine").foregroundStyle(.secondary); Text("\(p)") }
                    }
                    if !libro.lingua.isEmpty {
                        GridRow { Text("Lingua").foregroundStyle(.secondary); Text(libro.lingua) }
                    }
                    if !libro.genere.isEmpty {
                        GridRow { Text("Genere").foregroundStyle(.secondary); Text(libro.genere) }
                    }
                    if !libro.isbn.isEmpty {
                        GridRow { Text("ISBN").foregroundStyle(.secondary); Text(libro.isbn) }
                    }
                    GridRow {
                        Text("Inserito il").foregroundStyle(.secondary)
                        Text(libro.dataInserimento.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.callout)

                if !libro.descrizione.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Descrizione").font(.headline)
                        Text(libro.descrizione).foregroundStyle(.primary)
                    }
                }
                if !libro.note.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note personali").font(.headline)
                        Text(libro.note)
                            .padding(10)
                            .background(Color.yellow.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var contenutoModifica: some View {
        VStack(alignment: .leading, spacing: 14) {
            campo("Titolo *", $libro.titolo)
            HStack {
                campo("Autore", $libro.autore)
                campo("Editore", $libro.editore)
            }
            HStack {
                campo("Anno", $annoTesto)
                campo("Pagine", $pagineTesto)
                campo("Lingua", $libro.lingua)
            }
            campoGenereModifica
            campo("ISBN", $libro.isbn)
            campo("URL copertina", $libro.copertinaURL)
            campo("Posizione *", $libro.posizione, placeholder: "Es. Studio · Scaffale 2 · Ripiano 3")

            if !posizioniSuggerite.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(posizioniSuggerite, id: \.self) { p in
                            Button(p) { libro.posizione = p }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Descrizione").font(.callout).foregroundStyle(.secondary)
                TextEditor(text: $libro.descrizione)
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3)))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Note personali").font(.callout).foregroundStyle(.secondary)
                TextEditor(text: $libro.note)
                    .frame(minHeight: 60)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3)))
            }
        }
        .padding(20)
    }

    private var footer: some View {
        HStack {
            Button(role: .destructive) {
                confermaElimina = true
            } label: {
                Label("Elimina", systemImage: "trash")
            }
            .confirmationDialog(
                "Eliminare “\(libro.titolo)”?",
                isPresented: $confermaElimina,
                titleVisibility: .visible
            ) {
                Button("Elimina", role: .destructive) { elimina() }
                Button("Annulla", role: .cancel) { }
            }

            Spacer()

            if inModifica {
                Button("Annulla modifiche") {
                    if let originale = store.libri.first(where: { $0.id == libro.id }) {
                        libro = originale
                        annoTesto = originale.anno.map(String.init) ?? ""
                        pagineTesto = originale.pagine.map(String.init) ?? ""
                    }
                    inModifica = false
                }
                Button {
                    libro.anno = Int(annoTesto)
                    libro.pagine = Int(pagineTesto)
                    store.aggiorna(libro)
                    inModifica = false
                } label: {
                    Label("Salva", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    inModifica = true
                } label: {
                    Label("Modifica", systemImage: "pencil")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }

    private var campoGenereModifica: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Genere").font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField("Es. Narrativa, Saggistica…", text: $libro.genere)
                    .textFieldStyle(.roundedBorder)
                Menu {
                    ForEach(Libro.generiSuggeriti, id: \.self) { g in
                        Button(g) { libro.genere = g }
                    }
                } label: {
                    Image(systemName: "chevron.down.circle").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Scegli un genere dalla lista")
            }
        }
    }

    private func campo(_ etichetta: String, _ testo: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(etichetta).font(.callout).foregroundStyle(.secondary)
            TextField(placeholder, text: testo).textFieldStyle(.roundedBorder)
        }
    }

    private func elimina() {
        store.elimina(libro)
        dismiss()
    }
}

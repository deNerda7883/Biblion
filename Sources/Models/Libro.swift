import Foundation

struct Libro: Identifiable, Hashable {
    var id: UUID
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
    var posizione: String
    var note: String
    var dataInserimento: Date

    init(
        id: UUID = UUID(),
        isbn: String = "",
        titolo: String,
        autore: String = "",
        editore: String = "",
        anno: Int? = nil,
        pagine: Int? = nil,
        lingua: String = "",
        genere: String = "",
        descrizione: String = "",
        copertinaURL: String = "",
        posizione: String,
        note: String = "",
        dataInserimento: Date = .now
    ) {
        self.id = id
        self.isbn = isbn
        self.titolo = titolo
        self.autore = autore
        self.editore = editore
        self.anno = anno
        self.pagine = pagine
        self.lingua = lingua
        self.genere = genere
        self.descrizione = descrizione
        self.copertinaURL = copertinaURL
        self.posizione = posizione
        self.note = note
        self.dataInserimento = dataInserimento
    }
}

// Codable manuale per retrocompatibilità: i libri già salvati senza "genere" vengono
// deserializzati correttamente con genere = "".
extension Libro: Codable {
    enum CodingKeys: String, CodingKey {
        case id, isbn, titolo, autore, editore, anno, pagine, lingua, genere
        case descrizione, copertinaURL, posizione, note, dataInserimento
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try  c.decode(UUID.self,    forKey: .id)
        isbn             = try  c.decode(String.self,  forKey: .isbn)
        titolo           = try  c.decode(String.self,  forKey: .titolo)
        autore           = try  c.decode(String.self,  forKey: .autore)
        editore          = try  c.decode(String.self,  forKey: .editore)
        anno             = try? c.decode(Int.self,     forKey: .anno)
        pagine           = try? c.decode(Int.self,     forKey: .pagine)
        lingua           = (try? c.decode(String.self, forKey: .lingua))    ?? ""
        genere           = (try? c.decode(String.self, forKey: .genere))    ?? ""
        descrizione      = (try? c.decode(String.self, forKey: .descrizione)) ?? ""
        copertinaURL     = (try? c.decode(String.self, forKey: .copertinaURL)) ?? ""
        posizione        = try  c.decode(String.self,  forKey: .posizione)
        note             = (try? c.decode(String.self, forKey: .note))      ?? ""
        dataInserimento  = try  c.decode(Date.self,    forKey: .dataInserimento)
    }
}

// Generi standard suggeriti nell'interfaccia
extension Libro {
    static let generiSuggeriti: [String] = [
        "Narrativa", "Romanzo", "Racconto", "Poesia", "Teatro",
        "Giallo / Thriller", "Fantasy / Fantascienza", "Horror",
        "Saggistica", "Storia", "Filosofia", "Psicologia",
        "Scienze", "Economia", "Diritto", "Politica",
        "Arte / Architettura", "Musica", "Cinema",
        "Biografie / Memorie", "Viaggi", "Cucina",
        "Bambini / Ragazzi", "Fumetti / Graphic Novel",
        "Classici", "Religione / Spiritualità", "Sport"
    ]
}

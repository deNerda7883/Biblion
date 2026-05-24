# Biblion

**Biblion** è un'app macOS nativa per gestire la tua libreria personale fisica — scansiona un ISBN con la fotocamera, l'app trova automaticamente titolo, autore, editore e copertina, e salva il libro nella tua collezione.

![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Funzionalità

- **Scansione ISBN** tramite fotocamera integrata (o inserimento manuale)
- **Ricerca automatica** su Google Books, Open Library e catalogo SBN italiano
- **Copertine automatiche** da Open Library, IBS e Gemini AI — retroattiva anche sui libri già in libreria
- **Vista griglia, scaffale e tabella** con ordinamento e filtri per genere
- **Scaffale visivo** con dorsi colorati proporzionali alle pagine
- **Ricerca** per titolo, autore, ISBN o editore
- **Impostazioni API** per chiavi Google Books e Gemini con test di connessione integrato
- Salvataggio locale in JSON (`~/Library/Application Support/Biblion/`)

---

## Requisiti

| Requisito | Versione |
|-----------|----------|
| macOS | 14 Sonoma o superiore |
| Xcode Command Line Tools | qualsiasi versione recente |
| Swift | 5.9+ |

Installa i Command Line Tools se non li hai già:
```bash
xcode-select --install
```

---

## Build e installazione

```bash
git clone https://github.com/tuo-utente/biblion.git
cd biblion
bash build.sh
```

Lo script compila l'app, la firma con firma ad-hoc e la copia in `/Applications/Biblion.app`.

```bash
open /Applications/Biblion.app
```

---

## Chiavi API (opzionali ma consigliate)

Biblion funziona **senza nessuna chiave API** — usa le quote pubbliche di Google Books e Open Library. Se però aggiungi le chiavi personali ottieni molte più ricerche al giorno e risultati più affidabili.

Puoi inserire le chiavi da **Biblion → Impostazioni** (icona ingranaggio in alto a destra).

---

### Google Books API

La fonte principale per recuperare metadati (titolo, autore, editore, anno, copertina).

**Senza chiave:** quota condivisa, si esaurisce velocemente con uso intenso.  
**Con chiave:** 40.000 ricerche/giorno gratuite.

**Come ottenerla:**

1. Vai su [console.cloud.google.com](https://console.cloud.google.com/)
2. Crea un nuovo progetto (o selezionane uno esistente)
3. Vai su **API e servizi → Libreria** e cerca **"Books API"**
4. Clicca **Abilita**
5. Vai su **API e servizi → Credenziali → Crea credenziali → Chiave API**
6. Copia la chiave e incollala nelle Impostazioni di Biblion

> La chiave inizia con `AIzaSy…`

---

### Google Gemini API

Usata come **ultima risorsa** quando Google Books e Open Library non trovano il libro. Cerca anche le copertine per i libri non indicizzati su Open Library.

**Gratis:** 1.500 richieste/giorno con il piano gratuito.

**Come ottenerla:**

1. Vai su [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. Clicca **Crea chiave API**
3. Seleziona un progetto Google Cloud esistente (va bene lo stesso di Google Books)
4. Copia la chiave e incollala nelle Impostazioni di Biblion

> La chiave inizia con `AIza…`

> **Nota:** I risultati trovati tramite Gemini sono sempre segnalati con un avviso arancione nell'interfaccia. Verificali prima di salvare il libro.

---

## Fonti dati

Biblion interroga le seguenti fonti in parallelo e unisce i risultati:

| Fonte | Tipo | Note |
|-------|------|-------|
| **Google Books** | Metadati + copertina | Richiede chiave per uso intenso |
| **Open Library** | Metadati + copertina | Open source, ottima copertura mondiale |
| **SBN** | Metadati | Catalogo nazionale italiano — ottimo per libri italiani |
| **IBS** | Copertina | Libreria italiana, ottima per libri scolastici e di nicchia |
| **Gemini AI** | Metadati + copertina | Solo se le altre fonti falliscono |

---

## Struttura del progetto

```
biblion/
├── Sources/
│   ├── App/               # Entry point SwiftUI
│   ├── Models/            # Libro.swift
│   ├── Services/          # BookLookup.swift, LibroStore.swift
│   └── Views/             # ContentView, AggiungiLibroView, ecc.
├── Resources/
│   ├── Info.plist
│   ├── Libreria.entitlements
│   └── AppIcon.iconset/
├── build.sh               # Script di compilazione
└── README.md
```

---

## Dati e privacy

Tutti i dati sono salvati **esclusivamente in locale** su Mac:

```
~/Library/Application Support/Biblion/libreria.json
```

Nessun dato viene inviato a server propri. Le uniche connessioni di rete sono verso le API di terze parti elencate sopra (Google Books, Open Library, SBN, IBS, Gemini) per recuperare i metadati dei libri.

---

## Licenza

MIT — vedi [LICENSE](LICENSE) per i dettagli.

import SwiftUI

struct ImpostazioniView: View {
    @AppStorage("gemini_api_key") private var apiKey: String = ""
    @AppStorage("google_books_api_key") private var googleBooksKey: String = ""
    @State private var visibile: Bool = false
    @State private var visibileGoogle: Bool = false
    @State private var testInCorso: Bool = false
    @State private var risultatoTest: String? = nil
    @State private var testGoogleInCorso: Bool = false
    @State private var risultatoTestGoogle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Impostazioni").font(.title2.weight(.semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Google Books API — Fonte principale (consigliata)", systemImage: "books.vertical")
                        .font(.headline)

                    Text("Senza chiave l'app usa la quota condivisa, che si esaurisce presto. Con una chiave personale ottieni 40.000 ricerche/giorno gratuite. Ottieni la chiave su console.cloud.google.com (abilita \"Books API\").")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Group {
                            if visibileGoogle {
                                TextField("AIzaSy…", text: $googleBooksKey)
                            } else {
                                SecureField("AIzaSy…", text: $googleBooksKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                        Button { visibileGoogle.toggle() } label: {
                            Image(systemName: visibileGoogle ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(visibileGoogle ? "Nascondi" : "Mostra")
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task { await testGoogleBooks() }
                        } label: {
                            if testGoogleInCorso {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Testa connessione")
                            }
                        }
                        .disabled(googleBooksKey.trimmingCharacters(in: .whitespaces).isEmpty || testGoogleInCorso)

                        if let r = risultatoTestGoogle {
                            Text(r)
                                .font(.callout)
                                .foregroundStyle(r.hasPrefix("✓") ? Color.green : Color.red)
                        }

                        Spacer()

                        Link("Ottieni API key gratuita →", destination: URL(string: "https://console.cloud.google.com/apis/library/books.googleapis.com")!)
                            .font(.callout)
                    }
                }
                .padding(8)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Google Gemini AI — Ultima risorsa (potrebbe dare risultati imprecisi)", systemImage: "sparkles")
                        .font(.headline)

                    Text("Usato solo se tutte le altre fonti falliscono. Gratuito fino a 1500 ricerche al giorno. I risultati Gemini sono sempre segnalati con un avviso — verificali prima di salvare.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Group {
                            if visibile {
                                TextField("AIza…", text: $apiKey)
                            } else {
                                SecureField("AIza…", text: $apiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                        Button {
                            visibile.toggle()
                        } label: {
                            Image(systemName: visibile ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(visibile ? "Nascondi" : "Mostra")
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task { await testAPI() }
                        } label: {
                            if testInCorso {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Testa connessione")
                            }
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty || testInCorso)

                        if let r = risultatoTest {
                            Text(r)
                                .font(.callout)
                                .foregroundStyle(r.hasPrefix("✓") ? Color.green : Color.red)
                        }

                        Spacer()

                        Link("Ottieni API key gratuita →", destination: URL(string: "https://aistudio.google.com/apikey")!)
                            .font(.callout)
                    }
                }
                .padding(8)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 520, height: 420)
    }

    private func testGoogleBooks() async {
        testGoogleInCorso = true
        risultatoTestGoogle = nil
        defer { testGoogleInCorso = false }

        let chiave = googleBooksKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://www.googleapis.com/books/v1/volumes?q=isbn:9780140449136&maxResults=1&key=\(chiave)") else { return }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse else { return }
            if http.statusCode == 200 {
                risultatoTestGoogle = "✓ Connessione riuscita"
            } else {
                // Mostra il messaggio esatto di Google
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                    .flatMap { $0["error"] as? [String: Any] }
                    .flatMap { $0["message"] as? String } ?? "Errore \(http.statusCode)"
                risultatoTestGoogle = "✗ \(msg)"
            }
        } catch {
            risultatoTestGoogle = "✗ Rete: \(error.localizedDescription)"
        }
    }

    private func testAPI() async {
        testInCorso = true
        risultatoTest = nil
        defer { testInCorso = false }

        let chiave = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelli = ["gemini-2.5-flash-lite", "gemini-2.0-flash-lite-001", "gemini-2.5-flash"]
        let body = "{\"contents\":[{\"parts\":[{\"text\":\"ping\"}]}],\"generationConfig\":{\"maxOutputTokens\":5}}"

        for modello in modelli {
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/\(modello):generateContent?key=\(chiave)") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = body.data(using: .utf8)
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                let corpo = String(data: data, encoding: .utf8) ?? ""
                print("[Gemini Test] \(modello) → \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    risultatoTest = "✓ Connessione riuscita (\(modello))"
                    return
                } else if corpo.contains("API_KEY_INVALID") || corpo.contains("401") {
                    risultatoTest = "✗ API key non valida"
                    return
                }
                // 503 o 404 → prova il prossimo modello
            } catch {
                risultatoTest = "✗ Rete: \(error.localizedDescription)"; return
            }
        }
        risultatoTest = "✗ Nessun modello disponibile al momento, riprova tra qualche minuto"
    }
}

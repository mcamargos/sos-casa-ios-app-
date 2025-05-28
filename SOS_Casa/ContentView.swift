import SwiftUI
import CoreLocation
import MapKit

struct ContentView: View { // <<< INÍCIO: ContentView struct
    @State private var selectedService: String? = nil
    @State private var providers: [Provider] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -15.80, longitude: -47.88), // Posição inicial (Ex: Brasília)
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // Zoom inicial
    )
    @State private var userLocation: CLLocationCoordinate2D? = nil
    @StateObject private var locationManager = LocationManager()

    @State private var selectedProvider: Provider? = nil // Profissional selecionado para exibir no topo
    @State private var bottomSheetHeight: SheetHeight = .hidden // Controla apenas a visibilidade da lista no bottom sheet

    let services = ["Encanador", "Eletricista", "Faxineira", "Chaveiro", "Marceneiro", "Pedreiro", "Doméstica", "Jardineiro", "Pintor", "Técnico de Ar Condicionado", "Montador de Móveis", "Limpeza de Estofados", "Diarista", "Marmorista"]

    // Definindo a altura da barra inferior de serviços
    let serviceBarHeight: CGFloat = 70

    // MARK: - View Principal (body)
    var body: some View { // <<< INÍCIO: ContentView body
        NavigationView {
            ZStack(alignment: .bottom) {
                mapSection // Mapa
                
                serviceSelectionBottomBar // Seleção de serviço na barra inferior
                    .zIndex(1)

                bottomSheetSection // Bottom Sheet (agora só para a lista de resultados)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    } // <<< FIM: ContentView body

    // MARK: - Propriedades Computadas para Seções da UI

    private var mapSection: some View { // <<< INÍCIO: mapSection
        Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: providers) { provider in
            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: provider.latitude, longitude: provider.longitude)) {
                ProviderMapAnnotationView(provider: provider, isSelected: selectedProvider?.id == provider.id)
                    .onTapGesture {
                        selectedProvider = provider // Seleciona o profissional para o card do topo
                        bottomSheetHeight = .collapsed // Mostra a lista se estava escondida
                    }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.lastLocation) { newLocation in
            if let location = newLocation {
                region.center = location.coordinate
                userLocation = location.coordinate
                if selectedService == nil || providers.isEmpty {
                    region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                }
            }
        }
        .overlay(alignment: .bottom) { // Indicador de carregamento
            if isLoading {
                ProgressView("Buscando profissionais...")
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .offset(y: -serviceBarHeight - 10)
            }
        }
        .overlay(alignment: .topLeading) { // Mensagem de erro
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.top, 50)
                    .padding(.leading, 10)
            }
        }
        // >>> NOVO: Card de detalhes do profissional no TOPO do mapa
        .overlay(alignment: .top) {
            if let provider = selectedProvider {
                VStack {
                    ProviderDetailContentTop(provider: provider) // Nova view para o card do topo
                        .background(Color.white.opacity(0.95))
                        .cornerRadius(15)
                        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    Spacer()
                }
                .transition(.move(edge: .top)) // Animação de entrada
                .animation(.spring(), value: selectedProvider?.id) // Animação ao mudar de provedor
            }
        }
    } // <<< FIM: mapSection

    private var serviceSelectionBottomBar: some View { // <<< INÍCIO: serviceSelectionBottomBar
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(services, id: \.self) { service in
                        Button(action: {
                            selectedService = service
                            searchProviders(service: service)
                            selectedProvider = nil // Limpa o card do topo ao iniciar nova busca
                            bottomSheetHeight = .collapsed // Mostra a lista de resultados embaixo
                        }) {
                            Text(service)
                                .font(.headline)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 10)
                                .background(selectedService == service ? Color.blue.opacity(0.9) : Color.white)
                                .foregroundColor(selectedService == service ? .white : .blue)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: serviceBarHeight)
            .background(Color.white.shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: -2))
            .cornerRadius(15)
            .ignoresSafeArea(edges: .bottom)
        }
        .offset(y: -bottomSheetHeight.rawValue)
        .animation(.spring(), value: bottomSheetHeight)
    } // <<< FIM: serviceSelectionBottomBar

    private var bottomSheetSection: some View { // <<< INÍCIO: bottomSheetSection
        BottomSheetView(currentHeight: $bottomSheetHeight) {
            // Este bottom sheet agora conterá SOMENTE a lista de resultados
            if !providers.isEmpty {
                ProviderListContent(providers: providers, selectedProvider: $selectedProvider, bottomSheetHeight: $bottomSheetHeight)
            } else if selectedService != nil && !isLoading && errorMessage == nil {
                Text("Nenhum profissional encontrado para '\(selectedService ?? "")'.")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        // A altura máxima do sheet será agora apenas a altura colapsada, não a expandida
        .offset(y: calculateBottomSheetYOffset() - serviceBarHeight)
        .animation(.spring(), value: bottomSheetHeight)
    } // <<< FIM: bottomSheetSection

    private func calculateBottomSheetYOffset() -> CGFloat { // <<< INÍCIO: calculateBottomSheetYOffset
        let screenHeight = UIScreen.main.bounds.height
        // O sheet agora só tem duas posições: escondido ou colapsado
        switch bottomSheetHeight {
        case .hidden:
            return screenHeight
        case .collapsed:
            return screenHeight - SheetHeight.collapsed.rawValue
        case .expanded: // Esta altura não será mais usada para o conteúdo principal
            return screenHeight // Ou poderia ser SheetHeight.collapsed.rawValue se expandido não existe
        }
    } // <<< FIM: calculateBottomSheetYOffset

    // MARK: - Funções de Rede e Lógica

    func searchProviders(service: String) { // <<< INÍCIO: searchProviders
        isLoading = true
        errorMessage = nil
        providers = []
        selectedProvider = nil // Limpa seleção ao buscar novo serviço

        let latToUse = locationManager.lastLocation?.coordinate.latitude ?? -15.80
        let lonToUse = locationManager.lastLocation?.coordinate.longitude ?? -47.88

        let baseUrl = "http://127.0.0.1:5000"

        guard let url = URL(string: "\(baseUrl)/api/providers/search?service=\(service)&lat=\(latToUse)&lon=\(lonToUse)") else {
            errorMessage = "URL inválida."
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    print("Erro na requisição: \(error.localizedDescription)")
                    errorMessage = "Erro ao buscar: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    print("Resposta inválida do servidor. Status: \(statusCode)")
                    errorMessage = "Resposta inválida do servidor. Status: \(statusCode)"
                    return
                }

                guard let data = data else {
                    errorMessage = "Dados não recebidos."
                    return
                }

                do {
                    let decodedProviders = try JSONDecoder().decode([Provider].self, from: data)
                    self.providers = decodedProviders
                    if decodedProviders.isEmpty {
                        errorMessage = "Nenhum profissional encontrado para '\(service)'."
                    } else {
                        errorMessage = nil
                        if let firstProvider = decodedProviders.first {
                            region.center = CLLocationCoordinate2D(latitude: firstProvider.latitude, longitude: firstProvider.longitude)
                            region.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                        }
                    }
                } catch {
                    print("Erro ao decodificar JSON: \(error.localizedDescription)")
                    errorMessage = "Erro ao processar dados."
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("JSON Inválido Recebido:\n\(jsonString)")
                    }
                }
            }
        }.resume()
    } // <<< FIM: searchProviders
} // <<< FIM: ContentView struct

// MARK: - Estrutura de Dados (Codable)
struct Provider: Codable, Identifiable { // <<< INÍCIO: Provider struct
    let id: Int
    let nome: String
    let servico: String
    let latitude: Double
    let longitude: Double
    let contato: String?
    let disponivel: Int?
    let distancia_km: Double?
    let avaliacoes: Int?

    var isAvailable: Bool {
        return disponivel == 1
    }
} // <<< FIM: Provider struct


// MARK: - Vistas Auxiliares para o Design (EXISTENTES E NOVAS)

struct ProviderMapAnnotationView: View { // <<< INÍCIO: ProviderMapAnnotationView struct
    let provider: Provider
    let isSelected: Bool

    var body: some View { // <<< INÍCIO: body
        VStack {
            Image(systemName: "mappin.and.ellipse.circle.fill")
                .font(isSelected ? .largeTitle : .title)
                .foregroundColor(isSelected ? .blue : .red)
                .shadow(radius: isSelected ? 5 : 2)

            if isSelected {
                Text(provider.nome)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(5)
                    .offset(y: -5)
            }
        }
    } // <<< FIM: body
} // <<< FIM: ProviderMapAnnotationView struct

// NOVA VISTA: Conteúdo Detalhado do Profissional para Exibição no TOPO
struct ProviderDetailContentTop: View { // <<< INÍCIO: ProviderDetailContentTop struct
    let provider: Provider

    var body: some View { // <<< INÍCIO: body
        VStack(alignment: .leading, spacing: 10) {
            // Cabeçalho com nome e serviço
            Text(provider.nome)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(provider.servico)
                .font(.headline)
                .foregroundColor(.secondary)

            Divider()

            // Detalhes em duas colunas (usando HStack com Spacers)
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: provider.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(provider.isAvailable ? .green : .red)
                        Text(provider.isAvailable ? "Disponível Agora" : "Indisponível")
                            .font(.subheadline)
                    }
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                        Text("★ \(provider.avaliacoes ?? 0) Avaliações")
                            .font(.subheadline)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Distância: \(provider.distancia_km ?? 0.0, specifier: "%.2f") km")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("Contato: \(provider.contato ?? "N/A")")
                        .font(.subheadline)
                        .foregroundColor(.blue) // Pra parecer clicável
                        .onTapGesture {
                            if let contato = provider.contato {
                                print("Tentando contatar: \(contato)")
                            }
                        }
                }
            }
            .padding(.bottom, 10)

            // Botão "Solicitar Serviço"
            Button(action: {
                print("Solicitar serviço de \(provider.nome)")
            }) {
                Label("Solicitar Serviço", systemImage: "hand.raised.fill")
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding(15) // Padding interno do card
    } // <<< FIM: body
} // <<< FIM: ProviderDetailContentTop struct


struct ProviderDetailContent: View { // <<< INÍCIO: ProviderDetailContent struct
    // REMOVIDA A LOGICA DO HANDLE, POIS ESTA NO BOTTOMSHEETVIEW PAI
    let provider: Provider

    var body: some View { // <<< INÍCIO: body
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                Text(provider.nome)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(provider.servico)
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: provider.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(provider.isAvailable ? .green : .red)
                    Text(provider.isAvailable ? "Disponível Agora" : "Indisponível")
                        .font(.headline)
                    Spacer()
                    Text("Distância: \(provider.distancia_km ?? 0.0, specifier: "%.2f") km")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .padding(.bottom, 10)

                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                    Text("★ \(provider.avaliacoes ?? 0) Avaliações")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.bottom, 10)

                Divider()

                Text("Informações de Contato:")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(provider.contato ?? "Contato não informado")
                    .font(.body)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        if let contato = provider.contato {
                            print("Tentando contatar: \(contato)")
                        }
                    }
                .padding(.bottom, 10)

                Spacer() // Empurra o botão para baixo

                Button(action: {
                    print("Solicitar serviço de \(provider.nome)")
                }) {
                    Label("Solicitar Serviço", systemImage: "hand.raised.fill")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        } // <<< FIM: ScrollView
    } // <<< FIM: body
} // <<< FIM: ProviderDetailContent struct

struct ProviderListContent: View { // <<< INÍCIO: ProviderListContent struct
    let providers: [Provider]
    @Binding var selectedProvider: Provider?
    @Binding var bottomSheetHeight: SheetHeight

    var body: some View { // <<< INÍCIO: body
        VStack(alignment: .leading, spacing: 10) {
            Text("Profissionais Próximos:")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 5)
                .foregroundColor(.primary)

            ScrollView {
                ForEach(providers, id: \.id) { provider in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(provider.nome)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text(provider.servico)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Text("Distância: \(provider.distancia_km ?? 0.0, specifier: "%.2f") km")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: provider.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(provider.isAvailable ? .green : .red)
                            Text(provider.isAvailable ? "Disponível" : "Indisponível")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text("★ \(provider.avaliacoes ?? 0) Avaliações")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                    .onTapGesture {
                        selectedProvider = provider
                        // Removida a expansão do sheet para cá, pois o card detalhe é no topo
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    } // <<< FIM: body
} // <<< FIM: ProviderListContent struct


// MARK: - Preview (Apenas para visualização no Xcode)
#Preview {
    ContentView()
}

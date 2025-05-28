import SwiftUI

// Define as alturas possíveis para o Bottom Sheet
enum SheetHeight: CGFloat, CaseIterable {
    case hidden = 0
    case collapsed = 200 // Altura para mostrar a lista de profissionais
    case expanded = 500 // Altura para mostrar detalhes de um profissional selecionado
    // Você pode ajustar esses valores ou adicionar mais, dependendo da tela
}

struct BottomSheetView<Content: View>: View {
    @Binding var currentHeight: SheetHeight // Altura atual do sheet
    let content: Content // Conteúdo que será exibido no sheet

    // Adiciona o drag gesture para arrastar o sheet
    @GestureState private var translation: CGFloat = 0

    init(currentHeight: Binding<SheetHeight>, @ViewBuilder content: () -> Content) {
        self._currentHeight = currentHeight
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // "Handle" para arrastar
                Capsule()
                    .frame(width: 40, height: 5)
                    .foregroundColor(Color.gray.opacity(0.5))
                    .padding(.bottom, 8)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .center)

                // Conteúdo principal do sheet
                self.content
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // <<< Garante que o conteúdo ocupe o espaço
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(.systemBackground)) // Fundo do sheet
            .cornerRadius(20) // Cantos arredondados
            .shadow(radius: 10) // Sombra
            .offset(y: geometry.size.height - self.currentHeight.rawValue + self.translation) // Posição vertical
            .animation(.interactiveSpring(), value: self.currentHeight) // Animação ao mudar de altura
            .animation(.interactiveSpring(), value: self.translation) // Animação ao arrastar
            .gesture(
                DragGesture().updating(self.$translation) { value, state, _ in
                    state = value.translation.height // Atualiza a translação enquanto arrasta
                }.onEnded { value in
                    // Lógica para definir a nova altura quando o arrasto termina
                    let snapThreshold: CGFloat = 0.2 * geometry.size.height // 20% da tela como threshold
                    let endHeight = geometry.size.height - (self.currentHeight.rawValue + value.translation.height)
                    
                    if value.translation.height > snapThreshold { // Arrasta para baixo
                        self.currentHeight = .hidden
                    } else if value.translation.height < -snapThreshold { // Arrasta para cima
                        self.currentHeight = .expanded
                    } else { // Retorna para a altura anterior ou para a mais próxima
                        let finalHeight = self.currentHeight.rawValue - value.translation.height
                        if finalHeight > SheetHeight.expanded.rawValue {
                            self.currentHeight = .expanded
                        } else if finalHeight > SheetHeight.collapsed.rawValue && finalHeight <= SheetHeight.expanded.rawValue {
                            self.currentHeight = .collapsed
                        } else {
                            self.currentHeight = .hidden
                        }
                    }
                }
            )
        }
        .ignoresSafeArea(.all, edges: .bottom) // Faz o sheet não respeitar a área segura inferior
    }
}

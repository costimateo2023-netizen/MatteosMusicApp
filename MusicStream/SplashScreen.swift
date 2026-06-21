import SwiftUI

struct SplashScreen: View {
    @State private var isActive = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        if isActive {
            ContentView()
                .preferredColorScheme(.dark)
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    Text("Matteo's Music App")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .scaleEffect(scale)
                .opacity(opacity)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    scale = 1.0
                    opacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeIn(duration: 0.4)) {
                        isActive = true
                    }
                }
            }
        }
    }
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.01)
            
            if appState.isTracking {
                GazeIndicator(point: appState.gazePoint)
            }
            
            if appState.isProcessing {
                ProcessingIndicator()
            }
            
            if let intent = appState.lastIntent {
                IntentResultView(intent: intent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

struct GazeIndicator: View {
    let point: CGPoint
    
    var body: some View {
        Circle()
            .stroke(Color.cyan.opacity(0.8), lineWidth: 3)
            .frame(width: 80, height: 80)
            .background(Circle().fill(Color.cyan.opacity(0.2)))
            .position(point)
            .animation(.easeOut(duration: 0.1), value: point)
    }
}

struct ProcessingIndicator: View {
    @State private var rotation = 0.0
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.orange, lineWidth: 4)
            .frame(width: 60, height: 60)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct IntentResultView: View {
    let intent: ResolvedIntent
    
    var body: some View {
        VStack(spacing: 8) {
            Text(intent.action)
                .font(.headline)
                .foregroundColor(.white)
            Text(intent.target)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("\(Int(intent.confidence * 100))% confidence")
                .font(.caption)
                .foregroundColor(intent.confidence > 0.7 ? .green : .orange)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.8)))
        .position(x: NSScreen.main?.frame.width ?? 800 / 2, y: 100)
    }
}

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            Toggle("Eye Tracking", isOn: $appState.isTracking)
            
            Divider()
            
            if !appState.lastTranscript.isEmpty {
                Text(appState.lastTranscript)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 200)
    }
}

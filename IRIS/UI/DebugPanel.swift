import SwiftUI

struct DebugPanel: View {
    @ObservedObject var coordinator: IRISCoordinator
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("I.R.I.S Debug")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            
            if isExpanded {
                Divider().background(Color.gray)
                
                Group {
                    HStack {
                        Circle()
                            .fill(coordinator.isActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(coordinator.isActive ? "Active" : "Inactive")
                    }
                    
                    Text("State: \(String(describing: coordinator.currentState))")
                    Text("Gaze: (\(Int(coordinator.gazeEstimator.gazePoint.x)), \(Int(coordinator.gazeEstimator.gazePoint.y)))")
                    
                    if !coordinator.speechService.transcript.isEmpty {
                        Text("Speech: \(coordinator.speechService.transcript)")
                            .lineLimit(2)
                    }
                    
                    if let intent = coordinator.lastIntent {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Intent:")
                                .fontWeight(.semibold)
                            Text("→ \(intent.action)")
                            Text("→ \(intent.target)")
                            Text("→ \(Int(intent.confidence * 100))%")
                        }
                    }
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                
                Divider().background(Color.gray)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(coordinator.debugLog.suffix(10), id: \.self) { line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .frame(maxHeight: 100)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.85)))
        .frame(width: 280)
    }
}

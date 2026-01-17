import SwiftUI

struct IRISSettingsPanel: View {
    @EnvironmentObject var coordinator: IRISCoordinator
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(coordinator.gazeEstimator.isTrackingEnabled ? 
                          IRISProductionColors.settingsIndicatorOn : 
                          IRISProductionColors.settingsIndicatorOff)
                    .frame(width: 8, height: 8)
                    .shadow(color: (coordinator.gazeEstimator.isTrackingEnabled ? 
                                    IRISProductionColors.settingsIndicatorOn : 
                                    IRISProductionColors.settingsIndicatorOff).opacity(0.5), radius: 4)
                
                Text("I.R.I.S CONTROLS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
            }
            .padding(.bottom, 4)

            // Gaze Indicator Toggle
            ToggleRow(
                title: "GAZE INDICATOR",
                isOn: Binding(
                    get: { coordinator.showGazeIndicator },
                    set: { coordinator.showGazeIndicator = $0 }
                )
            )

            // Snapping Toggle
            ToggleRow(
                title: "SMART SNAPPING",
                isOn: Binding(
                    get: { coordinator.snapIndicatorToElement },
                    set: { coordinator.snapIndicatorToElement = $0 }
                )
            )

            // Camera Picker
            if !coordinator.availableCameras.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 6) {
                    Text("CAMERA")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))

                    ForEach(coordinator.availableCameras) { cam in
                        CameraRow(
                            name: cam.name,
                            index: cam.id,
                            isSelected: cam.id == coordinator.selectedCameraIndex,
                            onSelect: { coordinator.switchCamera(to: cam.id) }
                        )
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 220)
        .background(
            ZStack {
                // Liquid glass background
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.4))
                
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3)) {
                isHovered = hovering
            }
        }
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            // Custom minimal toggle
            Button(action: { isOn.toggle() }) {
                ZStack {
                    Capsule()
                        .fill(isOn ? IRISProductionColors.trackingEnabledAccent.opacity(0.3) : Color.white.opacity(0.1))
                        .frame(width: 32, height: 16)

                    Circle()
                        .fill(isOn ? IRISProductionColors.trackingEnabledAccent : Color.white.opacity(0.5))
                        .frame(width: 12, height: 12)
                        .offset(x: isOn ? 8 : -8)
                        .shadow(color: isOn ? IRISProductionColors.trackingEnabledAccent.opacity(0.6) : .clear, radius: 4)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct CameraRow: View {
    let name: String
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? IRISProductionColors.trackingEnabledAccent : Color.white.opacity(0.15))
                    .frame(width: 6, height: 6)
                    .shadow(color: isSelected ? IRISProductionColors.trackingEnabledAccent.opacity(0.6) : .clear, radius: 3)

                Text(shortCameraName(name))
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular, design: .monospaced))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .white.opacity(0.45))
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Text("✓")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(IRISProductionColors.trackingEnabledAccent)
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func shortCameraName(_ name: String) -> String {
        // Shorten common camera names for compact display
        var short = name
            .replacingOccurrences(of: " (Built-in)", with: "")
            .replacingOccurrences(of: " (built-in)", with: "")
            .replacingOccurrences(of: "FaceTime HD Camera", with: "FaceTime HD")
        if short.count > 24 {
            short = String(short.prefix(22)) + "…"
        }
        return short
    }
}

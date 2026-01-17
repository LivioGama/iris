import SwiftUI
import IRISCore

/// View for configuring the Gemini API key
struct APIKeyConfigView: View {
    @State private var apiKey: String = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @FocusState private var isTextFieldFocused: Bool

    var onKeySaved: () -> Void

    private var isValidAPIKey: Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        // Gemini API keys start with "AIza" and are typically 39 characters long
        let isValid = !trimmed.isEmpty && trimmed.hasPrefix("AIza") && trimmed.count >= 30
        print("🔑 API Key validation: isEmpty=\(trimmed.isEmpty), length=\(trimmed.count), hasPrefix=\(trimmed.hasPrefix("AIza")), isValid=\(isValid)")
        return isValid
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)

                Text("Gemini API Key Required")
                    .font(.headline)

                Text("Enter your API key to enable AI features")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            // Input field
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                NSTextFieldWrapper(text: $apiKey, placeholder: "AIza...", isEnabled: !isSaving)
                    .frame(height: 22)

                Link("Get API Key from Google AI Studio",
                     destination: URL(string: "https://aistudio.google.com/apikey")!)
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            // Success/Error messages
            if showSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("API key saved successfully!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .transition(.opacity)
            }

            if showError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .transition(.opacity)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    apiKey = ""
                }
                .disabled(isSaving)

                Button("Save") {
                    saveAPIKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidAPIKey || isSaving)
            }
        }
        .padding()
        .frame(width: 380)
        .onAppear {
            // Auto-focus the text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }

    private func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            showErrorMessage("API key cannot be empty")
            return
        }

        // Validate Gemini API key format
        // Google API keys (including Gemini) start with "AIza" and are typically 39 characters
        guard trimmedKey.hasPrefix("AIza") else {
            showErrorMessage("Invalid API key format. Google API keys start with 'AIza'")
            return
        }

        guard trimmedKey.count >= 30 else {
            showErrorMessage("API key is too short. Google API keys are typically 39 characters")
            return
        }

        isSaving = true
        showError = false
        showSuccess = false

        Task {
            do {
                try KeychainService.shared.saveAPIKey(trimmedKey)

                await MainActor.run {
                    isSaving = false
                    showSuccess = true

                    // Clear success message and notify parent after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onKeySaved()
                        apiKey = ""
                        showSuccess = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    showErrorMessage("Failed to save: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true

        // Auto-hide error after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showError = false
        }
    }
}

// MARK: - Preview
#Preview {
    APIKeyConfigView(onKeySaved: {})
}

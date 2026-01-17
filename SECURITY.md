# IRIS Security Documentation

## Phase 1: API Key Security (Completed)

### Overview
All Gemini API keys are now stored securely in the macOS Keychain instead of being hardcoded in source files or environment variables.

### Implementation

#### 1. KeychainService (`IRIS/Services/KeychainService.swift`)
A secure service that manages API key storage using the macOS Security framework:
- Stores keys in the system Keychain with service identifier: `com.iris.gemini`
- Uses `kSecAttrAccessibleAfterFirstUnlock` for availability after first device unlock
- Provides methods: `saveAPIKey()`, `getAPIKey()`, `deleteAPIKey()`, `hasAPIKey()`

#### 2. Service Integration
Both `GeminiAssistantService` and `SentimentAnalysisService` have been updated to:
- First attempt to retrieve API key from Keychain
- Fallback to environment variable `GEMINI_API_KEY` for backwards compatibility
- No hardcoded API keys anywhere in the codebase

#### 3. Setup Script (`scripts/setup_api_key.sh`)
Interactive script to securely configure the API key:
```bash
./scripts/setup_api_key.sh
```

Features:
- Prompts user for API key securely (hidden input)
- Stores key in macOS Keychain
- Detects and offers to replace existing keys
- Validates input before storage

### Security Verification

Run the verification script to ensure no secrets are exposed:
```bash
./scripts/verify_security.sh
```

This script checks:
1. No hardcoded API keys in source files
2. KeychainService implementation exists
3. Services properly integrated with Keychain
4. Setup script is present and executable

### Migration Guide

#### For New Users
1. Clone the repository
2. Build the project: `swift build`
3. Run setup: `./scripts/setup_api_key.sh`
4. Launch IRIS: `./run_iris.sh`

#### For Existing Users
If you previously had the API key in `run_iris.sh`:
1. Note your existing API key from `run_iris.sh` (line 3, now removed)
2. Run: `./scripts/setup_api_key.sh`
3. Enter your API key when prompted
4. The old hardcoded value has been removed

### Technical Details

#### Keychain Access
- **Service**: `com.iris.gemini`
- **Account**: `gemini-api-key`
- **Accessibility**: After first unlock (`kSecAttrAccessibleAfterFirstUnlock`)
- **Protection**: Encrypted by macOS Keychain

#### Fallback Behavior
The implementation maintains backwards compatibility:
1. Try to retrieve from Keychain (preferred)
2. If not found, check environment variable `GEMINI_API_KEY`
3. If still not found, use empty string (will fail gracefully with error message)

### Files Changed
- ✅ `IRIS/Services/KeychainService.swift` - New secure storage service
- ✅ `IRIS/Services/GeminiAssistantService.swift` - Updated to use Keychain
- ✅ `IRIS/Services/SentimentAnalysisService.swift` - Updated to use Keychain
- ✅ `run_iris.sh` - Removed hardcoded API key
- ✅ `run.sh` - Removed hardcoded API key
- ✅ `scripts/setup_api_key.sh` - New setup script
- ✅ `scripts/verify_security.sh` - New verification script

### Validation Checklist
- [x] No secrets in source code
- [x] API key stored in macOS Keychain
- [x] Services retrieve keys from Keychain
- [x] Setup script created and tested
- [x] Verification script passes all checks
- [x] Build succeeds without errors
- [x] Backwards compatibility maintained

### Success Criteria: ✅ ACHIEVED
**Zero security vulnerabilities** - No API keys or secrets are exposed in the source code.

# tnl_ctrl_tests Setup

## Adding the Test Target to Xcode

The test files have been created but need to be added to the Xcode project. Follow these steps:

### 1. Create the Test Target

1. Open `tnl_ctrl.xcodeproj` in Xcode
2. Go to **File > New > Target...**
3. Select **macOS > Test > Unit Testing Bundle**
4. Configure:
   - **Product Name:** `tnl_ctrl_tests`
   - **Team:** Same as main app
   - **Language:** Swift
   - **Target to be Tested:** `tnl_ctrl`
5. Click **Finish**

### 2. Add Test Files

1. In the Project Navigator, right-click the `tnl_ctrl_tests` group
2. Select **Add Files to "tnl_ctrl_tests"...**
3. Navigate to `tnl_ctrl_tests/` folder and select all files:
   - `Mocks/MockKeychainManager.swift`
   - `Fixtures/ConfigFixtures.swift`
   - `Parsers/URIParserTests.swift`
   - `Parsers/SingBoxParserTests.swift`
   - `Parsers/ClashParserTests.swift`
   - `Parsers/V2RayParserTests.swift`
   - `Builder/SingBoxConfigBuilderTests.swift`
4. Ensure **"Copy items if needed"** is unchecked
5. Ensure **"tnl_ctrl_tests"** target is checked
6. Click **Add**

### 3. Run Tests

- Press **Cmd+U** to run all tests
- Or use: `xcodebuild test -scheme tnl_ctrl -destination 'platform=macOS'`

## Test Structure

```
tnl_ctrl_tests/
├── Mocks/
│   └── MockKeychainManager.swift    # Mock for Keychain in tests
├── Fixtures/
│   └── ConfigFixtures.swift         # Test data with fresh URI schemes
├── Parsers/
│   ├── URIParserTests.swift         # Tests for vless://, vmess://, hy2://, etc.
│   ├── SingBoxParserTests.swift     # Tests for sing-box JSON configs
│   ├── ClashParserTests.swift       # Tests for Clash YAML configs
│   └── V2RayParserTests.swift       # Tests for V2Ray JSON configs
└── Builder/
    └── SingBoxConfigBuilderTests.swift  # Tests for config generation
```

## Test Coverage

- **URIParserTests:** ~25 tests covering all 7 protocols including new Hysteria2 (hy2://)
- **SingBoxParserTests:** ~15 tests for sing-box JSON parsing
- **ClashParserTests:** ~10 tests for Clash YAML parsing
- **V2RayParserTests:** ~10 tests for V2Ray JSON parsing
- **SingBoxConfigBuilderTests:** ~20 tests for config generation, routing rules, chains

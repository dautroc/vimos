import Foundation
import VimOSCore

class ConfigDecodingTests {
    func runAll() {
        testDecode()
        print("ConfigDecodingTests passed!")
    }
    
    func assert(_ condition: Bool, _ message: String) {
        if !condition {
            print("❌ Assertion Failed: \(message)")
            exit(1)
        }
    }
    
    func testDecode() {
        let json = """
        {
          "mappings": [],
          "ignoredApplications": ["com.test.app"],
          "toggleShortcut": "Cmd+Option+v"
        }
        """
        
        guard let data = json.data(using: .utf8) else {
            assert(false, "Failed to create data")
            return
        }
        
        do {
            let config = try JSONDecoder().decode(VimOSConfig.self, from: data)
            print("Decoded shortcut: \(config.toggleShortcut ?? "nil")")
            assert(config.toggleShortcut == "Cmd+Option+v", "Expected Cmd+Option+v, got \(config.toggleShortcut ?? "nil")")
        } catch {
            assert(false, "Decoding failed: \(error)")
        }
    }
}

import Foundation
import JavaScriptCore

// One isolated JS context per call; district HTML is parsed as data, never run.
// Parsing runs outside the main actor and returns JSON across the boundary.
enum DistrictParser {
    static func parse(_ operation: String, arguments: Data) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try parseSynchronously(operation, arguments: arguments)
        }.value
    }

    static func parseSynchronously(_ operation: String, arguments: Data) throws -> Data {
        guard let url = Bundle.main.url(forResource: "DistrictParser", withExtension: "js"),
              let context = JSContext(), let input = String(data: arguments, encoding: .utf8) else {
            throw PortalFailure.message("The bundled district parser is unavailable. Reinstall Schoolity.")
        }
        context.evaluateScript(try String(contentsOf: url, encoding: .utf8))
        guard context.exception == nil,
              let function = context.objectForKeyedSubscript("DistrictParser")?.forProperty("invoke"),
              let result = function.call(withArguments: [operation, input])?.toString(),
              context.exception == nil, let output = result.data(using: .utf8),
              let envelope = try JSONSerialization.jsonObject(with: output) as? [String: Any] else {
            throw PortalFailure.message("Schoolity couldn’t parse the district response.")
        }
        if let error = envelope["error"] as? String { throw PortalFailure.message(error) }
        guard let value = envelope["data"] else { throw PortalFailure.message("The district returned an empty response.") }
        return try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
    }
}

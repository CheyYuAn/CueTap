import Foundation

enum ExampleFixture {
    static let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("single-segment-demo.json")
    static func load() throws -> DemoScript { try DemoScript.load(from: url) }
}

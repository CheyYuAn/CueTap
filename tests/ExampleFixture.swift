import Foundation

enum ExampleFixture {
    static let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("html-demo.json")
    static func load() throws -> DemoScript { try DemoScript.load(from: url) }
}

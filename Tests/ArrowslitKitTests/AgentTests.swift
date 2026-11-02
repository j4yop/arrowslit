import Foundation
import Testing
@testable import ArrowslitKit

@Suite("Agent approvals")
struct AgentTests {
    @Test func allSixAssistantsArePresent() {
        #expect(Set(AgentKind.allCases) == [.claude, .codex, .copilot, .antigravity, .cursor, .opencode])
    }

    @Test func parsesOpenCodePermissionPayload() throws {
        let input = try JSONSerialization.data(withJSONObject: [
            "hook_event_name": "PermissionRequest",
            "tool_name": "bash",
            "tool_input": ["command": "rm -rf build"],
            "cwd": "/tmp/project",
        ])
        let request = try #require(AgentRequest(hookInput: input, kind: .opencode))
        #expect(request.agent == "OpenCode")
        #expect(request.project == "project")
        #expect(request.title == "Run a command")
        #expect(request.detail == "rm -rf build")
    }

    @Test func openCodeAnswersInItsOwnFormat() throws {
        let allow = try JSONSerialization.jsonObject(with: AgentKind.opencode.output(for: .allow)) as? [String: String]
        let deny = try JSONSerialization.jsonObject(with: AgentKind.opencode.output(for: .deny)) as? [String: String]
        #expect(allow == ["decision": "once"])
        #expect(deny == ["decision": "reject"])
        #expect(AgentKind.opencode.output(for: .ask).isEmpty)
    }

    @Test func installsAndRemovesHooksWithoutDroppingTheRestOfTheFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = directory.appendingPathComponent("settings.json")
        try JSONSerialization.data(withJSONObject: [
            "theme": "dark",
            "hooks": ["PermissionRequest": [["matcher": "*", "hooks": [["type": "command", "command": "other-hook"]]]]],
        ]).write(to: settings)

        try AgentHookSettings.install(.claude, command: "arrowslit --agent-hook '/tmp/a.sock'", at: settings)
        #expect(AgentHookSettings.isInstalled(.claude, at: settings))
        let installed = try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as? [String: Any]
        #expect(installed?["theme"] as? String == "dark")
        #expect(AgentHookSettings.isCurrent(.claude, command: "arrowslit --agent-hook '/tmp/a.sock'", at: settings))

        try AgentHookSettings.uninstall(.claude, at: settings)
        #expect(!AgentHookSettings.isInstalled(.claude, at: settings))
        let remaining = try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as? [String: Any]
        #expect((remaining?["hooks"] as? [String: Any]) != nil)
    }

    @Test func socketIsUserOnlyAndAcceptsARequest() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("as-\(UUID().uuidString.prefix(8)).sock").path
        let server = AgentSocketServer(path: path)
        defer { server.stop() }
        #expect(server.start())
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)

        let received = DispatchSemaphore(value: 0)
        server.onRequest = { connection, data in
            #expect(String(decoding: data, as: UTF8.self).contains("PermissionRequest"))
            server.respond(on: connection, with: Data("{\"decision\":\"once\"}".utf8))
            received.signal()
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        #expect(fd >= 0)
        defer { Darwin.close(fd) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: Array(path.utf8) + [0])
        }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        #expect(connected == 0)
        let request = Data("{\"hook_event_name\":\"PermissionRequest\"}\n".utf8)
        request.withUnsafeBytes { _ = Darwin.write(fd, $0.baseAddress, request.count) }
        #expect(received.wait(timeout: .now() + 2) == .success)
    }

    @MainActor
    @Test func bridgePublishesADemoRequest() {
        let bridge = AgentBridge(socketPath: "/tmp/arrowslit-agent-test-\(UUID().uuidString).sock")
        var changed = false
        bridge.onChange = { changed = true }
        bridge.showDemo(kind: .opencode)
        #expect(bridge.pending.count == 1)
        #expect(bridge.pending.first?.agent == "OpenCode")
        #expect(changed)
    }

    @Test func installsAndRemovesTheOpenCodePlugin() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let plugin = directory.appendingPathComponent("arrowslit-approval.js")
        defer { try? FileManager.default.removeItem(at: directory) }
        try AgentHookSettings.installOpenCode(socket: "/tmp/arrowslit-agent.sock", at: plugin)
        let script = try String(contentsOf: plugin, encoding: .utf8)
        #expect(script.contains("permission.asked"))
        #expect(script.contains("permission.ask"))
        #expect(script.contains("output.status"))
        #expect(script.contains("/tmp/arrowslit-agent.sock"))
        #expect(AgentHookSettings.isInstalled(.opencode, at: plugin))
        try AgentHookSettings.uninstall(.opencode, at: plugin)
        #expect(!FileManager.default.fileExists(atPath: plugin.path))
    }
}

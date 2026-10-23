// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from FareyVision 8b32d7a; task-owned simulator capture only.
import XCTest

@MainActor enum SimulatorCapture {
  private struct Request: Encodable {
    let id: String
    let name: String
    let createdAt: TimeInterval
    let action: String
  }
  private struct Response: Decodable {
    let exitCode: Int
    let error: String?
  }
  private enum Failure: Error {
    case timeout, capture(String), invalidImage
  }

  static func record(_ name: String, in test: XCTestCase) throws {
    guard ProcessInfo.processInfo.environment["EXTERIOR_CAPTURE_HANDSHAKE"] == "1" else { return }
    let directory = FileManager.default.temporaryDirectory.appending(path: "exterior-capture")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let id = UUID().uuidString
    let responseURL = directory.appending(path: id + ".json")
    let imageURL = directory.appending(path: id + ".png")
    let request = Request(id: id, name: name, createdAt: Date().timeIntervalSince1970, action: "screenshot")
    try JSONEncoder().encode(request).write(to: directory.appending(path: "request.json"), options: .atomic)
    let deadline = Date().addingTimeInterval(30)
    while !FileManager.default.fileExists(atPath: responseURL.path) {
      guard Date() < deadline else { throw Failure.timeout }
      Thread.sleep(forTimeInterval: 0.05)
    }
    let responseData = try Data(contentsOf: responseURL)
    let response = try JSONDecoder().decode(Response.self, from: responseData)
    guard response.exitCode == 0 else { throw Failure.capture(response.error ?? "simctl failed") }
    let image = try Data(contentsOf: imageURL)
    guard image.count > 1_000 else { throw Failure.invalidImage }
    let attachment = XCTAttachment(data: image, uniformTypeIdentifier: "public.png")
    attachment.name = name
    attachment.lifetime = .keepAlways
    test.add(attachment)
    let timing = XCTAttachment(data: responseData, uniformTypeIdentifier: "public.json")
    timing.name = name + "-timing"
    timing.lifetime = .keepAlways
    test.add(timing)
  }

  static func video(_ name: String, start: Bool, in test: XCTestCase) throws {
    guard ProcessInfo.processInfo.environment["EXTERIOR_CAPTURE_HANDSHAKE"] == "1" else { return }
    let directory = FileManager.default.temporaryDirectory.appending(path: "exterior-capture")
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    let id = UUID().uuidString
    let responseURL = directory.appending(path:id + ".json")
    let request = Request(id:id,name:name,createdAt:Date().timeIntervalSince1970,action:start ? "video-start" : "video-stop")
    try JSONEncoder().encode(request).write(to:directory.appending(path:"request.json"),options:.atomic)
    let deadline = Date().addingTimeInterval(45)
    while !FileManager.default.fileExists(atPath:responseURL.path) {
      guard Date() < deadline else { throw Failure.timeout }
      Thread.sleep(forTimeInterval:0.05)
    }
    let data = try Data(contentsOf:responseURL)
    let response = try JSONDecoder().decode(Response.self,from:data)
    guard response.exitCode == 0 else { throw Failure.capture(response.error ?? "video capture failed") }
    let attachment = XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
    attachment.name = name + (start ? "-start" : "-stop"); attachment.lifetime = .keepAlways
    test.add(attachment)
  }
}

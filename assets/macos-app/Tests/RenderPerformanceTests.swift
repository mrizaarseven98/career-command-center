import AppKit
import Foundation
import SwiftUI

@main
@MainActor
struct RenderPerformanceTests {
    static func main() throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)

        let store = AppStore(
            workspaceOverride: FileManager.default.temporaryDirectory,
            preview: true
        )
        let timestamp = "2026-07-20T08:15:30.123Z"
        store.state.leads = (0..<500).map { index in
            LeadRecord(raw: [
                "id": .string("render-lead-\(index)"),
                "title": .string("Biomedical Systems Engineer \(index)"),
                "organization": .string("Swiss Test Organization"),
                "location": .string(index.isMultiple(of: 3) ? "Zurich" : "Lausanne"),
                "type": .string(index.isMultiple(of: 5) ? "PhD" : "Job"),
                "status": .string(index.isMultiple(of: 7) ? "monitor" : "to_apply"),
                "discovered_at": .string(timestamp),
                "updated_at": .string(timestamp),
                "score": .integer(70 + index % 30),
                "job_summary": .array([.string("Develop and validate biomedical engineering workflows.")]),
                "match_strengths": .array([.string("Python, modelling, validation, and experimental documentation")]),
                "fit_gaps": .array([.string("Posting-specific domain experience requires verification")])
            ])
        }

        let size = CGSize(width: 1280, height: 800)
        var totalDuration: TimeInterval = 0
        var slowestSection = ""
        var slowestDuration: TimeInterval = 0

        for section in AppSection.allCases {
            store.selectSection(section)
            let start = CFAbsoluteTimeGetCurrent()
            let hostingView = NSHostingView(
                rootView: MainView(store: store).frame(width: size.width, height: size.height)
            )
            hostingView.frame = CGRect(origin: .zero, size: size)
            hostingView.layoutSubtreeIfNeeded()
            hostingView.displayIfNeeded()
            guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
                throw RenderPerformanceFailure(message: "Could not allocate a render surface for \(section.title)")
            }
            hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
            let duration = CFAbsoluteTimeGetCurrent() - start
            totalDuration += duration
            if duration > slowestDuration {
                slowestDuration = duration
                slowestSection = section.title
            }
            try expect(duration < 2.5, "\(section.title) renders in under 2.5 seconds")
            try expect(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0, "\(section.title) produces a nonblank render surface")
        }

        try expect(totalDuration < 12, "all sections render in under twelve seconds")
        print(String(
            format: "Render performance: all sections %.3fs; slowest %@ %.3fs",
            totalDuration,
            slowestSection,
            slowestDuration
        ))
        print("Render performance tests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw RenderPerformanceFailure(message: message) }
    }
}

private struct RenderPerformanceFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

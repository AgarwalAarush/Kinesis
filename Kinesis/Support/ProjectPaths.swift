import Foundation

enum ProjectPaths {
    static func projectRoot() -> URL {
        if let envRoot = ProcessInfo.processInfo.environment["KINESIS_PROJECT_ROOT"], !envRoot.isEmpty {
            return URL(fileURLWithPath: envRoot)
        }

        var candidate = Bundle.main.bundleURL
        for _ in 0..<8 {
            let helper = candidate.appendingPathComponent("cv_helper/kinesis_cv.py")
            if FileManager.default.fileExists(atPath: helper.path) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}

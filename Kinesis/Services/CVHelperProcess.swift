import Foundation

@MainActor
final class CVHelperProcess {
    var onIntent: ((GestureIntent) -> Void)?
    var onStatusChange: ((HelperStatus) -> Void)?

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var pendingOutput = ""
    private var pendingError = ""
    private var generation = 0
    private let decoder = JSONDecoder()

    var isRunning: Bool {
        process?.isRunning == true
    }

    func start(settings: ControlSettings) {
        guard process?.isRunning != true else { return }

        let root = ProjectPaths.projectRoot()
        let helper = root.appendingPathComponent("cv_helper/kinesis_cv.py")
        guard FileManager.default.fileExists(atPath: helper.path) else {
            onStatusChange?(.failed("Missing Python helper at \(helper.path)."))
            return
        }

        let python = pythonExecutable(projectRoot: root)
        let process = Process()
        generation += 1
        let launchGeneration = generation
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = python
        process.arguments = [
            helper.path,
            "--smoothing", String(settings.smoothing),
            "--pinch-threshold", String(settings.pinchThreshold)
        ]
        process.currentDirectoryURL = root
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in self?.consumeOutput(text) }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in self?.pendingError += text }
        }

        process.terminationHandler = { [weak self, weak process] terminatedProcess in
            Task { @MainActor [weak self, weak process] in
                guard let self, self.generation == launchGeneration, self.process === process else { return }
                let message = self.pendingError.trimmingCharacters(in: .whitespacesAndNewlines)
                let status = terminatedProcess.terminationStatus
                self.cleanup()
                if status == 0 || status == 15 {
                    self.onStatusChange?(.stopped)
                } else {
                    self.onStatusChange?(.failed(message.isEmpty ? "Helper exited with status \(status)." : message))
                }
            }
        }

        do {
            onStatusChange?(.starting)
            try process.run()
            self.process = process
            self.outputPipe = outputPipe
            self.errorPipe = errorPipe
            onStatusChange?(.running)
        } catch {
            cleanup()
            onStatusChange?(.failed("Could not launch helper: \(error.localizedDescription)"))
        }
    }

    func stop() {
        generation += 1
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        cleanup()
        onStatusChange?(.stopped)
    }

    private func consumeOutput(_ text: String) {
        pendingOutput += text
        while let newline = pendingOutput.firstIndex(of: "\n") {
            let line = String(pendingOutput[..<newline])
            pendingOutput.removeSubrange(...newline)
            decodeLine(line)
        }
    }

    private func decodeLine(_ line: String) {
        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let data = line.data(using: .utf8) else { return }
        do {
            onIntent?(try decoder.decode(GestureIntent.self, from: data))
        } catch {
            onStatusChange?(.failed("Helper emitted invalid intent JSON: \(error.localizedDescription)"))
        }
    }

    private func cleanup() {
        process = nil
        outputPipe = nil
        errorPipe = nil
        pendingOutput = ""
        pendingError = ""
    }

    private func pythonExecutable(projectRoot: URL) -> URL {
        let venvPython = projectRoot.appendingPathComponent(".venv/bin/python3")
        if FileManager.default.isExecutableFile(atPath: venvPython.path) {
            return venvPython
        }
        return URL(fileURLWithPath: "/usr/bin/python3")
    }
}

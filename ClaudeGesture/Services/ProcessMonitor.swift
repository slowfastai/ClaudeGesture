import Foundation

/// Monitors a process by PID and calls back when it terminates.
/// Uses `kill(pid, 0)` polling to detect process exit.
class ProcessMonitor {
    private let pid: pid_t
    private var timer: DispatchSourceTimer?
    var onProcessTerminated: (() -> Void)?

    init(pid: pid_t) {
        self.pid = pid
    }

    func start() {
        stop()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let result = kill(self.pid, 0)
            if result != 0 && errno == ESRCH {
                // Process no longer exists
                self.stop()
                self.onProcessTerminated?()
            }
            // EPERM means process exists but we lack permission — still alive
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    deinit {
        stop()
    }
}

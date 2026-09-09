#pragma once

#include <atomic>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <queue>
#include <thread>

namespace vpn_plugin {

/**
 * Minimal single-threaded task queue for offloading blocking
 * VPN operations (service install/start/stop) off the UI thread.
 *
 * Replaces the ag::VpnEventLoop dependency so we don't pull in
 * transitive third-party headers from TrustTunnelClientWindows.
 */
class BackgroundWorker {
public:
    BackgroundWorker();
    ~BackgroundWorker();

    BackgroundWorker(const BackgroundWorker&) = delete;
    BackgroundWorker& operator=(const BackgroundWorker&) = delete;

    /**
     * Enqueue a task for asynchronous execution.
     * @param task The task to execute on the worker thread.
     * @return true if the task was enqueued, false if the worker is stopped.
     */
    bool Post(std::function<void()> task);

    /**
     * Enqueue a task and block the calling thread until it completes.
     * @param task The task to execute on the worker thread.
     */
    void Sync(std::function<void()> task);

private:
    /**
     * Main loop executed on the worker thread.
     */
    void Run();

    std::thread m_thread;
    std::queue<std::function<void()>> m_queue;
    std::mutex m_mutex;
    std::condition_variable m_cv;
    std::atomic<bool> m_stop{false};
};

} // namespace vpn_plugin

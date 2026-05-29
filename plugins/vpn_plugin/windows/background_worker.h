#ifndef FLUTTER_PLUGIN_BACKGROUND_WORKER_H_
#define FLUTTER_PLUGIN_BACKGROUND_WORKER_H_

#include <atomic>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <queue>
#include <thread>

namespace vpn_plugin {

/// Minimal single-threaded task queue for offloading blocking
/// VPN operations (service install/start/stop) off the UI thread.
///
/// Replaces the `ag::VpnEventLoop` dependency so we don't pull in
/// transitive third-party headers from TrustTunnelClientWindows.
class BackgroundWorker {
 public:
  BackgroundWorker();
  ~BackgroundWorker();

  BackgroundWorker(const BackgroundWorker&) = delete;
  BackgroundWorker& operator=(const BackgroundWorker&) = delete;

  /// Enqueue a task for asynchronous execution. Returns immediately.
  void Post(std::function<void()> task);

  /// Enqueue a task and block the calling thread until it completes.
  void Sync(std::function<void()> task);

 private:
  void Run();

  std::thread thread_;
  std::queue<std::function<void()>> queue_;
  std::mutex mutex_;
  std::condition_variable cv_;
  std::atomic<bool> stop_{false};
};

}  // namespace vpn_plugin

#endif  // FLUTTER_PLUGIN_BACKGROUND_WORKER_H_

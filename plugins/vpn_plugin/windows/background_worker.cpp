#include "background_worker.h"

#include <utility>

namespace vpn_plugin {

BackgroundWorker::BackgroundWorker()
    : thread_(&BackgroundWorker::Run, this) {}

BackgroundWorker::~BackgroundWorker() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    stop_ = true;
  }
  cv_.notify_one();
  if (thread_.joinable()) {
    thread_.join();
  }
}

void BackgroundWorker::Post(std::function<void()> task) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (stop_) return;
    queue_.push(std::move(task));
  }
  cv_.notify_one();
}

void BackgroundWorker::Sync(std::function<void()> task) {
  std::mutex sync_mutex;
  std::condition_variable sync_cv;
  bool done = false;

  Post([&]() {
    task();
    {
      std::lock_guard<std::mutex> lock(sync_mutex);
      done = true;
    }
    sync_cv.notify_one();
  });

  std::unique_lock<std::mutex> lock(sync_mutex);
  sync_cv.wait(lock, [&] { return done; });
}

void BackgroundWorker::Run() {
  for (;;) {
    std::function<void()> task;
    {
      std::unique_lock<std::mutex> lock(mutex_);
      cv_.wait(lock, [this] { return stop_ || !queue_.empty(); });
      if (stop_ && queue_.empty()) return;
      task = std::move(queue_.front());
      queue_.pop();
    }
    task();
  }
}

}  // namespace vpn_plugin

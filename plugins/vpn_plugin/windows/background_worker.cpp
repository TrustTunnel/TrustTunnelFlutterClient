#include "background_worker.h"

#include <utility>

namespace vpn_plugin {

BackgroundWorker::BackgroundWorker()
    : m_thread(&BackgroundWorker::Run, this) {}

BackgroundWorker::~BackgroundWorker() {
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_stop = true;
    }
    m_cv.notify_one();
    if (m_thread.joinable()) {
        m_thread.join();
    }
}

void BackgroundWorker::Post(std::function<void()> task) {
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_stop) {
            return;
        }
        m_queue.push(std::move(task));
    }
    m_cv.notify_one();
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
            std::unique_lock<std::mutex> lock(m_mutex);
            m_cv.wait(lock, [this] { return m_stop || !m_queue.empty(); });
            if (m_stop && m_queue.empty()) {
                return;
            }
            task = std::move(m_queue.front());
            m_queue.pop();
        }
        task();
    }
}

} // namespace vpn_plugin

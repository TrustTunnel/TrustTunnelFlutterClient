#pragma once

#include <functional>
#include <memory>

namespace vpn_plugin {

/**
 * Thread-safe UI thread dispatch using a message-only HWND_MESSAGE window.
 *
 * Allows arbitrary threads to schedule callbacks on the thread that owns
 * the Flutter Aura/UI message loop (the thread that created the HWND).
 */
class UIThreadDispatcher {
public:
    UIThreadDispatcher();
    ~UIThreadDispatcher();

    UIThreadDispatcher(const UIThreadDispatcher&) = delete;
    UIThreadDispatcher& operator=(const UIThreadDispatcher&) = delete;

    /**
     * Schedule a task for execution on the UI thread.
     * @param task The callback to run on the UI thread.
     */
    void RunOnUIThread(std::function<void()> task);

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};

} // namespace vpn_plugin

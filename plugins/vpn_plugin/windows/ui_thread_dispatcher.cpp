#include "ui_thread_dispatcher.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <mutex>
#include <queue>

struct UIThreadDispatcher::Impl {
  static constexpr UINT WM_DISPATCH = WM_APP + 1;
  static constexpr const wchar_t kClassName[] = L"VpnPluginDispatcher";

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp);

  HWND hwnd = nullptr;
  std::mutex mutex;
  std::queue<std::function<void()>> queue;
};

UIThreadDispatcher::UIThreadDispatcher() : impl_(std::make_unique<Impl>()) {
  WNDCLASSEXW wc = {};
  wc.cbSize = sizeof(wc);
  wc.lpfnWndProc = Impl::WndProc;
  wc.lpszClassName = Impl::kClassName;
  wc.hInstance = GetModuleHandle(nullptr);
  RegisterClassExW(&wc);
  impl_->hwnd = CreateWindowExW(0, Impl::kClassName, L"", 0, 0, 0, 0, 0,
      HWND_MESSAGE, nullptr, GetModuleHandle(nullptr), nullptr);
  SetWindowLongPtr(impl_->hwnd, GWLP_USERDATA,
                   reinterpret_cast<LONG_PTR>(impl_.get()));
}

UIThreadDispatcher::~UIThreadDispatcher() {
  if (impl_->hwnd) {
    DestroyWindow(impl_->hwnd);
  }
}

void UIThreadDispatcher::RunOnUIThread(std::function<void()> task) {
  {
    std::lock_guard<std::mutex> lock(impl_->mutex);
    impl_->queue.push(std::move(task));
  }
  PostMessage(impl_->hwnd, Impl::WM_DISPATCH, 0, 0);
}

LRESULT CALLBACK UIThreadDispatcher::Impl::WndProc(HWND hwnd, UINT msg,
                                                   WPARAM wp, LPARAM lp) {
  if (msg == WM_DISPATCH) {
    auto* pimpl = reinterpret_cast<Impl*>(
        GetWindowLongPtr(hwnd, GWLP_USERDATA));
    if (pimpl) {
      std::queue<std::function<void()>> tasks;
      {
        std::lock_guard<std::mutex> lock(pimpl->mutex);
        std::swap(tasks, pimpl->queue);
      }
      while (!tasks.empty()) {
        tasks.front()();
        tasks.pop();
      }
    }
    return 0;
  }
  return DefWindowProc(hwnd, msg, wp, lp);
}

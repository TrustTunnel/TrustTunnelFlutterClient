#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <functional>
#include <mutex>
#include <queue>

class UIThreadDispatcher {
 public:
  UIThreadDispatcher() {
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = WndProc;
    wc.lpszClassName = kClassName;
    wc.hInstance = GetModuleHandle(nullptr);
    RegisterClassExW(&wc);
    hwnd_ = CreateWindowExW(0, kClassName, L"", 0, 0, 0, 0, 0,
        HWND_MESSAGE, nullptr, GetModuleHandle(nullptr), nullptr);
    SetWindowLongPtr(hwnd_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
  }

  ~UIThreadDispatcher() {
    if (hwnd_) {
      DestroyWindow(hwnd_);
    }
  }

  UIThreadDispatcher(const UIThreadDispatcher&) = delete;
  UIThreadDispatcher& operator=(const UIThreadDispatcher&) = delete;

  void RunOnUIThread(std::function<void()> task) {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      queue_.push(std::move(task));
    }
    PostMessage(hwnd_, WM_DISPATCH, 0, 0);
  }

 private:
  static constexpr UINT WM_DISPATCH = WM_APP + 1;
  static constexpr const wchar_t kClassName[] = L"VpnPluginDispatcher";

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_DISPATCH) {
      auto* self = reinterpret_cast<UIThreadDispatcher*>(
          GetWindowLongPtr(hwnd, GWLP_USERDATA));
      if (self) {
        std::queue<std::function<void()>> tasks;
        {
          std::lock_guard<std::mutex> lock(self->mutex_);
          std::swap(tasks, self->queue_);
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

  HWND hwnd_ = nullptr;
  std::mutex mutex_;
  std::queue<std::function<void()>> queue_;
};

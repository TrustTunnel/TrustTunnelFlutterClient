#include "ui_thread_dispatcher.h"

UIThreadDispatcher::UIThreadDispatcher() {
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

UIThreadDispatcher::~UIThreadDispatcher() {
  if (hwnd_) {
    DestroyWindow(hwnd_);
  }
}

void UIThreadDispatcher::RunOnUIThread(std::function<void()> task) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    queue_.push(std::move(task));
  }
  PostMessage(hwnd_, WM_DISPATCH, 0, 0);
}

LRESULT CALLBACK UIThreadDispatcher::WndProc(HWND hwnd, UINT msg, WPARAM wp,
                                             LPARAM lp) {
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

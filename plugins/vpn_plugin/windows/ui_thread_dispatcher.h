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
  UIThreadDispatcher();
  ~UIThreadDispatcher();

  UIThreadDispatcher(const UIThreadDispatcher&) = delete;
  UIThreadDispatcher& operator=(const UIThreadDispatcher&) = delete;

  void RunOnUIThread(std::function<void()> task);

 private:
  static constexpr UINT WM_DISPATCH = WM_APP + 1;
  static constexpr const wchar_t kClassName[] = L"VpnPluginDispatcher";

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp);

  HWND hwnd_ = nullptr;
  std::mutex mutex_;
  std::queue<std::function<void()>> queue_;
};

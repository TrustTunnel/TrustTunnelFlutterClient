#ifndef RUNNER_WINDOW_ICONS_H_
#define RUNNER_WINDOW_ICONS_H_

#include <windows.h>

#include "resource.h"

// Owns only the per-window icons loaded without LR_SHARED. Class icons and
// icons installed by other code remain owned by their respective callers.
class WindowIcons {
 public:
  WindowIcons() = default;
  ~WindowIcons() { Reset(); }

  WindowIcons(const WindowIcons&) = delete;
  WindowIcons& operator=(const WindowIcons&) = delete;

  static UINT GetDpi(HWND window, UINT fallback = USER_DEFAULT_SCREEN_DPI) {
    using GetDpiForWindowProc = UINT(WINAPI*)(HWND);
    static const auto get_dpi_for_window =
        reinterpret_cast<GetDpiForWindowProc>(::GetProcAddress(
            ::GetModuleHandleW(L"user32.dll"), "GetDpiForWindow"));
    const UINT dpi = get_dpi_for_window != nullptr && window != nullptr
                         ? get_dpi_for_window(window)
                         : 0;
    return dpi != 0 ? dpi : fallback;
  }

  void Update(HWND window, UINT dpi) {
    Replace(window, ICON_SMALL, SM_CXSMICON, SM_CYSMICON, dpi, small_icon_);
    Replace(window, ICON_BIG, SM_CXICON, SM_CYICON, dpi, large_icon_);
  }

  // Call after the window stops using the icons (WM_NCDESTROY).
  void Reset() {
    Release(small_icon_);
    Release(large_icon_);
  }

 private:
  static int GetMetric(int index, UINT dpi) {
    using GetSystemMetricsForDpiProc = int(WINAPI*)(int, UINT);
    static const auto get_system_metrics_for_dpi =
        reinterpret_cast<GetSystemMetricsForDpiProc>(::GetProcAddress(
            ::GetModuleHandleW(L"user32.dll"), "GetSystemMetricsForDpi"));
    // Older Windows versions without this API use system-wide icon metrics.
    return get_system_metrics_for_dpi != nullptr
               ? get_system_metrics_for_dpi(index, dpi)
               : ::GetSystemMetrics(index);
  }

  static void Release(HICON& icon) {
    if (icon != nullptr) {
      ::DestroyIcon(icon);
      icon = nullptr;
    }
  }

  static void Replace(HWND window, WPARAM type, int width_metric,
                      int height_metric, UINT dpi, HICON& owned_icon) {
    const int width = GetMetric(width_metric, dpi);
    const int height = GetMetric(height_metric, dpi);
    if (width <= 0 || height <= 0) {
      return;
    }
    HICON icon = static_cast<HICON>(::LoadImageW(
        ::GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
        width, height, LR_DEFAULTCOLOR));
    if (icon == nullptr) {
      return;  // Keep the previously installed icon if loading fails.
    }
    ::SendMessageW(window, WM_SETICON, type, reinterpret_cast<LPARAM>(icon));
    Release(owned_icon);
    owned_icon = icon;
  }

  HICON small_icon_ = nullptr;
  HICON large_icon_ = nullptr;
};

#endif  // RUNNER_WINDOW_ICONS_H_

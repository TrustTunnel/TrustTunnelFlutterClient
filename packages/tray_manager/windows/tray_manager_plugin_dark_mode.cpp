#include "tray_manager_plugin_helpers.h"

#include <windows.h>

namespace tray_manager {

// Dark mode support - undocumented Windows APIs
enum PreferredAppMode { Default, AllowDark, ForceDark, ForceLight, Max };

using fnSetPreferredAppMode =
    PreferredAppMode(WINAPI *)(PreferredAppMode appMode);
using fnAllowDarkModeForWindow = bool(WINAPI *)(HWND hWnd, bool allow);
using fnRefreshImmersiveColorPolicyState = void(WINAPI *)();
using fnFlushMenuThemes = void(WINAPI *)();

static fnSetPreferredAppMode SetPreferredAppMode = nullptr;
static fnAllowDarkModeForWindow AllowDarkModeForWindow = nullptr;
static fnRefreshImmersiveColorPolicyState RefreshImmersiveColorPolicyState =
    nullptr;
static fnFlushMenuThemes FlushMenuThemes = nullptr;
static bool dark_mode_initialized = false;

void InitDarkMode() {
  if (dark_mode_initialized)
    return;
  dark_mode_initialized = true;

  HMODULE uxtheme =
      LoadLibraryExW(L"uxtheme.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (!uxtheme)
    return;

  // Ordinal 135 = SetPreferredAppMode (Windows 10 1903+)
  SetPreferredAppMode = reinterpret_cast<fnSetPreferredAppMode>(
      GetProcAddress(uxtheme, MAKEINTRESOURCEA(135)));
  // Ordinal 133 = AllowDarkModeForWindow
  AllowDarkModeForWindow = reinterpret_cast<fnAllowDarkModeForWindow>(
      GetProcAddress(uxtheme, MAKEINTRESOURCEA(133)));
  // Ordinal 104 = RefreshImmersiveColorPolicyState
  RefreshImmersiveColorPolicyState =
      reinterpret_cast<fnRefreshImmersiveColorPolicyState>(
          GetProcAddress(uxtheme, MAKEINTRESOURCEA(104)));
  // Ordinal 136 = FlushMenuThemes
  FlushMenuThemes = reinterpret_cast<fnFlushMenuThemes>(
      GetProcAddress(uxtheme, MAKEINTRESOURCEA(136)));

  if (SetPreferredAppMode) {
    SetPreferredAppMode(AllowDark);
  }
  if (RefreshImmersiveColorPolicyState) {
    RefreshImmersiveColorPolicyState();
  }
  if (FlushMenuThemes) {
    FlushMenuThemes();
  }
}

} // namespace tray_manager

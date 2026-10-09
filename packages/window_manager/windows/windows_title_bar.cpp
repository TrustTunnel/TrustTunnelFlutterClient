#include "windows_title_bar.h"

#include <commctrl.h>
#include <dwmapi.h>
#include <dwrite.h>
#include <shellapi.h>
#include <windowsx.h>
#include <winternl.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <utility>

bool WindowsTitleBar::IsWindows11OrGreater() {
  // GetVersion/VersionHelpers can report compatibility versions. RtlGetVersion
  // returns the actual build, including when no Windows 11 manifest exists.
  using RtlGetVersionProc = LONG(WINAPI*)(PRTL_OSVERSIONINFOW);
  const auto get_version = reinterpret_cast<RtlGetVersionProc>(
      GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion"));
  RTL_OSVERSIONINFOW version{};
  version.dwOSVersionInfoSize = sizeof(version);
  return get_version && get_version(&version) == 0 &&
         version.dwMajorVersion >= 10 && version.dwBuildNumber >= 22000;
}

namespace {
int64_t SystemColor(int index) {
  const COLORREF color = GetSysColor(index);
  return static_cast<int64_t>(0xff000000u | (GetRValue(color) << 16) |
                              (GetGValue(color) << 8) | GetBValue(color));
}

std::string ResolveCaptionFont() {
  Microsoft::WRL::ComPtr<IDWriteFactory> factory;
  Microsoft::WRL::ComPtr<IDWriteFontCollection> fonts;
  if (FAILED(DWriteCreateFactory(
          DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory),
          reinterpret_cast<IUnknown**>(factory.GetAddressOf()))) ||
      FAILED(factory->GetSystemFontCollection(&fonts, TRUE))) {
    return "Segoe UI";
  }
  // Windows installations expose the variable font under different family
  // names. Use a name present in the same DirectWrite collection Flutter uses.
  const std::pair<const wchar_t*, const char*> candidates[] = {
      {L"Segoe UI Variable", "Segoe UI Variable"},
      {L"Segoe UI Variable Text", "Segoe UI Variable Text"},
      {L"Segoe UI Variable Small", "Segoe UI Variable Small"},
  };
  for (const auto& candidate : candidates) {
    UINT32 index = 0;
    BOOL exists = FALSE;
    if (SUCCEEDED(fonts->FindFamilyName(candidate.first, &index, &exists)) &&
        exists) {
      return candidate.second;
    }
  }
  return "Segoe UI";
}
}  // namespace

WindowsTitleBar::WindowsTitleBar(HWND window, HWND view, StateCallback callback)
    : window_(window),
      view_(view),
      callback_(std::move(callback)),
      windows_11_(IsWindows11OrGreater()),
      maximized_(IsZoomed(window) != FALSE),
      font_family_(ResolveCaptionFont()) {
  SetWindowSubclass(view_, ChildProc, reinterpret_cast<UINT_PTR>(this),
                    reinterpret_cast<DWORD_PTR>(this));
}

WindowsTitleBar::~WindowsTitleBar() {
  if (IsWindow(view_)) {
    RemoveWindowSubclass(view_, ChildProc, reinterpret_cast<UINT_PTR>(this));
  }
  if (pressed_ != HTCLIENT && GetCapture() == window_) ReleaseCapture();
}

void WindowsTitleBar::Configure() {
  enabled_ = true;
  // Keep the caption/system menu styles: Windows uses them for Snap, keyboard
  // commands, animations, and DWM's external shadow/corner policy.
  SetWindowLongPtr(window_, GWL_STYLE,
                   GetWindowLongPtr(window_, GWL_STYLE) | WS_OVERLAPPEDWINDOW);
  UpdateAppearance();
  SetWindowPos(window_, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                   SWP_FRAMECHANGED);
}

bool WindowsTitleBar::ReadRect(const flutter::EncodableValue& value,
                               LogicalRect* rect) {
  const auto* list = std::get_if<flutter::EncodableList>(&value);
  if (!list || list->size() != 4) return false;
  double numbers[4];
  for (size_t i = 0; i < 4; ++i) {
    const auto* number = std::get_if<double>(&(*list)[i]);
    if (!number || !std::isfinite(*number)) return false;
    numbers[i] = *number;
  }
  if (numbers[2] < numbers[0] || numbers[3] < numbers[1]) return false;
  *rect = {numbers[0], numbers[1], numbers[2], numbers[3]};
  return true;
}

void WindowsTitleBar::Center() {
  const RECT work = WorkArea();
  RECT window{};
  GetWindowRect(window_, &window);
  const LONG x =
      work.left +
      std::max(0L, (work.right - work.left - (window.right - window.left)) / 2);
  const LONG y =
      work.top +
      std::max(0L, (work.bottom - work.top - (window.bottom - window.top)) / 2);
  SetWindowPos(window_, nullptr, x, y, 0, 0,
               SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
}

bool WindowsTitleBar::SetRegions(const flutter::EncodableMap& arguments) {
  const auto width_item = arguments.find(flutter::EncodableValue("viewWidth"));
  if (width_item == arguments.end()) return false;
  const auto* width = std::get_if<double>(&width_item->second);
  if (!width || !std::isfinite(*width) || *width <= 0) return false;
  LogicalRect drag, minimize, maximize, close;
  std::vector<LogicalRect> exclusions;
  const std::pair<const char*, LogicalRect*> fields[] = {
      {"drag", &drag},
      {"minimize", &minimize},
      {"maximize", &maximize},
      {"close", &close}};
  for (const auto& field : fields) {
    const auto item = arguments.find(flutter::EncodableValue(field.first));
    if (item == arguments.end() || !ReadRect(item->second, field.second))
      return false;
  }
  const auto item = arguments.find(flutter::EncodableValue("exclusions"));
  if (item == arguments.end()) return false;
  const auto* list = std::get_if<flutter::EncodableList>(&item->second);
  if (!list) return false;
  for (const auto& value : *list) {
    LogicalRect rect;
    if (!ReadRect(value, &rect)) return false;
    exclusions.push_back(rect);
  }
  drag_ = drag;
  minimize_ = minimize;
  maximize_ = maximize;
  close_ = close;
  exclusions_ = std::move(exclusions);
  view_width_ = *width;
  regions_ready_ = true;
  return true;
}

int WindowsTitleBar::FrameMetric(int metric) const {
  const UINT dpi = GetDpiForWindow(window_);
  return GetSystemMetricsForDpi(metric, dpi) +
         GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
}

RECT WindowsTitleBar::WorkArea() const {
  MONITORINFO info{sizeof(info)};
  const HMONITOR monitor = MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST);
  if (!GetMonitorInfo(monitor, &info)) {
    RECT rect{};
    GetWindowRect(window_, &rect);
    return rect;
  }
  RECT work = info.rcWork;
  // Reserve two physical pixels for revealing an auto-hidden taskbar on this
  // monitor, including negative-coordinate monitors and every taskbar edge.
  for (UINT edge = ABE_LEFT; edge <= ABE_BOTTOM; ++edge) {
    APPBARDATA bar{sizeof(bar)};
    bar.uEdge = edge;
    bar.rc = info.rcMonitor;
    if (SHAppBarMessage(ABM_GETAUTOHIDEBAREX, &bar) == 0) continue;
    switch (edge) {
      case ABE_LEFT:
        if (work.left == info.rcMonitor.left) work.left += 2;
        break;
      case ABE_TOP:
        if (work.top == info.rcMonitor.top) work.top += 2;
        break;
      case ABE_RIGHT:
        if (work.right == info.rcMonitor.right) work.right -= 2;
        break;
      case ABE_BOTTOM:
        if (work.bottom == info.rcMonitor.bottom) work.bottom -= 2;
        break;
    }
  }
  return work;
}

RECT WindowsTitleBar::PhysicalRect(const LogicalRect& rect,
                                   bool caption_button) const {
  // Rectangles are relative to the child view, which may be inset by the frame.
  // Right-aligned buttons track the current client width synchronously during
  // live resize, even before Flutter sends its next layout.
  RECT client{};
  GetClientRect(view_, &client);
  const double scale = GetDpiForWindow(window_) / 96.0;
  const double dx = caption_button ? client.right / scale - view_width_ : 0;
  RECT physical{
      static_cast<LONG>(std::lround((rect.left + dx) * scale)),
      static_cast<LONG>(std::lround(rect.top * scale)),
      static_cast<LONG>(std::lround((rect.right + dx) * scale)),
      static_cast<LONG>(std::lround(rect.bottom * scale)),
  };
  MapWindowPoints(view_, HWND_DESKTOP, reinterpret_cast<POINT*>(&physical), 2);
  return physical;
}

LRESULT WindowsTitleBar::HitTest(POINT point, bool resizable) const {
  RECT window{};
  GetWindowRect(window_, &window);
  if (!PtInRect(&window, point)) return HTNOWHERE;
  if (resizable && !IsZoomed(window_) && !IsIconic(window_)) {
    const int x = FrameMetric(SM_CXSIZEFRAME);
    const int y = FrameMetric(SM_CYSIZEFRAME);
    const bool left = point.x < window.left + x;
    const bool right = point.x >= window.right - x;
    const bool top = point.y < window.top + y;
    const bool bottom = point.y >= window.bottom - y;
    if (top && left) return HTTOPLEFT;
    if (top && right) return HTTOPRIGHT;
    if (bottom && left) return HTBOTTOMLEFT;
    if (bottom && right) return HTBOTTOMRIGHT;
    if (left) return HTLEFT;
    if (right) return HTRIGHT;
    if (top) return HTTOP;
    if (bottom) return HTBOTTOM;
  }
  if (!regions_ready_) return HTCLIENT;
  for (const auto& rect : exclusions_) {
    const RECT physical = PhysicalRect(rect);
    if (PtInRect(&physical, point)) return HTCLIENT;
  }
  const std::pair<const LogicalRect*, int> buttons[] = {
      {&minimize_, HTMINBUTTON}, {&maximize_, HTMAXBUTTON}, {&close_, HTCLOSE}};
  for (const auto& button : buttons) {
    const RECT rect = PhysicalRect(*button.first, true);
    if (PtInRect(&rect, point)) return button.second;
  }
  RECT drag = PhysicalRect(drag_);
  RECT view{};
  GetWindowRect(view_, &view);
  if (std::abs(drag_.right - view_width_) < 0.01) drag.right = view.right;
  return PtInRect(&drag, point) ? HTCAPTION : HTCLIENT;
}

std::string WindowsTitleBar::ButtonName(int hit) {
  switch (hit) {
    case HTMINBUTTON:
      return "minimize";
    case HTMAXBUTTON:
      return "maximize";
    case HTCLOSE:
      return "close";
    default:
      return "";
  }
}

flutter::EncodableMap WindowsTitleBar::State() const {
  using flutter::EncodableValue;
  HIGHCONTRASTW contrast{sizeof(contrast)};
  SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0);
  const HWND foreground = GetForegroundWindow();
  const bool active =
      foreground && GetAncestor(foreground, GA_ROOTOWNER) == window_;
  DWORD scale = 100;
  DWORD size = sizeof(scale);
  RegGetValueW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Accessibility",
               L"TextScaleFactor", RRF_RT_REG_DWORD, nullptr, &scale, &size);
  return {
      {EncodableValue("maximized"), EncodableValue(IsZoomed(window_) != FALSE)},
      {EncodableValue("active"), EncodableValue(active)},
      {EncodableValue("hovered"), EncodableValue(ButtonName(hovered_))},
      {EncodableValue("pressed"), EncodableValue(ButtonName(pressed_))},
      {EncodableValue("highContrast"),
       EncodableValue((contrast.dwFlags & HCF_HIGHCONTRASTON) != 0)},
      {EncodableValue("captionBackgroundColor"),
       EncodableValue(
           SystemColor(active ? COLOR_ACTIVECAPTION : COLOR_INACTIVECAPTION))},
      {EncodableValue("captionForegroundColor"),
       EncodableValue(SystemColor(active ? COLOR_CAPTIONTEXT
                                         : COLOR_INACTIVECAPTIONTEXT))},
      {EncodableValue("highlightColor"),
       EncodableValue(SystemColor(COLOR_HIGHLIGHT))},
      {EncodableValue("highlightTextColor"),
       EncodableValue(SystemColor(COLOR_HIGHLIGHTTEXT))},
      {EncodableValue("fontFamily"), EncodableValue(font_family_)},
      {EncodableValue("textScale"),
       EncodableValue(std::max(1.0, scale / 100.0))},
  };
}

void WindowsTitleBar::EmitState() { callback_(State()); }

void WindowsTitleBar::SetHover(int hit) {
  if (ButtonName(hit).empty()) hit = HTCLIENT;
  if (hovered_ == hit) return;
  hovered_ = hit;
  EmitState();
}

void WindowsTitleBar::ResetInput() {
  const bool changed = hovered_ != HTCLIENT || pressed_ != HTCLIENT;
  const bool owns_capture = pressed_ != HTCLIENT && GetCapture() == window_;
  hovered_ = pressed_ = HTCLIENT;
  // The same HWND also owns the system move/resize capture. Only release a
  // capture acquired by our caption button, never the one owned by Windows.
  if (owns_capture) ReleaseCapture();
  if (changed) EmitState();
}

void WindowsTitleBar::InvokeButton(const std::string& button) {
  UINT command = 0;
  if (button == "minimize") command = SC_MINIMIZE;
  if (button == "maximize")
    command = IsZoomed(window_) ? SC_RESTORE : SC_MAXIMIZE;
  if (button == "close") command = SC_CLOSE;
  if (command && IsWindowEnabled(window_)) {
    PostMessage(window_, WM_SYSCOMMAND, command, 0);
  }
}

void WindowsTitleBar::UpdateAppearance() {
  // An opaque window with its native styles lets DWM own external corners and
  // shadows. Windows 10 keeps its own policy; no transparent rounded region.
  const MARGINS margins{0, 0, 1, 0};
  DwmExtendFrameIntoClientArea(window_, &margins);
}

std::optional<LRESULT> WindowsTitleBar::HandleMessage(UINT message,
                                                      WPARAM wparam,
                                                      LPARAM lparam,
                                                      bool resizable) {
  if (!enabled_) return std::nullopt;
  resizable_ = resizable;
  switch (message) {
    case WM_NCCALCSIZE: {
      RECT* rect = wparam
                       ? &reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam)->rgrc[0]
                       : reinterpret_cast<RECT*>(lparam);
      if (IsZoomed(window_)) {
        const RECT work = WorkArea();
        rect->left = std::max(rect->left, work.left);
        rect->top = std::max(rect->top, work.top);
        rect->right = std::min(rect->right, work.right);
        rect->bottom = std::min(rect->bottom, work.bottom);
      } else {
        rect->left += FrameMetric(SM_CXSIZEFRAME);
        rect->right -= FrameMetric(SM_CXSIZEFRAME);
        rect->bottom -= FrameMetric(SM_CYSIZEFRAME);
        // Windows 10 needs one physical pixel for the DWM top border; this
        // is not a logical size and must not be multiplied by the DPI.
        rect->top += windows_11_ ? 0 : 1;
      }
      return 0;
    }
    case WM_GETMINMAXINFO: {
      MONITORINFO info{sizeof(info)};
      if (GetMonitorInfo(MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST),
                         &info)) {
        const RECT work = WorkArea();
        const int x = FrameMetric(SM_CXSIZEFRAME);
        const int y = FrameMetric(SM_CYSIZEFRAME);
        auto* limits = reinterpret_cast<MINMAXINFO*>(lparam);
        limits->ptMaxPosition = {work.left - info.rcMonitor.left - x,
                                 work.top - info.rcMonitor.top - y};
        limits->ptMaxSize = {work.right - work.left + x * 2,
                             work.bottom - work.top + y * 2};
      }
      // WindowManager still applies logical minimum/maximum track sizes.
      break;
    }
    case WM_NCHITTEST:
      return HitTest({GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)}, resizable);
    case WM_NCMOUSEMOVE: {
      SetHover(static_cast<int>(wparam));
      TRACKMOUSEEVENT tracking{sizeof(tracking), TME_LEAVE | TME_NONCLIENT,
                               window_, HOVER_DEFAULT};
      TrackMouseEvent(&tracking);
      // DWM/DefWindowProc need non-client hover over HTMAXBUTTON to display
      // the Windows 11 Snap flyout. They never receive our button down/up.
      LRESULT result = 0;
      if (DwmDefWindowProc(window_, message, wparam, lparam, &result))
        return result;
      break;
    }
    case WM_NCLBUTTONDOWN:
    case WM_NCLBUTTONDBLCLK:
      if (!ButtonName(static_cast<int>(wparam)).empty()) {
        pressed_ = hovered_ = static_cast<int>(wparam);
        SetCapture(window_);
        EmitState();
        return 0;
      }
      break;
    case WM_MOUSEMOVE:
      if (pressed_ != HTCLIENT) {
        POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        ClientToScreen(window_, &point);
        SetHover(static_cast<int>(HitTest(point, resizable)));
        return 0;
      }
      SetHover(HTCLIENT);
      break;
    case WM_LBUTTONUP:
    case WM_NCLBUTTONUP:
      if (pressed_ != HTCLIENT) {
        POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        if (message == WM_LBUTTONUP) ClientToScreen(window_, &point);
        const int pressed = pressed_;
        const bool activate = HitTest(point, resizable) == pressed;
        ResetInput();
        if (activate) InvokeButton(ButtonName(pressed));
        return 0;
      }
      // Never let DefWindowProc execute a second caption button action.
      if (message == WM_NCLBUTTONUP &&
          !ButtonName(static_cast<int>(wparam)).empty())
        return 0;
      break;
    case WM_NCMOUSELEAVE: {
      if (pressed_ == HTCLIENT) SetHover(HTCLIENT);
      LRESULT result = 0;
      if (DwmDefWindowProc(window_, message, wparam, lparam, &result))
        return result;
      break;
    }
    case WM_CAPTURECHANGED:
    case WM_CANCELMODE:
    case WM_KILLFOCUS:
    case WM_ENTERSIZEMOVE:
    case WM_ENTERMENULOOP:
      ResetInput();
      break;
    case WM_ACTIVATE:
    case WM_NCACTIVATE:
      if ((message == WM_ACTIVATE && LOWORD(wparam) == WA_INACTIVE) ||
          (message == WM_NCACTIVATE && !wparam))
        ResetInput();
      UpdateAppearance();
      EmitState();
      // Suppress native caption painting while retaining system activation.
      if (message == WM_NCACTIVATE)
        return DefWindowProc(window_, message, wparam, -1);
      break;
    case WM_SIZE: {
      const bool maximized = IsZoomed(window_) != FALSE;
      if (maximized_ != maximized) {
        maximized_ = maximized;
        EmitState();
      }
      if (wparam == SIZE_MINIMIZED) ResetInput();
      // A regular resize does not change caption state. In particular, leave
      // the system's mouse capture intact when restoring a window during drag.
      break;
    }
    case WM_SETTINGCHANGE:
    case WM_SYSCOLORCHANGE:
    case WM_THEMECHANGED:
    case WM_DWMCOMPOSITIONCHANGED:
      UpdateAppearance();
      EmitState();
      break;
    case WM_FONTCHANGE:
      font_family_ = ResolveCaptionFont();
      EmitState();
      break;
  }
  return std::nullopt;
}

LRESULT CALLBACK WindowsTitleBar::ChildProc(HWND window, UINT message,
                                            WPARAM wparam, LPARAM lparam,
                                            UINT_PTR id, DWORD_PTR reference) {
  auto* bar = reinterpret_cast<WindowsTitleBar*>(reference);
  if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(window, ChildProc, id);
  } else if (bar->enabled_) {
    if (message == WM_NCHITTEST) {
      const LRESULT hit = bar->HitTest(
          {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)}, bar->resizable_);
      // Only frame/caption areas pass through to the parent on this thread.
      if (hit != HTCLIENT && hit != HTNOWHERE) return HTTRANSPARENT;
    } else if (message == WM_MOUSEMOVE || message == WM_MOUSELEAVE) {
      bar->SetHover(HTCLIENT);
    } else if (message == WM_KILLFOCUS || message == WM_CANCELMODE) {
      bar->ResetInput();
    }
  }
  return DefSubclassProc(window, message, wparam, lparam);
}

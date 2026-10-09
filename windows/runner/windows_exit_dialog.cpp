// This is a WIP version; it does not need to be reviewed and is entirely temporary.
// At the time of creation, there is no design or technical specification for the final version of the dialog.
#include "windows_exit_dialog.h"

#include <dwmapi.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <gdiplus.h>
#include <windowsx.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iterator>
#include <optional>
#include <string>
#include <utility>
#include <variant>

#include "resource.h"

namespace {

constexpr char kWindowsExitDialogChannel[] = "trusttunnel/windows_exit_dialog";
constexpr wchar_t kDialogWindowClass[] = L"TRUSTTUNNEL_WINDOWS_EXIT_DIALOG";

constexpr int kDialogWidth = 260;
constexpr int kDialogHeight = 220;
constexpr int kSideInset = 16;
constexpr int kIconSize = 64;
constexpr int kIconTopInset = 20;
constexpr int kTitleTop = 100;
constexpr int kTitleHeight = 16;
constexpr int kMessageTop = 126;
constexpr int kMessageHeight = 28;
constexpr int kButtonTop = 172;
constexpr int kButtonHeight = 32;
constexpr int kButtonSpacing = 8;
constexpr int kCornerRadius = 24;
constexpr int kButtonCornerRadius = kButtonHeight / 2;
constexpr int kIconCornerRadius = 14;

constexpr wchar_t kDefaultTitle[] = L"Quit TrustTunnel?";
constexpr wchar_t kDefaultQuitButtonText[] = L"Quit";
constexpr wchar_t kDefaultDontQuitButtonText[] = L"Don't quit";

std::optional<std::wstring> Utf16FromUtf8(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }

  const int length =
      ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                            static_cast<int>(value.size()), nullptr, 0);
  if (length == 0) {
    return std::nullopt;
  }

  std::wstring result(length, L'\0');
  if (::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                            static_cast<int>(value.size()), result.data(),
                            length) == 0) {
    return std::nullopt;
  }

  return result;
}

const std::string* GetStringArgument(const flutter::EncodableMap& arguments,
                                     const char* name) {
  const auto iterator = arguments.find(flutter::EncodableValue(name));
  if (iterator == arguments.end()) {
    return nullptr;
  }

  return std::get_if<std::string>(&iterator->second);
}

std::optional<std::wstring> ReadStringArgument(
    const flutter::EncodableMap& arguments, const char* name,
    const wchar_t* fallback) {
  const std::string* value = GetStringArgument(arguments, name);
  return value == nullptr ? std::optional<std::wstring>(fallback)
                          : Utf16FromUtf8(*value);
}

UINT GetWindowDpi(HWND window) {
  using GetDpiForWindowProc = UINT(WINAPI*)(HWND);
  static const auto get_dpi_for_window = reinterpret_cast<GetDpiForWindowProc>(
      ::GetProcAddress(::GetModuleHandleW(L"user32.dll"), "GetDpiForWindow"));
  return get_dpi_for_window == nullptr || window == nullptr
             ? USER_DEFAULT_SCREEN_DPI
             : get_dpi_for_window(window);
}

void AddRoundedRect(Gdiplus::GraphicsPath* path, const Gdiplus::RectF& rect,
                    float radius) {
  const float diameter = radius * 2.0f;
  path->AddArc(rect.X, rect.Y, diameter, diameter, 180.0f, 90.0f);
  path->AddArc(rect.GetRight() - diameter, rect.Y, diameter, diameter, 270.0f,
               90.0f);
  path->AddArc(rect.GetRight() - diameter, rect.GetBottom() - diameter,
               diameter, diameter, 0.0f, 90.0f);
  path->AddArc(rect.X, rect.GetBottom() - diameter, diameter, diameter, 90.0f,
               90.0f);
  path->CloseFigure();
}

}  // namespace

class WindowsExitDialog::Impl {
 public:
  Impl(flutter::BinaryMessenger* messenger, HWND parent_window)
      : parent_window_(parent_window),
        channel_(
            std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                messenger, kWindowsExitDialogChannel,
                &flutter::StandardMethodCodec::GetInstance())) {
    Gdiplus::GdiplusStartupInput startup_input;
    if (Gdiplus::GdiplusStartup(&gdiplus_token_, &startup_input, nullptr) !=
        Gdiplus::Ok) {
      gdiplus_token_ = 0;
    }

    channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                   result) { HandleMethodCall(call, std::move(result)); });
  }

  ~Impl() {
    channel_->SetMethodCallHandler(nullptr);
    channel_.reset();

    if (dialog_window_ != nullptr) {
      ::DestroyWindow(dialog_window_);
    }
    if (gdiplus_token_ != 0) {
      Gdiplus::GdiplusShutdown(gdiplus_token_);
    }
  }

 private:
  struct Configuration {
    std::wstring title;
    std::wstring message;
    std::wstring quit_button_text;
    std::wstring dont_quit_button_text;
  };

  enum class Button {
    kNone,
    kQuit,
    kDontQuit,
  };

  enum class ShowResult {
    kQuit,
    kCancel,
    kUnavailable,
  };

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() != "show") {
      result->NotImplemented();
      return;
    }

    const auto* arguments =
        std::get_if<flutter::EncodableMap>(call.arguments());
    const flutter::EncodableMap empty_arguments;
    const auto& dialog_arguments =
        arguments == nullptr ? empty_arguments : *arguments;

    auto title = ReadStringArgument(dialog_arguments, "title", kDefaultTitle);
    auto message = ReadStringArgument(dialog_arguments, "message", L"");
    auto quit_button_text = ReadStringArgument(
        dialog_arguments, "quitButtonText", kDefaultQuitButtonText);
    auto dont_quit_button_text = ReadStringArgument(
        dialog_arguments, "dontQuitButtonText", kDefaultDontQuitButtonText);
    if (!title || !message || !quit_button_text || !dont_quit_button_text) {
      result->Error("invalid_arguments",
                    "Dialog arguments must contain valid UTF-8 strings");
      return;
    }

    Configuration configuration{
        std::move(*title),
        std::move(*message),
        std::move(*quit_button_text),
        std::move(*dont_quit_button_text),
    };
    switch (Show(configuration)) {
      case ShowResult::kQuit:
        result->Success(flutter::EncodableValue(true));
        return;
      case ShowResult::kCancel:
        result->Success(flutter::EncodableValue(false));
        return;
      case ShowResult::kUnavailable:
        result->Error("dialog_unavailable", "Unable to show the Windows exit dialog");
        return;
    }
  }

  ShowResult Show(const Configuration& configuration) {
    if (dialog_window_ != nullptr) {
      ::ShowWindow(dialog_window_, SW_SHOW);
      ::SetForegroundWindow(dialog_window_);
      return ShowResult::kCancel;
    }
    if (gdiplus_token_ == 0 || !RegisterWindowClass()) {
      return ShowResult::kUnavailable;
    }

    configuration_ = configuration;
    dpi_ = GetWindowDpi(parent_window_);
    should_quit_ = false;
    is_finished_ = false;
    decision_made_ = false;
    focused_button_ = Button::kDontQuit;
    hovered_button_ = Button::kNone;
    pressed_button_ = Button::kNone;

    const int width = Scale(kDialogWidth);
    const int height = Scale(kDialogHeight);
    const POINT origin = CalculateOrigin(width, height);

    dialog_window_ = ::CreateWindowExW(
        WS_EX_TOOLWINDOW | WS_EX_DLGMODALFRAME, kDialogWindowClass, L"",
        WS_POPUP, origin.x, origin.y, width, height, parent_window_, nullptr,
        ::GetModuleHandleW(nullptr), this);
    if (dialog_window_ == nullptr) {
      return ShowResult::kUnavailable;
    }

    ApplyWindowShape();
    ApplyWindowAppearance();

    const bool parent_was_enabled =
        parent_window_ != nullptr && ::IsWindowEnabled(parent_window_);
    if (parent_was_enabled) {
      ::EnableWindow(parent_window_, FALSE);
    }

    ::ShowWindow(dialog_window_, SW_SHOW);
    ::SetForegroundWindow(dialog_window_);
    ::SetFocus(dialog_window_);

    MSG message;
    bool received_quit_message = false;
    bool message_loop_failed = false;
    int quit_code = 0;
    while (!is_finished_) {
      const BOOL get_message_result = ::GetMessageW(&message, nullptr, 0, 0);
      if (get_message_result <= 0) {
        if (get_message_result == 0) {
          received_quit_message = true;
          quit_code = static_cast<int>(message.wParam);
        }
        message_loop_failed = true;
        break;
      }
      ::TranslateMessage(&message);
      ::DispatchMessageW(&message);
    }

    if (dialog_window_ != nullptr) {
      ::DestroyWindow(dialog_window_);
    }
    if (parent_was_enabled && ::IsWindow(parent_window_)) {
      ::EnableWindow(parent_window_, TRUE);
      if (!should_quit_) {
        ::SetForegroundWindow(parent_window_);
      }
    }
    if (received_quit_message) {
      ::PostQuitMessage(quit_code);
    }

    if (message_loop_failed || !decision_made_) {
      return ShowResult::kUnavailable;
    }
    return should_quit_ ? ShowResult::kQuit : ShowResult::kCancel;
  }

  bool RegisterWindowClass() const {
    WNDCLASSEXW existing_class{};
    existing_class.cbSize = sizeof(existing_class);
    if (::GetClassInfoExW(::GetModuleHandleW(nullptr), kDialogWindowClass,
                          &existing_class)) {
      return true;
    }

    WNDCLASSEXW window_class{};
    window_class.cbSize = sizeof(window_class);
    window_class.style = CS_HREDRAW | CS_VREDRAW | CS_DROPSHADOW;
    window_class.lpfnWndProc = WindowProc;
    window_class.hInstance = ::GetModuleHandleW(nullptr);
    window_class.hIcon = static_cast<HICON>(
        ::LoadImageW(window_class.hInstance, MAKEINTRESOURCEW(IDI_APP_ICON),
                     IMAGE_ICON, 0, 0, LR_DEFAULTSIZE | LR_SHARED));
    window_class.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
    window_class.lpszClassName = kDialogWindowClass;
    return ::RegisterClassExW(&window_class) != 0;
  }

  POINT CalculateOrigin(int width, int height) const {
    RECT anchor{};
    if (parent_window_ == nullptr || !::IsWindow(parent_window_) ||
        !::GetWindowRect(parent_window_, &anchor)) {
      const HMONITOR monitor =
          ::MonitorFromWindow(parent_window_, MONITOR_DEFAULTTOPRIMARY);
      MONITORINFO monitor_info{sizeof(monitor_info)};
      ::GetMonitorInfoW(monitor, &monitor_info);
      anchor = monitor_info.rcWork;
    }

    const HMONITOR monitor =
        ::MonitorFromRect(&anchor, MONITOR_DEFAULTTONEAREST);
    MONITORINFO monitor_info{sizeof(monitor_info)};
    ::GetMonitorInfoW(monitor, &monitor_info);
    const RECT work_area = monitor_info.rcWork;

    const int centered_x =
        anchor.left + (anchor.right - anchor.left - width) / 2;
    const int centered_y =
        anchor.top + (anchor.bottom - anchor.top - height) / 2;
    const int min_x = static_cast<int>(work_area.left);
    const int min_y = static_cast<int>(work_area.top);
    const int max_x =
        std::max(min_x, static_cast<int>(work_area.right) - width);
    const int max_y =
        std::max(min_y, static_cast<int>(work_area.bottom) - height);

    return {
        std::clamp(centered_x, min_x, max_x),
        std::clamp(centered_y, min_y, max_y),
    };
  }

  int Scale(int value) const {
    return static_cast<int>(std::lround(
        value * dpi_ / static_cast<double>(USER_DEFAULT_SCREEN_DPI)));
  }

  float Scale(float value) const {
    return value * dpi_ / static_cast<float>(USER_DEFAULT_SCREEN_DPI);
  }

  RECT ButtonRect(Button button) const {
    const int button_width =
        (kDialogWidth - kSideInset * 2 - kButtonSpacing) / 2;
    const int x = button == Button::kQuit
                      ? kSideInset
                      : kSideInset + button_width + kButtonSpacing;
    return {
        Scale(x),
        Scale(kButtonTop),
        Scale(x + button_width),
        Scale(kButtonTop + kButtonHeight),
    };
  }

  Button ButtonAt(POINT point) const {
    const RECT quit_rect = ButtonRect(Button::kQuit);
    if (::PtInRect(&quit_rect, point)) {
      return Button::kQuit;
    }

    const RECT dont_quit_rect = ButtonRect(Button::kDontQuit);
    return ::PtInRect(&dont_quit_rect, point) ? Button::kDontQuit
                                              : Button::kNone;
  }

  void ApplyWindowShape() const {
    RECT client_rect{};
    ::GetClientRect(dialog_window_, &client_rect);
    HRGN region = ::CreateRoundRectRgn(
        client_rect.left, client_rect.top, client_rect.right + 1,
        client_rect.bottom + 1, Scale(kCornerRadius * 2),
        Scale(kCornerRadius * 2));
    if (region == nullptr) {
      return;
    }
    if (::SetWindowRgn(dialog_window_, region, TRUE) == 0) {
      ::DeleteObject(region);
    }
  }

  void ApplyWindowAppearance() const {
    constexpr DWORD kDwmWindowCornerPreference = 33;
    constexpr int kRoundCornerPreference = 2;
    ::DwmSetWindowAttribute(
        dialog_window_,
        static_cast<DWMWINDOWATTRIBUTE>(kDwmWindowCornerPreference),
        &kRoundCornerPreference, sizeof(kRoundCornerPreference));

    const BOOL dark_mode = FALSE;
    constexpr DWORD kUseImmersiveDarkMode = 20;
    ::DwmSetWindowAttribute(
        dialog_window_, static_cast<DWMWINDOWATTRIBUTE>(kUseImmersiveDarkMode),
        &dark_mode, sizeof(dark_mode));

    HICON icon = static_cast<HICON>(::LoadImageW(
        ::GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
        0, 0, LR_DEFAULTSIZE | LR_SHARED));
    ::SendMessageW(dialog_window_, WM_SETICON, ICON_SMALL,
                   reinterpret_cast<LPARAM>(icon));
  }

  void Paint() const {
    PAINTSTRUCT paint{};
    HDC device_context = ::BeginPaint(dialog_window_, &paint);

    RECT client_rect{};
    ::GetClientRect(dialog_window_, &client_rect);
    const int width = client_rect.right - client_rect.left;
    const int height = client_rect.bottom - client_rect.top;

    Gdiplus::Bitmap buffer(width, height, PixelFormat32bppPARGB);
    Gdiplus::Graphics graphics(&buffer);
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHighQuality);
    graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);

    Gdiplus::LinearGradientBrush background_brush(
        Gdiplus::Point(0, 0), Gdiplus::Point(0, height),
        Gdiplus::Color(255, 252, 252, 252), Gdiplus::Color(255, 240, 240, 240));
    graphics.FillRectangle(&background_brush, 0, 0, width, height);

    Gdiplus::Pen border_pen(Gdiplus::Color(180, 255, 255, 255), Scale(1.0f));
    const Gdiplus::RectF border_rect(Scale(0.5f), Scale(0.5f),
                                     width - Scale(1.0f), height - Scale(1.0f));
    Gdiplus::GraphicsPath border_path;
    AddRoundedRect(&border_path, border_rect, Scale(kCornerRadius - 1.0f));
    graphics.DrawPath(&border_pen, &border_path);

    PaintIcon(graphics);
    PaintText(graphics);
    PaintButton(graphics, Button::kQuit, configuration_.quit_button_text);
    PaintButton(graphics, Button::kDontQuit,
                configuration_.dont_quit_button_text);

    Gdiplus::Graphics target(device_context);
    target.DrawImage(&buffer, 0, 0, width, height);
    ::EndPaint(dialog_window_, &paint);
  }

  void PaintIcon(Gdiplus::Graphics& graphics) const {
    const float x = Scale((kDialogWidth - kIconSize) / 2.0f);
    const float y = Scale(static_cast<float>(kIconTopInset));
    const float size = Scale(static_cast<float>(kIconSize));
    const Gdiplus::RectF icon_rect(x, y, size, size);

    const Gdiplus::RectF shadow_rect(x, y + Scale(1.0f), size, size);
    Gdiplus::GraphicsPath shadow_path;
    AddRoundedRect(&shadow_path, shadow_rect,
                   Scale(static_cast<float>(kIconCornerRadius)));
    Gdiplus::SolidBrush shadow_brush(Gdiplus::Color(42, 0, 0, 0));
    graphics.FillPath(&shadow_brush, &shadow_path);

    HICON icon = static_cast<HICON>(::LoadImageW(
        ::GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
        static_cast<int>(size), static_cast<int>(size), LR_DEFAULTCOLOR));
    if (icon != nullptr) {
      Gdiplus::Bitmap icon_bitmap(icon);
      if (icon_bitmap.GetLastStatus() == Gdiplus::Ok) {
        graphics.DrawImage(&icon_bitmap, icon_rect);
      } else {
        PaintPlaceholderIcon(graphics, icon_rect);
      }
      ::DestroyIcon(icon);
      return;
    }

    PaintPlaceholderIcon(graphics, icon_rect);
  }

  void PaintPlaceholderIcon(Gdiplus::Graphics& graphics,
                            const Gdiplus::RectF& icon_rect) const {
    Gdiplus::GraphicsPath icon_path;
    AddRoundedRect(&icon_path, icon_rect,
                   Scale(static_cast<float>(kIconCornerRadius)));
    Gdiplus::SolidBrush background_brush(Gdiplus::Color(255, 255, 255, 255));
    graphics.FillPath(&background_brush, &icon_path);

    const float inset = Scale(11.0f);
    Gdiplus::SolidBrush accent_brush(Gdiplus::Color(255, 51, 122, 184));
    graphics.FillEllipse(&accent_brush, icon_rect.X + inset,
                         icon_rect.Y + inset, icon_rect.Width - inset * 2,
                         icon_rect.Height - inset * 2);

    Gdiplus::Pen check_pen(Gdiplus::Color(255, 255, 255, 255), Scale(4.0f));
    check_pen.SetStartCap(Gdiplus::LineCapRound);
    check_pen.SetEndCap(Gdiplus::LineCapRound);
    check_pen.SetLineJoin(Gdiplus::LineJoinRound);
    Gdiplus::PointF check_points[] = {
        {icon_rect.X + Scale(24.0f), icon_rect.Y + Scale(31.0f)},
        {icon_rect.X + Scale(31.0f), icon_rect.Y + Scale(38.0f)},
        {icon_rect.X + Scale(42.0f), icon_rect.Y + Scale(25.0f)},
    };
    graphics.DrawLines(&check_pen, check_points,
                       static_cast<int>(std::size(check_points)));
  }

  void PaintText(Gdiplus::Graphics& graphics) const {
    Gdiplus::SolidBrush text_brush(Gdiplus::Color(255, 0, 0, 0));
    Gdiplus::Font title_font(L"Segoe UI", Scale(13.0f), Gdiplus::FontStyleBold,
                             Gdiplus::UnitPixel);
    Gdiplus::Font message_font(L"Segoe UI", Scale(11.0f),
                               Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);

    Gdiplus::StringFormat title_format;
    title_format.SetAlignment(Gdiplus::StringAlignmentCenter);
    title_format.SetLineAlignment(Gdiplus::StringAlignmentCenter);
    title_format.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
    title_format.SetTrimming(Gdiplus::StringTrimmingEllipsisCharacter);

    Gdiplus::StringFormat message_format;
    message_format.SetAlignment(Gdiplus::StringAlignmentCenter);
    message_format.SetLineAlignment(Gdiplus::StringAlignmentCenter);
    message_format.SetTrimming(Gdiplus::StringTrimmingEllipsisWord);

    const Gdiplus::RectF title_rect(
        Scale(static_cast<float>(kSideInset)),
        Scale(static_cast<float>(kTitleTop)),
        Scale(static_cast<float>(kDialogWidth - kSideInset * 2)),
        Scale(static_cast<float>(kTitleHeight)));
    graphics.DrawString(configuration_.title.c_str(), -1, &title_font,
                        title_rect, &title_format, &text_brush);

    const Gdiplus::RectF message_rect(
        Scale(static_cast<float>(kSideInset)),
        Scale(static_cast<float>(kMessageTop)),
        Scale(static_cast<float>(kDialogWidth - kSideInset * 2)),
        Scale(static_cast<float>(kMessageHeight)));
    graphics.DrawString(configuration_.message.c_str(), -1, &message_font,
                        message_rect, &message_format, &text_brush);
  }

  void PaintButton(Gdiplus::Graphics& graphics, Button button,
                   const std::wstring& title) const {
    const RECT rectangle = ButtonRect(button);
    const Gdiplus::RectF button_rect(
        static_cast<float>(rectangle.left), static_cast<float>(rectangle.top),
        static_cast<float>(rectangle.right - rectangle.left),
        static_cast<float>(rectangle.bottom - rectangle.top));
    Gdiplus::GraphicsPath button_path;
    AddRoundedRect(&button_path, button_rect,
                   Scale(static_cast<float>(kButtonCornerRadius)));

    const bool is_primary = button == Button::kDontQuit;
    const bool is_pressed = button == pressed_button_;
    const bool is_hovered = button == hovered_button_;
    Gdiplus::Color background_color;
    if (is_primary) {
      background_color = is_pressed   ? Gdiplus::Color(255, 0, 93, 204)
                         : is_hovered ? Gdiplus::Color(255, 24, 132, 255)
                                      : Gdiplus::Color(255, 0, 122, 255);
    } else {
      background_color = is_pressed   ? Gdiplus::Color(255, 215, 215, 215)
                         : is_hovered ? Gdiplus::Color(255, 247, 247, 247)
                                      : Gdiplus::Color(255, 235, 235, 235);
    }

    Gdiplus::SolidBrush background_brush(background_color);
    graphics.FillPath(&background_brush, &button_path);

    if (button == focused_button_) {
      Gdiplus::Pen focus_pen(is_primary ? Gdiplus::Color(150, 255, 255, 255)
                                        : Gdiplus::Color(130, 0, 122, 255),
                             Scale(1.5f));
      graphics.DrawPath(&focus_pen, &button_path);
    }

    Gdiplus::Font button_font(L"Segoe UI", Scale(13.0f),
                              Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
    Gdiplus::SolidBrush text_brush(is_primary
                                       ? Gdiplus::Color(255, 255, 255, 255)
                                       : Gdiplus::Color(255, 0, 0, 0));
    Gdiplus::StringFormat text_format;
    text_format.SetAlignment(Gdiplus::StringAlignmentCenter);
    text_format.SetLineAlignment(Gdiplus::StringAlignmentCenter);
    text_format.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
    text_format.SetTrimming(Gdiplus::StringTrimmingEllipsisCharacter);
    graphics.DrawString(title.c_str(), -1, &button_font, button_rect,
                        &text_format, &text_brush);
  }

  void Finish(bool should_quit) {
    should_quit_ = should_quit;
    decision_made_ = true;
    is_finished_ = true;
    if (dialog_window_ != nullptr) {
      ::DestroyWindow(dialog_window_);
    }
  }

  void ToggleFocusedButton() {
    focused_button_ =
        focused_button_ == Button::kQuit ? Button::kDontQuit : Button::kQuit;
    ::InvalidateRect(dialog_window_, nullptr, FALSE);
  }

  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam) {
    switch (message) {
      case WM_PAINT:
        Paint();
        return 0;
      case WM_ERASEBKGND:
        return 1;
      case WM_CLOSE:
        Finish(false);
        return 0;
      case WM_DESTROY:
        is_finished_ = true;
        return 0;
      case WM_NCDESTROY:
        dialog_window_ = nullptr;
        ::SetWindowLongPtrW(window, GWLP_USERDATA, 0);
        return ::DefWindowProcW(window, message, wparam, lparam);
      case WM_DPICHANGED: {
        dpi_ = HIWORD(wparam);
        const auto* suggested_rect = reinterpret_cast<RECT*>(lparam);
        ::SetWindowPos(window, nullptr, suggested_rect->left,
                       suggested_rect->top,
                       suggested_rect->right - suggested_rect->left,
                       suggested_rect->bottom - suggested_rect->top,
                       SWP_NOACTIVATE | SWP_NOZORDER);
        ApplyWindowShape();
        ::InvalidateRect(window, nullptr, FALSE);
        return 0;
      }
      case WM_MOUSEMOVE: {
        const POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        const Button hovered_button = ButtonAt(point);
        if (hovered_button_ != hovered_button) {
          hovered_button_ = hovered_button;
          ::InvalidateRect(window, nullptr, FALSE);
        }
        TRACKMOUSEEVENT tracking{sizeof(tracking), TME_LEAVE, window,
                                 HOVER_DEFAULT};
        ::TrackMouseEvent(&tracking);
        return 0;
      }
      case WM_MOUSELEAVE:
        hovered_button_ = Button::kNone;
        ::InvalidateRect(window, nullptr, FALSE);
        return 0;
      case WM_LBUTTONDOWN: {
        const POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        pressed_button_ = ButtonAt(point);
        if (pressed_button_ != Button::kNone) {
          focused_button_ = pressed_button_;
          ::SetCapture(window);
          ::InvalidateRect(window, nullptr, FALSE);
          return 0;
        }

        ::ReleaseCapture();
        POINT screen_point{};
        ::GetCursorPos(&screen_point);
        ::SendMessageW(window, WM_NCLBUTTONDOWN, HTCAPTION,
                       MAKELPARAM(screen_point.x, screen_point.y));
        return 0;
      }
      case WM_LBUTTONUP: {
        if (pressed_button_ == Button::kNone) {
          return 0;
        }
        const POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        const Button released_button = ButtonAt(point);
        const Button pressed_button = pressed_button_;
        pressed_button_ = Button::kNone;
        if (::GetCapture() == window) {
          ::ReleaseCapture();
        }
        if (released_button == pressed_button) {
          Finish(pressed_button == Button::kQuit);
        } else {
          ::InvalidateRect(window, nullptr, FALSE);
        }
        return 0;
      }
      case WM_CAPTURECHANGED:
        pressed_button_ = Button::kNone;
        ::InvalidateRect(window, nullptr, FALSE);
        return 0;
      case WM_KEYDOWN:
        switch (wparam) {
          case VK_ESCAPE:
            Finish(false);
            return 0;
          case VK_TAB:
          case VK_LEFT:
          case VK_RIGHT:
            ToggleFocusedButton();
            return 0;
          case VK_RETURN:
          case VK_SPACE:
            Finish(focused_button_ == Button::kQuit);
            return 0;
          default:
            break;
        }
        break;
      case WM_SETCURSOR:
        if (LOWORD(lparam) == HTCLIENT) {
          POINT point{};
          ::GetCursorPos(&point);
          ::ScreenToClient(window, &point);
          ::SetCursor(::LoadCursorW(nullptr, ButtonAt(point) == Button::kNone
                                                 ? IDC_ARROW
                                                 : IDC_HAND));
          return TRUE;
        }
        break;
      default:
        break;
    }

    return ::DefWindowProcW(window, message, wparam, lparam);
  }

  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) {
    if (message == WM_NCCREATE) {
      const auto* create_struct = reinterpret_cast<CREATESTRUCTW*>(lparam);
      auto* dialog = static_cast<Impl*>(create_struct->lpCreateParams);
      ::SetWindowLongPtrW(window, GWLP_USERDATA,
                          reinterpret_cast<LONG_PTR>(dialog));
      dialog->dialog_window_ = window;
    }

    auto* dialog =
        reinterpret_cast<Impl*>(::GetWindowLongPtrW(window, GWLP_USERDATA));
    return dialog == nullptr
               ? ::DefWindowProcW(window, message, wparam, lparam)
               : dialog->HandleMessage(window, message, wparam, lparam);
  }

  HWND parent_window_ = nullptr;
  HWND dialog_window_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  ULONG_PTR gdiplus_token_ = 0;
  Configuration configuration_;
  UINT dpi_ = USER_DEFAULT_SCREEN_DPI;
  Button focused_button_ = Button::kDontQuit;
  Button hovered_button_ = Button::kNone;
  Button pressed_button_ = Button::kNone;
  bool should_quit_ = false;
  bool is_finished_ = false;
  bool decision_made_ = false;
};

WindowsExitDialog::WindowsExitDialog(flutter::BinaryMessenger* messenger,
                                     HWND parent_window)
    : impl_(std::make_unique<Impl>(messenger, parent_window)) {}

WindowsExitDialog::~WindowsExitDialog() = default;

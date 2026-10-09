#include "windows_exit_dialog.h"

#include <d2d1.h>
#include <dwmapi.h>
#include <dwrite.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windowsx.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <optional>
#include <string>
#include <utility>
#include <variant>

#include "resource.h"

namespace {

constexpr char kWindowsExitDialogChannel[] = "trusttunnel/windows_exit_dialog";
constexpr wchar_t kDialogWindowClass[] = L"TRUSTTUNNEL_WINDOWS_EXIT_DIALOG";

// All layout values are Windows device-independent pixels (96 DPI).
constexpr int kDialogWidth = 448;
constexpr int kDialogHeight = 188;
constexpr int kSideInset = 24;
constexpr int kTitleTop = 24;
constexpr int kTitleHeight = 28;
constexpr int kMessageTop = kTitleTop + kTitleHeight + 12;
constexpr int kMessageHeight = 20;
constexpr int kDividerTop = kMessageTop + kMessageHeight + 24;
constexpr int kButtonTop = kDividerTop + 24;
constexpr int kButtonHeight = 32;
constexpr int kButtonSpacing = 8;
constexpr int kCornerRadius = 8;
constexpr int kButtonCornerRadius = 4;

constexpr uint32_t kContentColor = 0xFFFFFF;
constexpr uint32_t kFooterColor = 0xF3F3F3;
constexpr uint32_t kDividerColor = 0xE5E5E5;
constexpr uint32_t kPrimaryButtonColor = 0x005FB8;
constexpr uint32_t kPrimaryButtonBorderColor = 0x156CBE;
constexpr uint32_t kSecondaryButtonColor = 0xFBFBFB;
constexpr uint32_t kSecondaryButtonBorderColor = 0xE5E5E5;
constexpr uint32_t kDialogBorderColor = 0x757575;
constexpr float kDialogBorderOpacity = 0x66 / 255.0f;
constexpr float kTextOpacity = 0xE4 / 255.0f;

constexpr wchar_t kDefaultTitle[] = L"Quit TrustTunnel?";
constexpr wchar_t kDefaultMessage[] =
    L"This will disconnect you from the active server";
constexpr wchar_t kDefaultQuitButtonText[] = L"Quit";
constexpr wchar_t kDefaultDontQuitButtonText[] = L"Don\u2019t quit";

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

const wchar_t* ResolveDialogFont(IDWriteFactory* factory) {
  Microsoft::WRL::ComPtr<IDWriteFontCollection> fonts;
  if (SUCCEEDED(factory->GetSystemFontCollection(&fonts, TRUE))) {
    // Match the family selection used by WindowsTitleBar / Flutter.
    const wchar_t* candidates[] = {L"Segoe UI Variable",
                                   L"Segoe UI Variable Text",
                                   L"Segoe UI Variable Small"};
    for (const auto* candidate : candidates) {
      UINT32 index = 0;
      BOOL exists = FALSE;
      if (SUCCEEDED(fonts->FindFamilyName(candidate, &index, &exists)) &&
          exists) {
        return candidate;
      }
    }
  }
  return L"Segoe UI";
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
    if (call.method_name() == "cancelForInstaller") {
      // Setup must not wait for a user's response to an earlier Quit request.
      if (dialog_window_ != nullptr) Finish(false);
      result->Success();
      return;
    }
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
    auto message =
        ReadStringArgument(dialog_arguments, "message", kDefaultMessage);
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
        result->Error("dialog_unavailable",
                      "Unable to show the Windows exit dialog");
        return;
    }
  }

  ShowResult Show(const Configuration& configuration) {
    if (dialog_window_ != nullptr) {
      ::ShowWindow(dialog_window_, SW_SHOW);
      ::SetForegroundWindow(dialog_window_);
      return ShowResult::kCancel;
    }
    if (!InitializeDrawingResources() || !RegisterWindowClass()) {
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
    keyboard_focus_visible_ = false;

    const int width = Scale(kDialogWidth);
    const int height = Scale(kDialogHeight);
    const POINT origin = CalculateOrigin(width, height);

    dialog_window_ = ::CreateWindowExW(
        WS_EX_TOOLWINDOW, kDialogWindowClass, L"",
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
      if (!should_quit_ && ::IsWindowVisible(parent_window_)) {
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

  D2D1_RECT_F ButtonLayoutRect(Button button) const {
    const int button_width =
        (kDialogWidth - kSideInset * 2 - kButtonSpacing) / 2;
    const int x = button == Button::kDontQuit
                      ? kSideInset
                      : kSideInset + button_width + kButtonSpacing;
    return {
        static_cast<float>(x),
        static_cast<float>(kButtonTop),
        static_cast<float>(x + button_width),
        static_cast<float>(kButtonTop + kButtonHeight),
    };
  }

  RECT ButtonRect(Button button) const {
    const auto rect = ButtonLayoutRect(button);
    return {Scale(static_cast<int>(rect.left)),
            Scale(static_cast<int>(rect.top)),
            Scale(static_cast<int>(rect.right)),
            Scale(static_cast<int>(rect.bottom))};
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

  bool CreateTextFormat(float size, float line_height, float baseline,
                        DWRITE_FONT_WEIGHT weight,
                        DWRITE_TEXT_ALIGNMENT alignment,
                        IDWriteTextFormat** format) const {
    if (FAILED(text_factory_->CreateTextFormat(
            ResolveDialogFont(text_factory_.Get()), nullptr, weight,
            DWRITE_FONT_STYLE_NORMAL, DWRITE_FONT_STRETCH_NORMAL, size, L"",
            format))) {
      return false;
    }

    Microsoft::WRL::ComPtr<IDWriteInlineObject> ellipsis;
    const DWRITE_TRIMMING trimming{DWRITE_TRIMMING_GRANULARITY_CHARACTER, 0, 0};
    return SUCCEEDED((*format)->SetTextAlignment(alignment)) &&
           SUCCEEDED((*format)->SetParagraphAlignment(
               DWRITE_PARAGRAPH_ALIGNMENT_CENTER)) &&
           SUCCEEDED(
               (*format)->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP)) &&
           SUCCEEDED((*format)->SetLineSpacing(
               DWRITE_LINE_SPACING_METHOD_UNIFORM, line_height, baseline)) &&
           SUCCEEDED(
               text_factory_->CreateEllipsisTrimmingSign(*format, &ellipsis)) &&
           SUCCEEDED((*format)->SetTrimming(&trimming, ellipsis.Get()));
  }

  bool InitializeDrawingResources() {
    if (!drawing_factory_ &&
        FAILED(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED,
                                 drawing_factory_.GetAddressOf()))) {
      return false;
    }
    if (!text_factory_ &&
        FAILED(DWriteCreateFactory(
            DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory),
            reinterpret_cast<IUnknown**>(text_factory_.GetAddressOf())))) {
      return false;
    }
    if (!title_format_ || !message_format_ || !button_format_) {
      if (!CreateTextFormat(20.0f, kTitleHeight, 21.0f,
                            DWRITE_FONT_WEIGHT_SEMI_BOLD,
                            DWRITE_TEXT_ALIGNMENT_LEADING,
                            title_format_.ReleaseAndGetAddressOf()) ||
          !CreateTextFormat(14.0f, kMessageHeight, 15.0f,
                            DWRITE_FONT_WEIGHT_NORMAL,
                            DWRITE_TEXT_ALIGNMENT_LEADING,
                            message_format_.ReleaseAndGetAddressOf()) ||
          !CreateTextFormat(14.0f, 20.0f, 15.0f, DWRITE_FONT_WEIGHT_NORMAL,
                            DWRITE_TEXT_ALIGNMENT_CENTER,
                            button_format_.ReleaseAndGetAddressOf())) {
        title_format_.Reset();
        message_format_.Reset();
        button_format_.Reset();
        return false;
      }
    }
    if (!render_target_) {
      // The DC target buffers drawing internally before copying it to the
      // window.
      const auto properties = D2D1::RenderTargetProperties(
          D2D1_RENDER_TARGET_TYPE_DEFAULT,
          D2D1::PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM,
                            D2D1_ALPHA_MODE_IGNORE));
      if (FAILED(drawing_factory_->CreateDCRenderTarget(
              &properties, render_target_.GetAddressOf()))) {
        return false;
      }
    }
    if (!brush_ && FAILED(render_target_->CreateSolidColorBrush(
                       D2D1::ColorF(0x000000), brush_.GetAddressOf()))) {
      render_target_.Reset();
      return false;
    }
    return true;
  }

  void SetBrushColor(uint32_t color, float opacity = 1.0f) const {
    brush_->SetColor(D2D1::ColorF(color, opacity));
  }

  void PaintText(const std::wstring& text, IDWriteTextFormat* format,
                 const D2D1_RECT_F& rect, uint32_t color,
                 float opacity = 1.0f) const {
    SetBrushColor(color, opacity);
    render_target_->DrawText(text.c_str(), static_cast<UINT32>(text.size()),
                             format, rect, brush_.Get(),
                             D2D1_DRAW_TEXT_OPTIONS_CLIP);
  }

  void Paint() {
    PAINTSTRUCT paint{};
    HDC device_context = ::BeginPaint(dialog_window_, &paint);
    RECT client_rect{};
    ::GetClientRect(dialog_window_, &client_rect);
    if (!InitializeDrawingResources() ||
        FAILED(render_target_->BindDC(device_context, &client_rect))) {
      ::EndPaint(dialog_window_, &paint);
      // Show reports an unavailable dialog without confirming an exit.
      is_finished_ = true;
      return;
    }

    const float dpi = static_cast<float>(dpi_);
    render_target_->SetDpi(dpi, dpi);
    const auto size = render_target_->GetSize();
    render_target_->BeginDraw();
    render_target_->SetTransform(D2D1::Matrix3x2F::Identity());
    render_target_->Clear(D2D1::ColorF(kContentColor));

    // Fill the separator as a rectangle so it starts exactly at y = 108 DIPs.
    render_target_->SetAntialiasMode(D2D1_ANTIALIAS_MODE_ALIASED);
    SetBrushColor(kFooterColor);
    render_target_->FillRectangle(
        D2D1::RectF(0.0f, kDividerTop, size.width, size.height), brush_.Get());
    SetBrushColor(kDividerColor);
    render_target_->FillRectangle(
        D2D1::RectF(0.0f, kDividerTop, size.width, kDividerTop + 1.0f),
        brush_.Get());
    render_target_->SetAntialiasMode(D2D1_ANTIALIAS_MODE_PER_PRIMITIVE);

    PaintText(configuration_.title, title_format_.Get(),
              D2D1::RectF(kSideInset, kTitleTop, kDialogWidth - kSideInset,
                          kTitleTop + kTitleHeight),
              0x000000, kTextOpacity);
    PaintText(configuration_.message, message_format_.Get(),
              D2D1::RectF(kSideInset, kMessageTop, kDialogWidth - kSideInset,
                          kMessageTop + kMessageHeight),
              0x000000, kTextOpacity);
    PaintButton(Button::kDontQuit, configuration_.dont_quit_button_text);
    PaintButton(Button::kQuit, configuration_.quit_button_text);

    SetBrushColor(kDialogBorderColor, kDialogBorderOpacity);
    render_target_->DrawRoundedRectangle(
        D2D1::RoundedRect(
            D2D1::RectF(0.5f, 0.5f, size.width - 0.5f, size.height - 0.5f),
            kCornerRadius - 0.5f, kCornerRadius - 0.5f),
        brush_.Get(), 1.0f);

    const HRESULT result = render_target_->EndDraw();
    ::EndPaint(dialog_window_, &paint);
    if (result == D2DERR_RECREATE_TARGET) {
      brush_.Reset();
      render_target_.Reset();
      ::InvalidateRect(dialog_window_, nullptr, FALSE);
    } else if (FAILED(result)) {
      is_finished_ = true;
    }
  }

  void PaintButton(Button button, const std::wstring& title) const {
    const auto rect = ButtonLayoutRect(button);
    // Inset the stroke by half its width to keep the button bounds exact.
    const auto shape = D2D1::RoundedRect(
        D2D1::RectF(rect.left + 0.5f, rect.top + 0.5f, rect.right - 0.5f,
                    rect.bottom - 0.5f),
        kButtonCornerRadius - 0.5f, kButtonCornerRadius - 0.5f);
    const bool is_primary = button == Button::kDontQuit;
    const bool is_pressed = button == pressed_button_;
    const bool is_hovered = button == hovered_button_;
    const uint32_t background_color =
        is_primary ? (is_pressed   ? 0x0054A3
                      : is_hovered ? 0x0059AD
                                   : kPrimaryButtonColor)
                   : (is_pressed   ? 0xF3F3F3
                      : is_hovered ? 0xF6F6F6
                                   : kSecondaryButtonColor);
    SetBrushColor(background_color);
    render_target_->FillRoundedRectangle(shape, brush_.Get());
    SetBrushColor(is_primary ? kPrimaryButtonBorderColor
                             : kSecondaryButtonBorderColor);
    render_target_->DrawRoundedRectangle(shape, brush_.Get(), 1.0f);

    if (keyboard_focus_visible_ && button == focused_button_) {
      SetBrushColor(is_primary ? 0xFFFFFF : 0x000000,
                    is_primary ? 1.0f : kTextOpacity);
      render_target_->DrawRoundedRectangle(
          D2D1::RoundedRect(D2D1::RectF(rect.left + 2.5f, rect.top + 2.5f,
                                        rect.right - 2.5f, rect.bottom - 2.5f),
                            2.0f, 2.0f),
          brush_.Get(), 1.0f);
    }

    PaintText(title, button_format_.Get(), rect,
              is_primary ? 0xFFFFFF : 0x000000,
              is_primary ? 1.0f : kTextOpacity);
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
    keyboard_focus_visible_ = true;
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
          keyboard_focus_visible_ = false;
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
  Microsoft::WRL::ComPtr<ID2D1Factory> drawing_factory_;
  Microsoft::WRL::ComPtr<IDWriteFactory> text_factory_;
  Microsoft::WRL::ComPtr<IDWriteTextFormat> title_format_;
  Microsoft::WRL::ComPtr<IDWriteTextFormat> message_format_;
  Microsoft::WRL::ComPtr<IDWriteTextFormat> button_format_;
  Microsoft::WRL::ComPtr<ID2D1DCRenderTarget> render_target_;
  Microsoft::WRL::ComPtr<ID2D1SolidColorBrush> brush_;
  Configuration configuration_;
  UINT dpi_ = USER_DEFAULT_SCREEN_DPI;
  Button focused_button_ = Button::kDontQuit;
  Button hovered_button_ = Button::kNone;
  Button pressed_button_ = Button::kNone;
  bool keyboard_focus_visible_ = false;
  bool should_quit_ = false;
  bool is_finished_ = false;
  bool decision_made_ = false;
};

WindowsExitDialog::WindowsExitDialog(flutter::BinaryMessenger* messenger,
                                     HWND parent_window)
    : impl_(std::make_unique<Impl>(messenger, parent_window)) {}

WindowsExitDialog::~WindowsExitDialog() = default;

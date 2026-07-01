#include "tray_manager_plugin.h"

#include <shlwapi.h>
#include <wincodec.h>

namespace tray_manager {

namespace {

template <typename T> class ComPtr {
public:
  ComPtr() : ptr_(nullptr) {}
  ~ComPtr() {
    if (ptr_) {
      ptr_->Release();
      ptr_ = nullptr;
    }
  }

private:
  ComPtr(const ComPtr &);
  ComPtr &operator=(const ComPtr &);

public:
  T *Get() const { return ptr_; }
  T **GetAddressOf() {
    Reset();
    return &ptr_;
  }
  void Attach(T *p) {
    Reset();
    ptr_ = p;
  }
  T *operator->() const { return ptr_; }
  operator bool() const { return ptr_ != nullptr; }

private:
  void Reset() {
    if (ptr_) {
      ptr_->Release();
      ptr_ = nullptr;
    }
  }

  T *ptr_;
};

} // namespace

HICON TrayManagerPlugin::CreateIconFromPng(
    const std::vector<uint8_t> &png_data) {
  if (png_data.empty())
    return nullptr;

  // Create WIC factory
  ComPtr<IWICImagingFactory> factory;
  HRESULT hr =
      CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER,
                       IID_PPV_ARGS(factory.GetAddressOf()));
  if (FAILED(hr) || !factory)
    return nullptr;

  // Create stream from memory
  ComPtr<IStream> stream;
  stream.Attach(
      SHCreateMemStream(png_data.data(), static_cast<UINT>(png_data.size())));
  if (!stream) {
    return nullptr;
  }

  // Create decoder
  ComPtr<IWICBitmapDecoder> decoder;
  hr = factory->CreateDecoderFromStream(stream.Get(), nullptr,
                                        WICDecodeMetadataCacheOnDemand,
                                        decoder.GetAddressOf());
  if (FAILED(hr) || !decoder) {
    return nullptr;
  }

  // Get first frame
  ComPtr<IWICBitmapFrameDecode> frame;
  hr = decoder->GetFrame(0, frame.GetAddressOf());
  if (FAILED(hr) || !frame) {
    return nullptr;
  }

  // Convert to 32bppPBGRA (pre-multiplied alpha) for proper transparency
  ComPtr<IWICFormatConverter> converter;
  hr = factory->CreateFormatConverter(converter.GetAddressOf());
  if (FAILED(hr) || !converter) {
    return nullptr;
  }

  hr = converter->Initialize(
      frame.Get(), GUID_WICPixelFormat32bppPBGRA, // Pre-multiplied BGRA
      WICBitmapDitherTypeNone, nullptr, 0.0, WICBitmapPaletteTypeCustom);
  if (FAILED(hr)) {
    return nullptr;
  }

  // Get dimensions
  UINT width = 0, height = 0;
  converter->GetSize(&width, &height);
  if (width == 0 || height == 0) {
    return nullptr;
  }

  // Create DIB section for color bitmap with alpha
  BITMAPV5HEADER bi = {};
  bi.bV5Size = sizeof(BITMAPV5HEADER);
  bi.bV5Width = static_cast<LONG>(width);
  bi.bV5Height = -static_cast<LONG>(height); // Top-down
  bi.bV5Planes = 1;
  bi.bV5BitCount = 32;
  bi.bV5Compression = BI_BITFIELDS;
  bi.bV5RedMask = 0x00FF0000;
  bi.bV5GreenMask = 0x0000FF00;
  bi.bV5BlueMask = 0x000000FF;
  bi.bV5AlphaMask = 0xFF000000;

  void *bits = nullptr;
  HDC hdc = GetDC(nullptr);
  HBITMAP hBitmap = CreateDIBSection(hdc, reinterpret_cast<BITMAPINFO *>(&bi),
                                     DIB_RGB_COLORS, &bits, nullptr, 0);
  ReleaseDC(nullptr, hdc);

  if (!hBitmap || !bits) {
    return nullptr;
  }

  // Copy pixels
  UINT stride = width * 4;
  UINT bufferSize = stride * height;
  hr = converter->CopyPixels(nullptr, stride, bufferSize,
                             static_cast<BYTE *>(bits));

  if (FAILED(hr)) {
    DeleteObject(hBitmap);
    return nullptr;
  }

  // Create monochrome mask bitmap
  HBITMAP hMask = CreateBitmap(width, height, 1, 1, nullptr);
  if (!hMask) {
    DeleteObject(hBitmap);
    return nullptr;
  }

  // Create icon with alpha channel
  ICONINFO iconInfo = {};
  iconInfo.fIcon = TRUE;
  iconInfo.hbmMask = hMask;
  iconInfo.hbmColor = hBitmap;

  HICON hIcon = CreateIconIndirect(&iconInfo);

  DeleteObject(hBitmap);
  DeleteObject(hMask);

  return hIcon;
}

HBITMAP
TrayManagerPlugin::CreateBitmapFromPng(const std::vector<uint8_t> &png_data) {
  if (png_data.empty())
    return nullptr;

  // Create WIC factory
  ComPtr<IWICImagingFactory> factory;
  HRESULT hr =
      CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER,
                       IID_PPV_ARGS(factory.GetAddressOf()));
  if (FAILED(hr) || !factory)
    return nullptr;

  // Create stream from memory
  ComPtr<IStream> stream;
  stream.Attach(
      SHCreateMemStream(png_data.data(), static_cast<UINT>(png_data.size())));
  if (!stream) {
    return nullptr;
  }

  // Create decoder
  ComPtr<IWICBitmapDecoder> decoder;
  hr = factory->CreateDecoderFromStream(stream.Get(), nullptr,
                                        WICDecodeMetadataCacheOnDemand,
                                        decoder.GetAddressOf());
  if (FAILED(hr) || !decoder) {
    return nullptr;
  }

  // Get first frame
  ComPtr<IWICBitmapFrameDecode> frame;
  hr = decoder->GetFrame(0, frame.GetAddressOf());
  if (FAILED(hr) || !frame) {
    return nullptr;
  }

  // Convert to 32bppPBGRA (pre-multiplied alpha) for proper transparency
  ComPtr<IWICFormatConverter> converter;
  hr = factory->CreateFormatConverter(converter.GetAddressOf());
  if (FAILED(hr) || !converter) {
    return nullptr;
  }

  hr = converter->Initialize(frame.Get(), GUID_WICPixelFormat32bppPBGRA,
                             WICBitmapDitherTypeNone, nullptr, 0.0,
                             WICBitmapPaletteTypeCustom);
  if (FAILED(hr)) {
    return nullptr;
  }

  // Get original dimensions
  UINT origWidth = 0, origHeight = 0;
  converter->GetSize(&origWidth, &origHeight);
  if (origWidth == 0 || origHeight == 0) {
    return nullptr;
  }

  // Base height of 12 pixels, scaled by system DPI
  HDC screenDC = GetDC(nullptr);
  int dpi = GetDeviceCaps(screenDC, LOGPIXELSY);
  ReleaseDC(nullptr, screenDC);
  if (dpi <= 0)
    dpi = 96; // Fallback to standard DPI

  UINT targetHeight = (12 * dpi) / 96;
  if (targetHeight == 0)
    targetHeight = 12;
  UINT targetWidth = (origWidth * targetHeight) / origHeight;
  if (targetWidth == 0)
    targetWidth = 1;

  // Scale to target size
  ComPtr<IWICBitmapScaler> scaler;
  hr = factory->CreateBitmapScaler(scaler.GetAddressOf());
  if (FAILED(hr) || !scaler) {
    return nullptr;
  }

  hr = scaler->Initialize(converter.Get(), targetWidth, targetHeight,
                          WICBitmapInterpolationModeHighQualityCubic);
  if (FAILED(hr)) {
    return nullptr;
  }

  // Create DIB section for bitmap with alpha
  BITMAPINFO bmi = {};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = static_cast<LONG>(targetWidth);
  bmi.bmiHeader.biHeight = -static_cast<LONG>(targetHeight); // Top-down
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 32;
  bmi.bmiHeader.biCompression = BI_RGB;

  void *bits = nullptr;
  HDC hdc = GetDC(nullptr);
  HBITMAP hBitmap =
      CreateDIBSection(hdc, &bmi, DIB_RGB_COLORS, &bits, nullptr, 0);
  ReleaseDC(nullptr, hdc);

  if (!hBitmap || !bits) {
    return nullptr;
  }

  // Copy pixels from scaled image
  UINT stride = targetWidth * 4;
  UINT bufferSize = stride * targetHeight;
  hr = scaler->CopyPixels(nullptr, stride, bufferSize,
                          static_cast<BYTE *>(bits));

  if (FAILED(hr)) {
    DeleteObject(hBitmap);
    return nullptr;
  }

  return hBitmap;
}

void TrayManagerPlugin::ClearMenuBitmaps() {
  for (HBITMAP bmp : menu_bitmaps_) {
    if (bmp)
      DeleteObject(bmp);
  }
  menu_bitmaps_.clear();
}

} // namespace tray_manager

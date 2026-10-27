#include "trusttunnel_deeplink.h"

#include "trusttunnel_deeplink_ffi.h"

namespace vpn_plugin {

bool DecodeTrustTunnelDeepLink(const std::string& uri, std::string* configuration,
                               std::string* error_message) {
  if (configuration == nullptr) {
    if (error_message != nullptr) {
      *error_message = "configuration output is null";
    }
    return false;
  }

  DeepLinkError* error = nullptr;
  char* decoded = trusttunnel_deeplink_decode(uri.c_str(), &error);
  if (decoded == nullptr) {
    if (error_message != nullptr) {
      const char* message = error != nullptr ? trusttunnel_deeplink_error_message(error)
                                             : nullptr;
      *error_message = message != nullptr ? message : "failed to decode deep link";
    }
    trusttunnel_deeplink_error_free(error);
    return false;
  }

  *configuration = decoded;
  trusttunnel_deeplink_string_free(decoded);
  return true;
}

bool EncodeTrustTunnelDeepLink(const std::string& endpoint_toml, std::string* uri,
                               std::string* error_message) {
  if (uri == nullptr) {
    if (error_message != nullptr) {
      *error_message = "uri output is null";
    }
    return false;
  }

  DeepLinkError* error = nullptr;
  char* encoded = trusttunnel_deeplink_encode(endpoint_toml.c_str(), &error);
  if (encoded == nullptr) {
    if (error_message != nullptr) {
      const char* message = error != nullptr ? trusttunnel_deeplink_error_message(error)
                                             : nullptr;
      *error_message = message != nullptr ? message : "failed to encode deep link";
    }
    trusttunnel_deeplink_error_free(error);
    return false;
  }

  *uri = encoded;
  trusttunnel_deeplink_string_free(encoded);
  return true;
}

}  // namespace vpn_plugin

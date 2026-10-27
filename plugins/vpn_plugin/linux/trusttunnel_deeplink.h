#ifndef VPN_PLUGIN_LINUX_TRUSTTUNNEL_DEEPLINK_H_
#define VPN_PLUGIN_LINUX_TRUSTTUNNEL_DEEPLINK_H_

#include <string>

namespace vpn_plugin {

// Decodes a TrustTunnel `tt://?...` deep link into the `[endpoint]` TOML/INI
// document consumed by the Dart ConfigurationDecoder.
//
// `uri` must be the complete deep link (including the `tt://` scheme), as
// delivered by the Dart IDeepLink API. On success returns true and fills
// `configuration`; on failure returns false and fills `error_message`.
bool DecodeTrustTunnelDeepLink(const std::string& uri, std::string* configuration,
                               std::string* error_message);

// Encodes an `[endpoint]` TOML section into a `tt://?...` deep-link URI.
//
// `endpoint_toml` must use the same layout that DecodeTrustTunnelDeepLink
// produces. On success returns true and fills `uri`; on failure returns false
// and fills `error_message`.
bool EncodeTrustTunnelDeepLink(const std::string& endpoint_toml, std::string* uri,
                               std::string* error_message);

}  // namespace vpn_plugin

#endif  // VPN_PLUGIN_LINUX_TRUSTTUNNEL_DEEPLINK_H_

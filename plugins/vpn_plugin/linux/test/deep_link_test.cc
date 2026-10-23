#include "trusttunnel_deeplink.h"

#include <gtest/gtest.h>

#include <string>

namespace {

// Generated with the Rust trusttunnel_deeplink encoder from:
// [endpoint]
// hostname = "vpn.example.com"
// addresses = ["1.2.3.4:443", "[2001:db8::1]:443"]
// has_ipv6 = true
// username = "user"
// password = "pa:ss"
// client_random = "aabbccdd"
// skip_verification = false
// upstream_protocol = "http2"
// anti_dpi = true
// custom_sni = "sni.example.com"
// dns_upstreams = ["tls://dns.example.com"]
// name = "Test Server"
constexpr const char kValidDeepLink[] =
    "tt://?AAECAQ92cG4uZXhhbXBsZS5jb20FBHVzZXIGBXBhOnNzAgsxLjIuMy40OjQ0MwIRWzIwMDE6ZGI4"
    "OjoxXTo0NDMLCGFhYmJjY2RkAw9zbmkuZXhhbXBsZS5jb20KAQEMC1Rlc3QgU2VydmVyDRYVdGxzOi8v"
    "ZG5zLmV4YW1wbGUuY29t";

TEST(TrustTunnelDeepLinkTest, DecodesEndpointConfiguration) {
  std::string configuration;
  std::string error;
  ASSERT_TRUE(vpn_plugin::DecodeTrustTunnelDeepLink(kValidDeepLink, &configuration, &error))
      << error;

  EXPECT_NE(configuration.find("hostname = \"vpn.example.com\""), std::string::npos);
  EXPECT_NE(configuration.find("upstream_protocol = \"http2\""), std::string::npos);
  EXPECT_NE(configuration.find("anti_dpi = true"), std::string::npos);
  EXPECT_NE(configuration.find("name = \"Test Server\""), std::string::npos);
}

TEST(TrustTunnelDeepLinkTest, RejectsMalformedUri) {
  std::string configuration;
  std::string error;
  EXPECT_FALSE(vpn_plugin::DecodeTrustTunnelDeepLink("not-a-deep-link", &configuration, &error));
  EXPECT_FALSE(error.empty());
}

}  // namespace

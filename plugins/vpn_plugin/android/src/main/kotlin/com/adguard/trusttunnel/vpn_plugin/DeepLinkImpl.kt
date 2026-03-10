package com.adguard.trusttunnel.vpn_plugin

import com.adguard.trusttunnel.DeepLink

class DeepLinkImpl : IDeepLink {
    override fun decode(uri: String): String {
        return DeepLink.decode(uri)
    }
}

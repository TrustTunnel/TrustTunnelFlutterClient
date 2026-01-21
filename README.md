<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://cdn.adguardcdn.com/website/github.com/TrustTunnel/logo_dark.svg" width="300px" alt="TrustTunnel" />
    <img src="https://cdn.adguardcdn.com/website/github.com/TrustTunnel/logo_light.svg" width="300px" alt="TrustTunnel" />
  </picture>
</p>

# <p align="center">TrustTunnel Flutter Client</p>


<p align="center">
  <a href="https://github.com/TrustTunnel/TrustTunnel">TrustTunnel Server</a>
  · <a href="https://github.com/TrustTunnel/TrustTunnelClient">Console client</a>
  · <a href="https://agrd.io/ios_trusttunnel">App Store</a>
  · <a href="https://agrd.io/android_trusttunnel">Play Store</a>
</p>

**TrustTunnel Flutter Client** is a mobile VPN client for **Android and iOS**, built with Flutter.
It provides a clean and focused graphical interface for connecting to **self-hosted TrustTunnel VPN servers**.

The application acts as a thin, user-facing layer on top of the TrustTunnel VPN stack. It does not attempt to hide the underlying architecture or networking model. Instead, it exposes core concepts — servers, endpoints, credentials, and transport protocols — in a clear and predictable form suitable for both beginners and experienced users.

Whether you are setting up your first self-hosted VPN or operating your own infrastructure, the Flutter client helps you connect, observe, and manage VPN traffic with confidence.

### Why TrustTunnel Flutter Client

- **Cross-platform by design**
  Built with Flutter, the client provides a consistent experience on Android and iOS while integrating directly with system VPN APIs on each platform.

- **Clean separation of concerns**
  VPN functionality lives in a dedicated Flutter plugin with native bindings, while the application focuses on user experience and configuration. This architecture keeps the codebase understandable and easy to maintain.

- **Self-hosted by default**
  No bundled servers, no shared exit nodes, and no third-party VPN providers. You connect only to servers you install and operate yourself.

- **Transparent and controllable**
  The client exposes key concepts such as endpoints, credentials, protocols, and routing behavior instead of hiding them behind abstractions, giving you full visibility into how your VPN works.

## Table of Contents
- [TrustTunnel Flutter Client](#trusttunnel-flutter-client)
    - [Why TrustTunnel Flutter Client](#why-trusttunnel-flutter-client)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Building](#building)
      - [1. Clone repository](#1-clone-repository)
      - [2. Use make to initialize project](#2-use-make-to-initialize-project)
      - [3. Configure GitHub Packages access](#3-configure-github-packages-access)
      - [4. Android: configure signing](#4-android-configure-signing)
      - [5. iOS: install pods and configure signing](#5-ios-install-pods-and-configure-signing)
      - [6. Build or run the application](#6-build-or-run-the-application)
  - [Usage](#usage)
    - [Quick Start](#quick-start)
    - [Server Configuration](#server-configuration)
    - [Routing Profiles](#routing-profiles)
    - [Excluded Routes](#excluded-routes)
    - [Query Logs](#query-logs)
  - [How TrustTunnel Works](#how-trusttunnel-works)
    - [Flutter App and VPN Plugin](#flutter-app-and-vpn-plugin)
    - [Running \& Development](#running--development)
  - [License](#license)

## Getting Started
### Prerequisites

Before working with the application, ensure that your environment is ready:

- **Flutter SDK 3.38.3 or newer**
- Android and/or iOS development tooling configured on your system
- Basic build utilities, including `make`

Flutter installation instructions are available in the official documentation:
https://docs.flutter.dev/get-started

### Building

To build and run the application follow this steps:

#### 1. Clone repository
```shell
git clone https://github.com/TrustTunnel/TrustTunnelFlutterClient.git
cd TrustTunnelFlutterClient
```

#### 2. Use make to initialize project
```shell
make init
```

#### 3. Configure GitHub Packages access

Project depends on artifacts published in GitHub Packages.
To download them, you must provide a **personal access token** via environment variables used by Maven.

**Create a personal access token**

Create a token here:
https://github.com/settings/tokens

Required permissions:
- `read:packages`
- `public_repo`

**Export token to environment**
```shell
export GPR_KEY=<your_personal_access_token>
```

As an alternative to exporting the variable in your shell, you can pass the token inline when running Flutter:

```shell
GPR_KEY=<your_personal_access_token> flutter run
```

Without this variable, builds will fail when resolving GitHub Packages dependencies.

---

#### 4. Android: configure signing

If you are building Android application, make sure that signing config is provided.

Run the following command once:
```shell
make aux-setup-android-signing
```

During keystore generation, `keytool` will interactively ask for certificate details.
You may set any values.

---

#### 5. iOS: install pods and configure signing

If you are building iOS application, make sure that pods are installed:
```shell
cd ios
pod install --repo-update
```

Also make sure that project uses correct signing configuration.

Configure signing in Xcode:
- Open the workspace: `ios/Runner.xcworkspace`
- Select the **Runner** target
- Open **Signing & Capabilities**
- Select your Apple Developer Team
- Enable **Automatically manage signing** (recommended)

Alternatively, disable automatic signing and select the required certificate and provisioning profile manually.

---

#### 6. Build or run the application

After initialization, the application can be built or launched using standard Flutter tooling:
```shell
flutter build
```

or:
```shell
flutter run
```

> [!NOTE]
> TrustTunnel Flutter Client requires a TrustTunnel VPN server.
> Before using the app, install and configure a TrustTunnel server by following the
> <a href="https://github.com/TrustTunnel/TrustTunnel?tab=readme-ov-file#endpoint-setup">server setup instructions</a>.

## Usage

### Quick Start

To use the VPN, connect the app to your TrustTunnel server.

Export a <a href="https://github.com/TrustTunnel/TrustTunnel?tab=readme-ov-file#export-client-configuration">client configuration</a> from the server and use it to establish a secure connection.
The configuration contains all required connection parameters and will be used in the next step:
```shell
# This file was automatically generated by endpoint and could be used in vpn client.

# Endpoint host name, used for TLS session establishment
hostname = "your.host.name"

# Endpoint addresses.
addresses = ["your.address"]

# Whether IPv6 traffic can be routed through the endpoint
has_ipv6 = true

# Username for authorization
username = "username"

# Password for authorization
password = "password"

# Skip the endpoint certificate verification?
# That is, any certificate is accepted with this one set to true.
skip_verification = false

# Endpoint certificate in PEM format.
# If not specified, the endpoint certificate is verified using the system storage.
certificate = """certificate"""

# Protocol to be used to communicate with the endpoint [http2, http3]
upstream_protocol = "protocol"

# Fallback protocol to be used in case the main one fails [<none>, http2, http3]
upstream_fallback_protocol = ""

# Is anti-DPI measures should be enabled
anti_dpi = false
```

> [!WARNING]
> TrustTunnel Flutter Client **doesn't support** self-signed certificates **yet**.
> If you want to use the TrustTunnel Flutter Client, you should have a valid
> certificate issued by a publicly trusted Certificate Authority (CA) associated
> with a registered domain for the IP address of the endpoint. Otherwise,
> the TrustTunnel Flutter Client will be unable to connect to the endpoint.

### Server Configuration
After generating the configuration on the server, open the **TrustTunnel Flutter Client** and navigate to the **Servers** section. From there, open the **Add Server / Edit Server** screen.

The configuration file includes many parameters, but only a subset is required by the mobile app. These values should be entered manually into the UI.

You will need to provide:

- A server name, used only as a display label inside the app
- The server IP address and port, taken from the `addresses` field
- The server hostname, taken from the `hostname` field
- Authentication credentials (`username` and `password`)
- Any valid DNS addresses
- The transport protocol, taken from `upstream_protocol`

Protocol mapping in the app is straightforward:
- `http2` corresponds to HTTP/2
- `http3` corresponds to QUIC

Once all fields are filled in, save the server. It will appear in the server list and be ready for connection.

### Routing Profiles
Routing Profiles define **how network traffic is classified and routed** when a VPN connection is active.

A routing profile is a named set of routing rules combined with a routing mode. Profiles are evaluated on the client side before traffic is forwarded, making routing behavior transparent and predictable.

By default, the application includes a single routing profile. You can create additional profiles to represent different usage scenarios, such as work-related traffic, personal browsing, or custom split-tunneling setups.

Each routing profile operates in one of two modes:

- **VPN mode** — traffic matching the rules is routed through the VPN tunnel.
- **Bypass mode** — traffic matching the rules bypasses the VPN tunnel.

The selected mode defines how the rules are interpreted. In VPN mode, rules act as an allow list for tunneling. In Bypass mode, rules act as an exclusion list.

Routing rules describe traffic destinations and each rule is evaluated independently and applied in a straightforward manner.

After saving a routing profile, **make sure it is assigned to the desired server** in the server settings screen.

This approach allows the same server to be reused with different routing behaviors while keeping server configuration and routing logic clearly separated.



### Excluded Routes
Excluded Routes provide a **low-level routing override** that applies independently of routing profiles.
This section is intended for explicitly excluding entire network ranges from being routed through the VPN tunnel.

These routes are evaluated at the networking layer and take precedence over higher-level routing rules.
Typical use cases include excluding local networks, private subnets, or system-reserved address ranges that must never be routed through a tunnel.

The input format is intentionally minimal and strict. Only CIDR ranges are supported.
Each range must be entered on its own line to keep the configuration readable and easy to audit.


### Query Logs
Query Logs provide **real-time visibility into VPN activity** directly from the client application.
This section presents a dynamically updating list of events produced by the VPN engine while the connection is active.

Each log entry represents a single networking decision made by the VPN stack.
The log captures what happened to a connection, which transport protocol was used, where the traffic originated, and where it was routed.

## How TrustTunnel Works
TrustTunnel follows a strict and explicit **client–server VPN architecture**, with a clear separation of responsibilities between components.

The **TrustTunnel server** runs on infrastructure fully controlled by the user. It is responsible for terminating encrypted connections, authenticating clients, and applying transport- and routing-level decisions. All security- and policy-related logic lives on the server side and is configured independently of the mobile application.

The **TrustTunnel Flutter Client** runs on a mobile device and acts purely as a client. Its responsibility is to establish a secure tunnel to the server, integrate with the operating system VPN APIs, and provide a graphical interface for managing the connection and observing its behavior.

### Flutter App and VPN Plugin
The project is intentionally split into **two independent layers**.

The **Flutter application** is responsible for user experience and business logic. It handles UI, navigation, server management, configuration input, routing profile selection, and the overall connection lifecycle. This layer focuses on making VPN usage understandable and manageable for the user.

The **VPN plugin**, located in `plugins/vpn_plugin`, is fully dedicated to VPN functionality. It communicates with native platform implementations through Pigeon-generated APIs and integrates directly with Android and iOS VPN frameworks. The plugin is completely decoupled from the GUI layer and does not depend on any application-specific logic.

Because of this separation, the VPN plugin can be reused in other Flutter applications without modification. The GUI application is just one possible consumer of the plugin.

This architecture keeps responsibilities well-defined, simplifies maintenance, and allows independent evolution of UI and networking layers.

### Running & Development

The application supports development and testing on Android and iOS platforms.

However, **VPN functionality must be tested on physical devices**.
Emulators and simulators do not fully replicate system VPN behavior and may introduce false positives or platform-specific issues.

For reliable results and correct VPN lifecycle handling, always validate functionality on real hardware.
Connection state changes and errors displayed in the UI directly reflect real network and system conditions.

## License
Apache 2.0


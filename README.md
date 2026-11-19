&nbsp;

<p align="center">
  <a href="https://cdn.adguardcdn.com/website/github.com/TrustTunnel/logo_light.svg#gh-light-mode-only">
    <img src="https://cdn.adguardcdn.com/website/github.com/TrustTunnel/logo_light.svg#gh-light-mode-only" width="300" alt="TrustTunnel" />
  </a>
  <a href="https://cdn.adguardcdn.com/website/github.com/TrustTunnel/logo_dark.svg#gh-dark-mode-only">
    <img src="https://cdn.adguardcdn.com/website/github.com/TrustTunnel/logo_dark.svg#gh-dark-mode-only" width="300" alt="TrustTunnel" />
  </a>
</p>

# <p align="center">TrustTunnel Flutter Client</p>


<p align="center">
  <b>Download:</b>
  <a href="https://agrd.io/android_trusttunnel">Android</a>
  · <a href="https://agrd.io/ios_trusttunnel">iOS</a>
  · <a href="https://agrd.io/macos_trusttunnel">macOS</a>
  · <a href="https://agrd.io/trusttunnel_windows">Windows</a>
  <br>
  <sub>
    <a href="https://github.com/TrustTunnel/TrustTunnel">TrustTunnel Server</a>
    · <a href="https://github.com/TrustTunnel/TrustTunnelClient">TrustTunnel CLI Client</a>
  </sub>
</p>

&nbsp;

**TrustTunnel Flutter Client** is a VPN client for Android, iOS, macOS, and Windows, built with Flutter.
It provides a clean and focused graphical interface for connecting to **self-hosted TrustTunnel VPN servers**.

The application acts as a thin, user-facing layer on top of the TrustTunnel VPN stack. It does not attempt to hide the underlying architecture or networking model. Instead, it exposes core concepts — servers, endpoints, credentials, and transport protocols — in a clear and predictable form suitable for both beginners and experienced users.

Whether you are setting up your first self-hosted VPN or operating your own infrastructure, the Flutter client helps you connect, observe, and manage VPN traffic with confidence.

### Why TrustTunnel Flutter Client

- **Cross-platform by design**
  Built with Flutter, the client provides a consistent experience on Android, iOS, macOS, and Windows while integrating directly with platform-specific networking APIs on each platform.

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
  - [Quick Start](#quick-start)
  - [Features](#features)
    - [Routing Profiles](#routing-profiles)
    - [Excluded Routes](#excluded-routes)
    - [Connection Log](#connection-log)
  - [How TrustTunnel Works](#how-trusttunnel-works)
    - [Flutter App and VPN Plugin](#flutter-app-and-vpn-plugin)
    - [Running \& Development](#running--development)
  - [Building from Source](#building-from-source)
    - [Prerequisites](#prerequisites)
    - [Building](#building)
      - [1. Clone repository](#1-clone-repository)
      - [2. Use make to initialize project](#2-use-make-to-initialize-project)
      - [3. Configure GitHub Packages access](#3-configure-github-packages-access)
      - [4. Android: configure signing](#4-android-configure-signing)
      - [5. iOS: install pods and configure signing](#5-ios-install-pods-and-configure-signing)
      - [6. macOS: install pods and configure signing](#6-macos-install-pods-and-configure-signing)
      - [7. Windows: configure the build environment](#7-windows-configure-the-build-environment)
      - [8. Build or run the application](#8-build-or-run-the-application)
  - [License](#license)

## Quick Start

A TrustTunnel setup includes two components: a server and a client application.

1. **Set up a TrustTunnel server.** Install and configure it by following the
   [server setup instructions](https://github.com/TrustTunnel/TrustTunnel#endpoint-setup).
2. **Get a connection link from your server.** The server encodes everything the app needs to connect
   into a `tt://?…` link: the server address, your credentials, and the connection settings.
   See the [server documentation](https://github.com/TrustTunnel/TrustTunnel#export-client-configuration)
   for how to generate it.
3. **Install the client app.** Download a ready-made build for [Android](https://agrd.io/android_trusttunnel),
   [iOS](https://agrd.io/ios_trusttunnel), [macOS](https://agrd.io/macos_trusttunnel),
   or [Windows](https://agrd.io/trusttunnel_windows), or [build it from source](#building-from-source).
4. **Add the server to the app.** Paste the link at [trusttunnel.org/qr.html](https://trusttunnel.org/qr.html),
   then tap **Open in TrustTunnel App** or scan the QR code with your phone's camera.
   The link is processed locally in your browser, so it never leaves your device.
   TrustTunnel opens the **Add server** screen with all fields filled in — review them and tap **Save**.

> [!NOTE]
> Alternatively, you can add a server manually instead of using the `tt://` link: open **Servers**, tap **Add server**,
> and fill in the fields from the TOML configuration [exported from your server](https://github.com/TrustTunnel/TrustTunnel#toml-format-for-cli-client).

## Features

### Routing Profiles
A routing profile defines which traffic goes through the VPN tunnel and which goes directly.
Profiles are managed on the **Routing** tab and assigned to a server in the server settings.

Each profile has a routing mode — **VPN** or **Bypass** — and a list of exceptions that are routed the other way:

- In **VPN** mode, all traffic goes through the tunnel except destinations listed in the **Bypass** field.
- In **Bypass** mode, all traffic goes directly except destinations listed in the **VPN** field.

You can add domains of any level (subdomains are included automatically), IP addresses, IP addresses with a port,
and IP ranges with a mask — one per line.

### Excluded Routes
Excluded routes are network ranges that never go through the VPN tunnel, even if they match a rule in a routing profile.
They are configured in **Settings → General → Excluded routes**, one CIDR range per line.

By default, the list contains private and reserved ranges, such as `10.0.0.0/8` and `192.168.0.0/16`,
so local network devices stay reachable while the VPN is on.

### Connection Log
The connection log helps you see how the app routes your traffic and check that your routing settings work as expected.
It updates in real time and is available in **Settings → Connection log**.

Every record contains a timestamp, protocol (TCP or UDP), routing decision (tunnel, bypass, or reject),
source and destination addresses, plus the domain name when available.
Records are stored locally on your device, and the 500 most recent ones are kept.

## How TrustTunnel Works
TrustTunnel follows a strict and explicit **client–server VPN architecture**, with a clear separation of responsibilities between components.

The **TrustTunnel server** runs on infrastructure fully controlled by the user. It is responsible for terminating encrypted connections, authenticating clients, and applying transport- and routing-level decisions. All security- and policy-related logic lives on the server side and is configured independently of the client application.

The **TrustTunnel Flutter Client** runs on a user's device (mobile or desktop) and acts purely as a client. Its responsibility is to establish a secure tunnel to the server, integrate with the operating system VPN APIs, and provide a graphical interface for managing the connection and observing its behavior.

### Flutter App and VPN Plugin
The project is intentionally split into **two independent layers**.

The **Flutter application** is responsible for user experience and business logic. It handles UI, navigation, server management, configuration input, routing profile selection, and the overall connection lifecycle. This layer focuses on making VPN usage understandable and manageable for the user.

The **VPN plugin**, located in `plugins/vpn_plugin`, is fully dedicated to VPN functionality. It communicates with native platform implementations through Pigeon-generated APIs and integrates directly with the VPN and networking facilities of Android, iOS, macOS, and Windows. The plugin is completely decoupled from the GUI layer and does not depend on any application-specific logic.

Because of this separation, the VPN plugin can be reused in other Flutter applications without modification. The GUI application is just one possible consumer of the plugin.

This architecture keeps responsibilities well-defined, simplifies maintenance, and allows independent evolution of UI and networking layers.

### Running & Development

The application supports development and testing on Android, iOS, macOS, and Windows platforms.

However, **VPN functionality must be tested on physical devices**.
Emulators and simulators do not fully replicate system VPN behavior and may introduce false positives or platform-specific issues.

For reliable results and correct VPN lifecycle handling, always validate functionality on real hardware.
Connection state changes and errors displayed in the UI directly reflect real network and system conditions.

## Building from Source
### Prerequisites

Before working with the application, ensure that your environment is ready:

- **Flutter SDK 3.47.8 or newer**
- Android, iOS, macOS, and/or Windows development tooling configured on your system
- Basic build utilities, including `make`

Flutter installation instructions are available in the official documentation:
https://docs.flutter.dev/get-started

### Building

To build and run the application, follow these steps:

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


#### 6. macOS: install pods and configure signing

If you are building macOS application, make sure that pods are installed:
```shell
cd macos
pod install --repo-update
```

Also make sure that project uses correct signing configuration.

Configure signing in Xcode:

Open the workspace: macos/Runner.xcworkspace
Select the Runner target
Open Signing & Capabilities
Select your Apple Developer Team
Enable Automatically manage signing (recommended)

---

#### 7. Windows: configure the build environment

If you are building Windows application, make sure that Flutter's Windows desktop prerequisites are installed, including Visual Studio with the **Desktop development with C++** workload.

No signing configuration is required for local builds.

Debug builds install the TrustTunnel VPN service on demand, so Windows will prompt for administrator privileges the first time a VPN connection is started.

To build the installer, install [Inno Setup](https://jrsoftware.org/isinfo.php) 6.6 or newer and run:
```shell
make create-windows-installer
```

The installer is created at `build/windows/installer/TrustTunnelSetup.exe`.
It supports x64 Windows 10 (22H2 or newer) and ARM64 Windows 11 devices.

---

#### 8. Build or run the application

After initialization, the application can be built or launched using standard Flutter tooling:
```shell
flutter build
```

or:
```shell
flutter run
```

## License
Apache 2.0

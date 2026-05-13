# KeyringAccess & SecretService

![Swift](https://img.shields.io/badge/swift-F54A2A?style=for-the-badge&logo=swift&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

[Documentation KeyringAccess](https://amethystsoft.github.io/KeyringAccess/keyring/documentation/keyringaccess/)
[Documentation SecretService](https://amethystsoft.github.io/KeyringAccess/secret/documentation/secretservice/)

> Use KeyringAccess for a simplified API. Use SecretService if you need low-level DBus communication or custom collection handling.

SecretService is a zero-system-dependency, full-swift implementation of the freedesktop secret service dbus spec.
KeyringAccess provides a convenient high level API for linux desktop apps.

## `KeyringAccess`

A pure Swift library to store secrets securely on Linux with 0 system development dependencies.

## Overview

`KeyringAccess` provides a native Swift implementation of the Freedesktop Secret Service API. It eliminates the need for system development headers like libsecret-1-dev by communicating directly via DBus.

It offers a resilient storage approach: if no default keyring is found, the library automatically resolves this by promoting existing collections or creating a new one, ensuring a seamless experience for both CLI and Desktop applications.

## Features
- **Zero System Dependencies**: No need to install C-libraries or headers on your build or target machine.
- **Interactive Authentication**: Automatically handles system prompt redirects if the keyring is locked.
- **Modern Swift**: Fully supports `async/await` for all operations.
- **Secure**: Uses the system's native secret storage (like GNOME Keyring or KWallet).
- **Subscript and get/set Support**: Use subscripts or methods, depending on what fits your use case better.

## Collection Management

`KeyringAccess` is designed to be "plug-and-play." You don't need to worry about whether a user has a specific keyring collection pre-configured:

- **Automatic Discovery**: It automatically targets the `default` collection.
- **Intelligent Fallback**: If no `default` alias exists, the library looks for an existing `login` collection and promotes it to `default`.
- **Zero-Config**: If no suitable collection is found, it will automatically create a new one to ensure your secrets can be stored immediately.

## Installation
```swift
dependencies: [
    .package(url: "https://github.com/amethystsoft/KeyringAccess.git", from: "1.0.0")
]
```

## Usage
```swift
import KeyringAccess

// Set your app identifier globally before first use.
Keyring.appIdentifier.withLock { identifier in
    identifier = "com.example.YourApp"
}

// Create a new Keyring for a server or service.
// Adding a label is optional, but recommended, so its visible in the system manager.
let keyring = Keyring(server: "https://api.yourapp.com/")
.label("YourApp API key")

// Store via subscript
keyring["user"] = "mytoken123"

// Store via setter (also available asynchronously)
keyring.set("mytoken123", for: "user")

// Updates are upserts.
keyring["user"] = "newtoken123"

// Read secret via subscript (also available asynchronously)
let secretViaSubscript = keyring["user"]

// Read secret via getter (also available asynchronously)
let secretViaGetter = keyring.get(for: "user")

// Get attributes via subscript (also available asynchronously)
if let attributesViaSubscript = keyring[attributes: "user"] {
    print("Label: \(attributesViaSubscript.label)")
    print("Created at: \(attributesViaSubscript.created)")
    print("Modified at: \(attributesViaSubscript.modified)")
}

// Get attributes via getter (also available asynchronously)
if let attributesViaGetter = keyring.getAttributes("user") {
    print("Label: \(attributesViaGetter.label)")
    print("Created at: \(attributesViaGetter.created)")
    print("Modified at: \(attributesViaGetter.modified)")
}

// Delete by setting to nil via subscript.
keyring["user"] = nil

// Delete by setting to nil via setter (also available asynchronously)
keyring.set(nil, for: "user")

// For batch operations to avoid repeated diffie hellmann exchange
try await Keyring.runBatched { service in
    // Do operations, using service
    let keyring = Keyring(server: "https://api.yourapp.com/")
    
    try await keyring.set("newToken", for: "user", service: service)
    // ...
}
```

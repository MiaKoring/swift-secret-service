# ``KeyringAccess``

A pure Swift library to store secrets securely on Linux with 0 system development dependencies.

## Overview

``KeyringAccess`` provides a native Swift implementation of the Freedesktop Secret Service API. It eliminates the need for system development headers like libsecret-1-dev by communicating directly via DBus.

It offers a resilient storage approach: if no default keyring is found, the library automatically resolves this by promoting existing collections or creating a new one, ensuring a seamless experience for both CLI and Desktop applications.

## Features
- **Zero System Dependencies**: No need to install C-libraries or headers on your build or target machine.
- **Interactive Authentication**: Automatically handles system prompt redirects if the keyring is locked.
- **Modern Swift**: Fully supports `async/await` for all operations.
- **Secure**: Uses the system's native secret storage (like GNOME Keyring or KWallet).
- **Subscript and get/set Support**: Use subscripts or methods, depending on what fits your usecase better.

## Collection Management

`KeyringAccess` is designed to be "plug-and-play." You don't need to worry about whether a user has a specific keyring collection pre-configured:

- **Automatic Discovery**: It automatically targets the `default` collection.
- **Intelligent Fallback**: If no `default` alias exists, the library looks for an existing `login` collection and promotes it to `default`.
- **Zero-Config**: If no suitable collection is found, it will automatically create a new one to ensure your secrets can be stored immediately.

## Topics
- ``Keyring``

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EMDK (Enterprise Mobility Developer Kit) port to .NET MAUI — a reference implementation demonstrating Symbol/Zebra EMDK SDK integration with MAUI on Android, while maintaining cross-platform scaffolding for iOS, macOS, Windows, and Tizen.

## Build Commands

```bash
# Solution is at the repo root; project is in emdkbindingMAUIapp/
dotnet build emdkbindingMAUIapp/emdkMAUIapp.csproj

# Platform-specific builds
dotnet build emdkbindingMAUIapp/emdkMAUIapp.csproj -f net6.0-android31.0
dotnet build emdkbindingMAUIapp/emdkMAUIapp.csproj -f net6.0-windows10.0.22621.0
dotnet build emdkbindingMAUIapp/emdkMAUIapp.csproj -f net6.0-ios
dotnet build emdkbindingMAUIapp/emdkMAUIapp.csproj -f net6.0-maccatalyst

# Run on Windows
dotnet build emdkbindingMAUIapp/emdkMAUIapp.csproj -f net6.0-windows10.0.22621.0 -t:Run
```

There are no tests in this project.

## Architecture

**Single-project MAUI app** targeting .NET 6.0 across five platforms. Platform-specific code lives under `emdkbindingMAUIapp/Platforms/{Android,iOS,MacCatalyst,Windows,Tizen}/`.

### Key files

- **`MauiProgram.cs`** — MAUI startup and font registration.
- **`App.xaml.cs`** — App lifecycle; sets `AppShell` as root.
- **`MainPage.xaml/.cs`** — Single UI page. Registers for `WeakReferenceMessenger` string messages and sends `"HI_ANDROID"` on button click.
- **`Platforms/Android/MainActivity.cs`** — The core of the app. Implements `EMDKManager.IEMDKListener` and `EMDKManager.IStatusListener`. Handles EMDK lifecycle (ProfileManager, VersionManager, NotificationManager), processes profiles asynchronously, queries Android system settings, and sends results back to MainPage via `WeakReferenceMessenger`.
- **`Platforms/Android/Assets/EMDKConfig.xml`** — EMDK profile XML (DisplayMgr settings).
- **`Platforms/Android/AndroidManifest.xml`** — Declares EMDK library dependency (`com.symbol.emdk`), EMDK permission, and targets API 33 / min API 29.

### Communication pattern

`MainPage` and `MainActivity` are decoupled via **CommunityToolkit.Mvvm's `WeakReferenceMessenger`** (string-typed messages). The UI sends a trigger message; Android-side EMDK results flow back as display strings.

## Key Dependencies

| Package | Version | Notes |
|---|---|---|
| CommunityToolkit.Mvvm | 8.0.0 | MVVM messaging (`WeakReferenceMessenger`) |
| Symbol.XamarinEMDK | 8.0.0.2 | Android-only; EMDK barcode/device management |

## Platform Notes

- **Android is the primary platform** — EMDK features only work on Zebra/Symbol Android devices. Other platform folders (iOS, macOS, Windows, Tizen) contain default MAUI scaffolding.
- The Android build requires the EMDK library on the target device (`com.symbol.emdk.emdkservice`).
- Root namespace is `emdkMAUIapp` (note: project folder is `emdkbindingMAUIapp`, which differs from the namespace).

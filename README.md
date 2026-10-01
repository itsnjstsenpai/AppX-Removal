# AppX-Removal

A small Windows app for finding and removing AppX packages from the account you are currently signed in to.

**Author:** ItsnJstSenpai

AppX-Removal is built with PowerShell and WPF. Its source is split into functions, UI startup code, and XAML, then combined into one runnable script.

> [!CAUTION]
> Removing an app can break Windows features or other apps that depend on it. Review every selected package before confirming. Back up important data and create a restore point before making system changes. AppX removal is not guaranteed to be reversible.

## Quick Start

### Requirements

- Windows with the AppX PowerShell cmdlets and WPF desktop runtime
- Windows PowerShell 5.1 or PowerShell 7 for Windows

### Build And Launch

Open PowerShell in the project folder and run:

```powershell
.\Compile.ps1
.\AppX-Removal.ps1
```

Run the app as the Windows account whose packages you want to manage. The list is loaded automatically when the window opens.

## Using The App

1. Search by app name, package ID, or publisher. Clear the search to see the full list again.
2. Check one or more rows. The selected count appears at the bottom of the window.
3. Choose **Remove selected** and review the confirmation prompt before approving removal.
4. Use **Refresh** or press `F5` to reload the current account's package list.

Use the GitHub button in the window to open the project repository.

## What It Can Remove

- The app works on packages installed for the current user only.
- Packages marked by Windows as frameworks or non-removable are excluded from the list and checked again before removal.
- It removes the installed package registration. It does not remove packages provisioned in a Windows image or prevent them from being installed for future users.
- Some listed packages may still be important to Windows or other apps. Windows can also reject a removal; the app reports the failure.
- The app does not back up packages, restore removed packages, or reinstall them.

## Logs And Privacy

The app writes progress and errors to the PowerShell console and to a timestamped log file:

```text
%LOCALAPPDATA%\AppX-Removal\logs\AppX-Removal_YYYY-MM-DD_HH-mm-ss.log
```

Logs can contain package names and error details. They stay in your local AppData folder; the app does not upload them. Review or redact a log before sharing it.

## For Developers

Edit the source files, then rebuild with `.\Compile.ps1` from the project folder. `AppX-Removal.ps1` is generated output; do not edit it directly.

Run the focused tests with Pester 5.8.0:

```powershell
Import-Module Pester -RequiredVersion 5.8.0 -Force
Invoke-Pester -Path .\pester\AppX-Removal.Tests.ps1 -Output Detailed
```

The tests use mock package data and do not remove apps from the machine. GitHub Actions also runs the tests and checks that the generated script and WPF interface load.

### Project Files

- `Compile.ps1` builds the single-file runnable script.
- `functions/` contains inventory, removal, and logging functions.
- `scripts/main.ps1` starts the WPF window and connects its controls to the package functions.
- `xaml/MainWindow.xaml` defines the window and table layout.
- `pester/AppX-Removal.Tests.ps1` tests filtering, removal safeguards, and logging.
- `.github/workflows/ci.yml` builds and tests the project on GitHub Actions.
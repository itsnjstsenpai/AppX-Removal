if (-not $IsWindows -and $PSVersionTable.PSEdition -eq "Core") {
    throw "AppX-Removal requires Windows and the WPF desktop runtime."
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

if (-not ('AppXRemovalDwmApi' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class AppXRemovalDwmApi {
    [DllImport("dwmapi.dll", PreserveSig = true)]
    public static extern int DwmSetWindowAttribute(IntPtr window, int attribute, ref int value, int size);
}
"@
}

[xml]$windowXml = $AppxRemovalXaml
$xmlReader = [System.Xml.XmlNodeReader]::new($windowXml)
$window = [Windows.Markup.XamlReader]::Load($xmlReader)
$xmlReader.Close()

$window.Add_SourceInitialized({
        $windowHandle = [System.Windows.Interop.WindowInteropHelper]::new($window).Handle
        $darkMode = 1
        $darkModeResult = [AppXRemovalDwmApi]::DwmSetWindowAttribute($windowHandle, 20, [ref]$darkMode, 4)
        if ($darkModeResult -ne 0) {
            [void][AppXRemovalDwmApi]::DwmSetWindowAttribute($windowHandle, 19, [ref]$darkMode, 4)
        }

        $captionColor = 0
        $captionTextColor = 0x00ECE9E9
        $captionBorderColor = 0x00363636
        [void][AppXRemovalDwmApi]::DwmSetWindowAttribute($windowHandle, 35, [ref]$captionColor, 4)
        [void][AppXRemovalDwmApi]::DwmSetWindowAttribute($windowHandle, 36, [ref]$captionTextColor, 4)
        [void][AppXRemovalDwmApi]::DwmSetWindowAttribute($windowHandle, 34, [ref]$captionBorderColor, 4)
    })

$script:appxWindow = $window
$script:appxGrid = $window.FindName("PackageGrid")
$script:appxSearch = $window.FindName("SearchBox")
$script:appxStatus = $window.FindName("StatusText")
$script:appxSelected = $window.FindName("SelectedText")
$script:appxInventoryCount = $window.FindName("InventoryCount")
$script:appxEmptyState = $window.FindName("EmptyStateText")
$script:appxRefresh = $window.FindName("RefreshButton")
$script:appxGitHub = $window.FindName("GitHubButton")
$script:appxRemove = $window.FindName("RemoveButton")
$script:appxPackages = @()

function Update-AppxRemovalSelection {
    $selectedCount = @($script:appxPackages | Where-Object { $_.IsSelected }).Count
    $script:appxSelected.Text = "$selectedCount selected"
    $script:appxRemove.IsEnabled = $selectedCount -gt 0
}

function Update-AppxRemovalList {
    $query = $script:appxSearch.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($query)) {
        $visiblePackages = @($script:appxPackages)
    }
    else {
        $visiblePackages = @($script:appxPackages | Where-Object {
                $_.DisplayName -like "*$query*" -or
                $_.Name -like "*$query*" -or
                $_.Publisher -like "*$query*"
            })
    }
    $script:appxGrid.ItemsSource = $visiblePackages
    if ($visiblePackages.Count -eq 0) {
        if ($script:appxPackages.Count -eq 0) {
            $script:appxEmptyState.Text = "No removable packages found."
        }
        else {
            $script:appxEmptyState.Text = "No packages match your search."
        }
        $script:appxEmptyState.Visibility = [System.Windows.Visibility]::Visible
    }
    else {
        $script:appxEmptyState.Visibility = [System.Windows.Visibility]::Collapsed
    }
    Update-AppxRemovalSelection
}

function Update-AppxRemovalInventory {
    $script:appxRefresh.IsEnabled = $false
    $script:appxStatus.Text = "Scanning installed packages..."
    Write-AppxRemovalLog -Message "Scanning installed AppX packages for the current user."
    try {
        $script:appxPackages = @(Get-AppxRemovalPackage)
        Update-AppxRemovalList
        $script:appxStatus.Text = "Loaded $($script:appxPackages.Count) removable packages for the current user."
        $script:appxInventoryCount.Text = "$($script:appxPackages.Count) removable packages"
        Write-AppxRemovalLog -Message "Loaded $($script:appxPackages.Count) removable package(s)."
    }
    catch {
        $script:appxStatus.Text = "Package scan failed."
        $script:appxInventoryCount.Text = "Inventory unavailable"
        Write-AppxRemovalLog -Level "ERROR" -Message "Package scan failed: $($_.Exception.Message)"
        [void][System.Windows.MessageBox]::Show(
            $script:appxWindow,
            $_.Exception.Message,
            "AppX-Removal",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
    finally {
        $script:appxRefresh.IsEnabled = $true
    }
}

$script:appxSearch.Add_TextChanged({ Update-AppxRemovalList })
$script:appxRefresh.Add_Click({ Update-AppxRemovalInventory })
$script:appxGitHub.Add_Click({ Start-Process -FilePath "https://github.com/itsnjstsenpai/AppX-Removal" })
$checkboxChanged = [System.Windows.RoutedEventHandler] { Update-AppxRemovalSelection }
$script:appxGrid.AddHandler([System.Windows.Controls.Primitives.ToggleButton]::CheckedEvent, $checkboxChanged)
$script:appxGrid.AddHandler([System.Windows.Controls.Primitives.ToggleButton]::UncheckedEvent, $checkboxChanged)
$window.Add_KeyDown({
        if ($_.Key -eq [System.Windows.Input.Key]::F5) {
            Update-AppxRemovalInventory
            $_.Handled = $true
        }
    })
$script:appxRemove.Add_Click({
        $selectedPackages = @($script:appxPackages | Where-Object { $_.IsSelected })
        if ($selectedPackages.Count -eq 0) { return }

        $names = ($selectedPackages | ForEach-Object { $_.DisplayName }) -join "`n"
        $answer = [System.Windows.MessageBox]::Show(
            $script:appxWindow,
            "Remove these packages for the current user?`n`n$names`n`nSome apps may be required by Windows or other apps.",
            "Confirm package removal",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($answer -ne [System.Windows.MessageBoxResult]::Yes) {
            Write-AppxRemovalLog -Message "Removal cancelled by the user."
            return
        }

        $failures = [System.Collections.Generic.List[string]]::new()
        $removedCount = 0
        $script:appxRemove.IsEnabled = $false
        Write-AppxRemovalLog -Message "Starting removal for $($selectedPackages.Count) selected package(s)."
        foreach ($package in $selectedPackages) {
            $script:appxStatus.Text = "Removing $($package.DisplayName)..."
            Write-AppxRemovalLog -Message "Removing $($package.DisplayName) ($($package.PackageFullName))."
            try {
                Remove-AppxRemovalPackage -Package $package -Confirm:$false -ErrorAction Stop
                $removedCount++
                Write-AppxRemovalLog -Message "Removed $($package.DisplayName)."
            }
            catch {
                $failure = "$($package.DisplayName): $($_.Exception.Message)"
                $failures.Add($failure)
                Write-AppxRemovalLog -Level "ERROR" -Message $failure
            }
        }

        Update-AppxRemovalInventory
        if ($failures.Count -eq 0) {
            Write-AppxRemovalLog -Message "Removal complete. Removed $removedCount package(s)."
        }
        else {
            Write-AppxRemovalLog -Level "WARN" -Message "Removal finished with $removedCount removed and $($failures.Count) failed."
        }
        if ($failures.Count -gt 0) {
            [void][System.Windows.MessageBox]::Show(
                $script:appxWindow,
                ($failures -join "`n"),
                "Some packages could not be removed",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            )
        }
    })

Update-AppxRemovalInventory
[void]$window.ShowDialog()

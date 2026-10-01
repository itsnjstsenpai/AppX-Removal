BeforeAll {
    . (Join-Path $PSScriptRoot "..\functions\Get-AppxRemovalPackage.ps1")
    . (Join-Path $PSScriptRoot "..\functions\Remove-AppxRemovalPackage.ps1")
    . (Join-Path $PSScriptRoot "..\functions\Write-AppxRemovalLog.ps1")
}

Describe "Get-AppxRemovalPackage" {
    It "returns sorted removable packages and excludes protected packages" {
        Mock Get-AppxPackage {
            @(
                [pscustomobject]@{
                    DisplayName = "Zulu"
                    Name = "Example.Zulu"
                    PackageFullName = "Example.Zulu_1.0_x64__test"
                    Publisher = "CN=Example"
                    Version = "1.0"
                    IsFramework = $false
                    NonRemovable = $false
                }
                [pscustomobject]@{
                    DisplayName = ""
                    Name = "Example.Alpha"
                    PackageFullName = "Example.Alpha_1.0_x64__test"
                    Publisher = "CN=Example"
                    Version = "1.0"
                    IsFramework = $false
                    NonRemovable = $false
                }
                [pscustomobject]@{
                    DisplayName = "Framework Runtime"
                    Name = "Example.Framework"
                    PackageFullName = "Example.Framework_1.0_x64__test"
                    Publisher = "CN=Example"
                    Version = "1.0"
                    IsFramework = $true
                    NonRemovable = $false
                }
                [pscustomobject]@{
                    DisplayName = "Protected Component"
                    Name = "Example.Protected"
                    PackageFullName = "Example.Protected_1.0_x64__test"
                    Publisher = "CN=Example"
                    Version = "1.0"
                    IsFramework = $false
                    NonRemovable = $true
                }
            )
        }

        $packages = @(Get-AppxRemovalPackage)

        $packages.Count | Should -Be 2
        $packages[0].DisplayName | Should -Be "Example.Alpha"
        $packages[0].FrameworkStatus | Should -Be "No"
        $packages[0].IsSelected | Should -BeFalse
        $packages[1].DisplayName | Should -Be "Zulu"
        $packages[1].FrameworkStatus | Should -Be "No"
        Should -Invoke Get-AppxPackage -Times 1 -Exactly
    }
}

Describe "Write-AppxRemovalLog" {
    It "writes a timestamped AppX entry to the session log" {
        Mock Write-Host { }
        $script:AppxRemovalLogPath = Join-Path $TestDrive "AppX-Removal.log"

        Write-AppxRemovalLog -Level "WARN" -Message "Test package warning."

        $entry = Get-Content -LiteralPath $script:AppxRemovalLogPath -Raw
        $entry | Should -Match '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\] \[WARN\] \[AppX\] Test package warning\.'
        Should -Invoke Write-Host -Times 1 -Exactly
    }
}

Describe "Remove-AppxRemovalPackage" {
    It "removes an eligible package by its exact full name" {
        Mock Remove-AppxPackage { }
        $package = [pscustomobject]@{
            DisplayName = "Example App"
            Name = "Example.App"
            PackageFullName = "Example.App_1.0_x64__test"
            IsFramework = $false
            NonRemovable = $false
        }

        Remove-AppxRemovalPackage -Package $package -Confirm:$false

        Should -Invoke Remove-AppxPackage -Times 1 -Exactly -ParameterFilter {
            $Package -eq "Example.App_1.0_x64__test"
        }
    }

    It "refuses framework packages" {
        Mock Remove-AppxPackage { }
        $package = [pscustomobject]@{
            DisplayName = "Example Framework"
            Name = "Example.Framework"
            PackageFullName = "Example.Framework_1.0_x64__test"
            IsFramework = $true
            NonRemovable = $false
        }

        { Remove-AppxRemovalPackage -Package $package -Confirm:$false } | Should -Throw "Refusing to remove protected package*"
        Should -Invoke Remove-AppxPackage -Times 0 -Exactly
    }
}

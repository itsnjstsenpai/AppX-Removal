function Get-AppxRemovalPackage {
    [CmdletBinding()]
    param()

    Get-AppxPackage -ErrorAction Stop |
    Where-Object { -not $_.IsFramework -and -not $_.NonRemovable } |
    Sort-Object -Property DisplayName, Name |
    Select-Object @{
        Name       = "DisplayName"
        Expression = { if ($_.DisplayName) { $_.DisplayName } else { $_.Name } }
    }, Name, PackageFullName, Publisher, Version, IsFramework, NonRemovable, @{
        Name       = "FrameworkStatus"
        Expression = { if ($_.IsFramework) { "Yes" } else { "No" } }
    }, @{
        Name       = "IsSelected"
        Expression = { $false }
    }
}

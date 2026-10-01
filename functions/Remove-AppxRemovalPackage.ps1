function Remove-AppxRemovalPackage {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$Package
    )

    process {
        foreach ($app in $Package) {
            if ($app.IsFramework -or $app.NonRemovable) {
                throw "Refusing to remove protected package '$($app.DisplayName)' ($($app.Name))."
            }

            if ($PSCmdlet.ShouldProcess($app.PackageFullName, "Remove for current user")) {
                Remove-AppxPackage -Package $app.PackageFullName -ErrorAction Stop
            }
        }
    }
}

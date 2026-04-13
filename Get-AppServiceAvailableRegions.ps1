param(
    # App Service quota SKU to check. Examples: S1, P1v3, B1, F1, D1
    [string]$Sku = "S1",

    # Quota API version (the one you tested successfully)
    [string]$ApiVersion = "2025-09-01",

    # Show regions even when limit == 0
    [switch]$ShowZeroLimit,

    # Only show regions where usage is known and remaining capacity exists (Used < Limit)
    [switch]$OnlyAvailable
)

$ErrorActionPreference = "Stop"

# Ensure az is available
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) not found. Install Azure CLI or run in Azure Cloud Shell."
}

# Subscription id
$subId = az account show --query id -o tsv
if (-not $subId) { throw "No subscription found. Run: az login" }

# Regions list
$regions = az account list-locations --query "[].name" -o tsv | Sort-Object
if (-not $regions) { throw "No regions returned. Check subscription access." }

Write-Host "Subscription: $subId"
Write-Host "Checking App Service quota via Microsoft.Quota for SKU: $Sku"
Write-Host ""

$results = foreach ($r in $regions) {
    $url = "https://management.azure.com/subscriptions/$subId/providers/Microsoft.Web/locations/$r/providers/Microsoft.Quota/quotas?api-version=$ApiVersion"

    # Call Quota API (suppress noisy errors for regions where this scope isn't supported)
    $jsonText = az rest --method get --url $url -o json 2>$null
    if (-not $jsonText) { continue }

    $data = $jsonText | ConvertFrom-Json
    if (-not $data.value) { continue }

    # Find the record for this SKU:
    # - Either .name == SKU (e.g. "S1")
    # - Or localizedValue contains "S1 VMs"
    $match = $data.value | Where-Object {
        $_.name -eq $Sku -or ($_.properties.name.localizedValue -like "*$Sku VMs*")
    } | Select-Object -First 1

    if (-not $match) { continue }

    # Limit is typically at properties.limit.value
    $limit = $match.properties.limit.value

    # Usage isn't always returned; some tenants only show limit.
    # We'll try a few likely places and fallback to $null.
    $used = $null
    if ($match.properties.PSObject.Properties.Name -contains "currentValue") {
        $used = $match.properties.currentValue
    } elseif ($match.properties.PSObject.Properties.Name -contains "usages" -and $match.properties.usages) {
        # sometimes: properties.usages.value
        if ($match.properties.usages.PSObject.Properties.Name -contains "value") {
            $used = $match.properties.usages.value
        }
    }

    # Filter logic
    if (-not $ShowZeroLimit -and ($limit -is [int] -or $limit -is [long]) -and $limit -le 0) { continue }
    if ($OnlyAvailable) {
        if ($used -eq $null) { continue }  # can't prove availability
        if ($used -ge $limit) { continue }
    }

    [pscustomobject]@{
        Region    = $r
        Used      = $(if ($used -eq $null) { "?" } else { $used })
        Limit     = $limit
        QuotaName = $match.properties.name.localizedValue
        Sku       = $match.name
        Unit      = $match.properties.unit
    }
}

# Output (sorted by highest limit first)
$results |
    Sort-Object -Property @{Expression="Limit"; Descending=$true}, Region |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Examples:"
Write-Host "  .\Get-AppServiceAvailableRegions.ps1 -Sku S1"
Write-Host "  .\Get-AppServiceAvailableRegions.ps1 -Sku P1v3"
Write-Host "  .\Get-AppServiceAvailableRegions.ps1 -Sku S1 -OnlyAvailable"
Write-Host "  .\Get-AppServiceAvailableRegions.ps1 -Sku S1 -ShowZeroLimit"

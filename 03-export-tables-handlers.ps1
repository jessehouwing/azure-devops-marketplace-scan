$cacheFile = "report.json"
$report = (Get-Content -raw -Path $cacheFile) | ConvertFrom-Json -AsHashtable

# Find all extensions that rely on deprecated task handlers only
$deprecatedHandlers = @("Node", "PowerShell", "Javascript") | %{ $_.ToLower() }
$count = 0
$Node = 0
$PowerShell = 0
$Javascript = 0
$executionHandlers = @()

foreach ($extension in $report.extensions)
{
    $deprecated = $false
    foreach ($task in $extension.tasks | ?{ -not $_.isDeprecated  })
    {
        foreach ($version in $task.versions){
            $handlers = ($version.executionHandlers + $version.preExecutionHandlers + $version.postExecutionHandlers) | %{ "$_".ToLower() } | Get-Unique
            if (($handlers | ?{$_ -notin $deprecatedHandlers}).Count -eq 0)
            {
                $deprecated = $true
                if ($version.executionHandlers -contains "node")
                {
                    $Node = $Node + 1
                }
                if ($version.executionHandlers -contains "powershell")
                {
                    $PowerShell = $PowerShell + 1
                }
                $count = $count + 1
            }
            $executionHandlers += $handlers
            
        }
    }

    if ($deprecated)
    {
        Write-host "$($extension.publisher)/$($extension.extensionId)"
    }
}

$executionHandlers | %{ $_.ToLower() } | Group-Object | Sort-Object -Property Name -Descending
$allExecutionHandlers = $executionHandlers | %{ $_.ToLower() } | Sort-Object | Get-Unique
$allExecutionHandlers | ConvertTo-Json
Write-host $count
Write-host "Node: $Node"
Write-Host "PowerShell: $PowerShell"
Write-Host "Javascript: $Javascript"
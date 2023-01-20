# vulnerability kinds
# vulnerability kinds

$cacheFile = "report.json"
$report = (Get-Content -raw -Path $cacheFile) | ConvertFrom-Json -AsHashtable

$vulnerableByVerified = @()
$byVerified = @()

foreach ($extension in $report.extensions)
{
    if ( -not (
        ($extension.executionHandlers -contains "Node") -or
        ($extension.executionHandlers -contains "Node10") -or
        ($extension.executionHandlers -contains "Node16")
    ))
    {
        # continue;
    }
    
    $vulnerable = $false
    foreach ($task in $extension.tasks)
    {
        foreach ($version in $task.versions) {
            if (($version.vulnerableDependencies) -or 
                ($version.codescanResults))
            {
                $vulnerable = $true
            }
        }
    }

    if ($vulnerable)
    {
        $vulnerableByVerified += $extension.topPublisher
    }
    $byVerified += $extension.topPublisher
}

write-host "by verified status"
$byVerified | Group-Object | Sort-Object -Property Name -Descending

write-host "vulnerable by verified status"
$vulnerableByVerified | Group-Object | Sort-Object -Property Name -Descending

write-host "of $($report.extensions.count)"
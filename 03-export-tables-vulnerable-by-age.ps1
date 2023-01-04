# vulnerability kinds
# vulnerability kinds

$cacheFile = "report.json"
$report = (Get-Content -raw -Path $cacheFile) | ConvertFrom-Json -AsHashtable

$vulnerableByAge = @()
$byAge = @()

foreach ($extension in $report.extensions)
{
    if ( -not (
        ($extension.executionHandlers -contains "Node") -or
        ($extension.executionHandlers -contains "Node10") -or
        ($extension.executionHandlers -contains "Node16")
    ))
    {
        continue;
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
        $vulnerableByAge += ([int](((Get-Date) - $extension.lastUpdated).TotalDays / 30)).ToString("000")
    }
    $byAge += ([int](((Get-Date) - $extension.lastUpdated).TotalDays / 30)).ToString("000")
}

write-host "by months old"
$byAge | Group-Object | Sort-Object -Property Name 

write-host "vulnerable months old"
$vulnerableByAge | Group-Object | Sort-Object -Property Name

write-host "of $($report.extensions.count)"
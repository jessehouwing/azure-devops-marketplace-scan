# vulnerability kinds
# vulnerability kinds

$cacheFile = "report.json"
$report = (Get-Content -raw -Path $cacheFile) | ConvertFrom-Json -AsHashtable

$vulnerableByRating = @()
$byRating = @()

foreach ($extension in $report.extensions)
{
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
        $vulnerableByRating += [Math]::Round($extension.rating, [System.MidpointRounding]::AwayFromZero)
    }
    $byRating += [Math]::Round($extension.rating, [System.MidpointRounding]::AwayFromZero)
}

write-host "by rating"
$byRating | Group-Object | Sort-Object -Property Name -Descending

write-host "vulnerable-by-rating"
$vulnerableByRating | Group-Object | Sort-Object -Property Name -Descending

write-host "of $($report.extensions.count)"
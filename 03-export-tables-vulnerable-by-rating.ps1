# vulnerability kinds
# vulnerability kinds

$cacheFile = "report.json"
$report = (Get-Content -raw -Path $cacheFile) | ConvertFrom-Json -AsHashtable

$byRating = @()

foreach ($extension in $report.extensions)
{
    $vulnerable = $false
    foreach ($task in $extension.tasks)
    {
        foreach ($version in $task.versions) {
            if (($version.vulnerableDependencies -gt 0) -or 
                ($version.codescanResults))
                {
                    $vulnerable = $true
                }
            }        
        }
    }

    write-host $extension.rating

    if ($vulnerable)
    {
        $byRating += [Math]::Round( 1*$extension.rating, [MidpointRounding]'AwayFromZero' )
    }
}
$byRating | Group-Object | Sort-Object -Property Name -Descending

write-host "of $($report.extensions.count)"
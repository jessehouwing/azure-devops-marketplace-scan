# Find all extensions that rely on deprecated task handlers only

$cacheFile = "report.json"
$report = (Get-Content -raw -Path $cacheFile) | ConvertFrom-Json -AsHashtable


$jsTaskLibversions = @()
$pstaskLibVersions = @()

foreach ($extension in $report.extensions)
{
    $deprecated = $false
    foreach ($task in $extension.tasks)
    {
        foreach ($version in $task.versions){
            if ($version.jsTasklibVersion)
            {
                $jsTaskLibversions += @($version.jsTasklibVersion)
            }
            if ($version.psTaskLibversion)
            {
                $pstaskLibVersions += @($version.psTaskLibversion)
            }
        }
    }
}
write-host JS
$jsTaskLibversions | Group-Object | Sort-Object -Property Name -Descending
write-host PS
$pstaskLibVersions | Group-Object | Sort-Object -Property Name -Descending
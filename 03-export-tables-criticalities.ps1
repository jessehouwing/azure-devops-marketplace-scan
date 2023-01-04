# vulnerability kinds

$cacheFile = "report.json"
$report = (Get-Content -raw -Path $cacheFile) | ConvertFrom-Json -AsHashtable

$depsCriticalities = @()
$codeCriticalities = @()

foreach ($extension in $report.extensions)
{
    foreach ($task in $extension.tasks)
    {
        foreach ($version in $task.versions) {
            if ($null -ne $version.jsTasklibVersion) {
                if ($version.vulnerableDependencies)
                {
                    foreach ($dependency in $version.vulnerableDependencies)
                    {
                        foreach ($vulnerability in $dependency.vulnerabilities)
                        {
                            $depsCriticalities += $vulnerability.severity
                        }
                    }
                }

                if ($version.codescanResults)
                {
                    foreach ($vulnerability in $version.codescanResults)
                    {
                        $codeCriticalities += $vulnerability.level
                    }
                }
            }          
        }
    }
}
$depsCriticalities | Group-Object | Sort-Object -Property Name -Descending
write-host
$codeCriticalities | Group-Object | Sort-Object -Property Name -Descending

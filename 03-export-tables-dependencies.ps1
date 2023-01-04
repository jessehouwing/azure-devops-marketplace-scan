$cacheFile = "report.json"
$report = (Get-Content -raw -Path $cacheFile) | ConvertFrom-Json -AsHashtable


# Find all extensions that rely on a vulnerable task-lib
$totalvulnerabilitiescount = 0
$tasklibvulnerabilitiescount = 0
$vulnerabletasks = 0
$tasklibvulnerableTasks = 0
foreach ($extension in $report.extensions)
{
    $vulnerable = $false
    $tasklibvulnerable = $false
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
                            foreach ($source in $vulnerability.from)
                            {
                                if (($source -like "vsts-task-lib@*") `
                                -or ($source -like "vso-task-lib@*") `
                                -or ($source -like "azure-pipelines-task-lib@*") `
                                -or ($source -like "azure-pipelines-tool-lib@*"))
                                {
                                    $tasklibvulnerabilitiescount = $tasklibvulnerabilitiescount + 1 
                                    $tasklibvulnerable = $true
                                    break;
                                }
                            }
                            $totalvulnerabilitiescount = $totalvulnerabilitiescount + 1 
                            $vulnerable = $true
                        }
                    }
                }
            }          
        }
    }
    if ($vulnerable)
        {
            $vulnerabletasks = $vulnerabletasks + 1
        }
        if ($tasklibvulnerable)
        {
            $tasklibvulnerableTasks = $tasklibvulnerableTasks + 1
        }
}
write-host "$tasklibvulnerabilitiescount / $totalvulnerabilitiescount"
write-host "$tasklibvulnerableTasks / $vulnerabletasks"
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
                                    
                                }
                                $totalvulnerabilitiescount = $totalvulnerabilitiescount + 1 
                                $vulnerable = $true
                            }
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

# Find all extensions that rely on a task-lib that starts with `vsts-` and `vso-`
# Histogram by task-lib version
# Find all extensions that rely on deprecated task handlers only

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

# Histogram by handler version

# total number of tasks vs vulnerabilities
# total number of extensions vs vulnerabilities

# vulnerabilities introduced by task/toollib alone
# vulnerabilities by latest vs all versions


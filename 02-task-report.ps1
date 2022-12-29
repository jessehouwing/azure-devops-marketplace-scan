$cacheFile = "Extensions.json"
$extensions = Get-Content -raw -Path $cacheFile | ConvertFrom-Json

$depedencyResults = Get-Content -raw -Path "result.json" | ConvertFrom-Json

$consolidatedExtensions = @()
$currentDirectory =  Resolve-Path -path "."

function write-report{
    $report = [PSCustomObject]@{
        extensions = $consolidatedExtensions
    }
    Set-Content -path "./report.json" -Value ($report | ConvertTo-Json -Depth 20) -Force
}

write-host "Reading extensions"

foreach ($extension in $extensions) {
    write-host " - $($extension.publisher.publisherName)/$($extension.extensionName) "
    $publisherId = $extension.publisher.publisherName
    $extensionId = $extension.extensionName
    $version = $extension.versions[0].version
    $extractedPath = Resolve-Path -path "./vsixs/$publisherId/$extensionId/$version/"

    $installCount = $extension.statistics | ?{ $_.statisticName -eq "install" } | %{ $_.value }
    $downloadCount = $extension.statistics | ?{ $_.statisticName -eq "onpremDownloads" } | %{ $_.value }
    $rating = $extension.statistics | ?{ $_.statisticName -eq "weightedRating" } | %{ $_.value }

    $consolidatedExtension = [PSCustomObject]@{
        publisher = $publisherId
        extensionId = $extensionId
        version = $version
        tasks = @()
        vsixManifest = $null
        vsoManifest = $null
        localPath = [string]$extractedPath
        scanResults = $null
        executionHandlers = @()
        installCount = $installCount
        downloadCount = $downloadCount
        rating = $rating
    }

    $scanResultPath = join-path -path "vsixs/$publisherId/$extensionId/" -childpath "results-code.json"
    if (Test-Path -Path $scanResultPath -PathType Leaf )
    {
        $consolidatedExtension.scanResults = (gc -raw $scanResultPath) | ConvertFrom-Json
    }

    $vsixManifestFile = Join-Path -Path $extractedPath -ChildPath "extension.vsixmanifest"
    $consolidatedExtension.vsixManifest = [string](gc -raw $vsixManifestFile)

    $vsoManifestFile = Join-Path $extractedPath -ChildPath "extension.vsomanifest"
    if (Test-Path -Path  $vsoManifestFile -PathType Leaf)
    {
        $consolidatedExtension.vsoManifest = (gc -raw $vsoManifestFile) | ConvertFrom-Json
    }

    $consolidatedExtensions += @($consolidatedExtension)
}   

write-host "Reading tasks"
foreach ($extension in $consolidatedExtensions)
{
    write-host " - $($extension.publisher)/$($extension.extensionId)"

    if ($null -ne $extension.vsoManifest)
    {
        # get the contribution id, it's the only unique thing for an extension 
        $taskContributions = $extension.vsoManifest.contributions | ?{ $_.type -eq "ms.vss-distributed-task.task" }
        foreach ($taskContribution in $taskContributions)
        {
            write-host "   - $($taskContribution.id)"

            $taskroot = $taskContribution.properties.name
            $contributionId = $taskContribution.id

            $task = [PSCustomObject]@{
                id = $contributionId
                localpath = [string](join-path -Path $extension.localPath -ChildPath $taskroot)
                versions = @()
                isDeprecated = $false
                executionHandlers = @()
            }

            $taskManifestFiles = Get-ChildItem -Path $task.localpath -Filter task.json -Recurse

            foreach ($taskManifestFile in $taskManifestFiles)
            {
                $taskManifestString = gc -raw $taskManifestFile.FullName
                $taskManifest = $taskManifestString | ConvertFrom-Json -AsHashtable
                
                try {
                    $majorVersion = $taskManifest.version.Major
                }
                catch{
                    try {
                        $majorVersion = $taskManifest.version.major
                    }
                    catch {
                        $majorVersion = 0
                    }
                }
                try {
                    $minorVersion = $taskManifest.version.Minor
                }
                catch{
                    try {
                        $minorVersion = $taskManifest.version.minor
                    }
                    catch {
                        $minorVersion = 0
                    }
                }
                try {
                    $patchVersion = $taskManifest.version.Patch
                }
                catch{
                    try {
                        $patchVersion = $taskManifest.version.patch
                    }
                    catch {
                        $patchVersion = 0
                    }
                }

                $versionString = [System.Version]"0$majorVersion.0$minorVersion.0$patchVersion"

                $version = [PSCustomObject]@{
                    name = $taskManifest.name
                    id = $taskManifest.id
                    version = $versionString
                    localpath = $taskManifestFile.Directory.FullName
                    taskManifest = $taskManifest
                    executionHandlers = @()
                    vulnerableDependencies = @()
                    codescanResults = @()
                    isLatest = $false
                    jsTasklibVersion = ""
                    psTaskLibversion = ""
                }

                write-host "     - $($version.version)"

                if ($null -ne $taskManifest.execution.Keys)
                {
                    $version.executionHandlers += @($taskManifest.execution.Keys)
                }
                if ($null -ne $taskManifest.prejobexecution.Keys)
                {
                    $version.executionHandlers += @($taskManifest.prejobexecution.Keys)
                }
                if ($null -ne $taskManifest.postjobexection.Keys)
                {
                    $version.executionHandlers += @($taskManifest.postjobexecution.Keys)
                }
                $version.executionHandlers = @($version.executionHandlers | Select-Object -Unique)

                # get the azure-pipelines-task-lib version used
                if ($version.executionHandlers -contains "Node" -or
                    $version.executionHandlers -contains "Node10" -or
                    $version.executionHandlers -contains "Node16"
                )
                {
                    $tasklibdir = dir -Path $version.localpath -recurse "azure-pipelines-task-lib"
                    if (-not $tasklibdir)
                    {
                        $tasklibdir = dir -Path $version.localpath -recurse "vsts-task-lib"
                    }
                    if (-not $tasklibdir)
                    {
                        $tasklibdir = dir -Path $version.localpath -recurse "vso-task-lib"
                    }

                    if ($tasklibdir)
                    {
                        gc -raw (join-path -path $tasklibdir.FullName -ChildPath "package.json") | ConvertFrom-Json -AsHashtable | %{
                            $version.jsTasklibVersion = $_.version
                        }
                    } else {
                        $version.jsTasklibVersion = "Unknown"
                    }
                }
                # get the VstsTaskLib version used
                if ($version.executionHandlers -contains "PowerShell3")
                {
                    $version.psTaskLibVersion = "Unknown"
                    $tasklibdir = dir -Path $version.localpath -recurse "VstsTaskSdk"
                    if (-not $tasklibdir)
                    {
                        $version.psTaskLibVersion = "missing"
                    } else {
                        $manifest = gc -raw (join-path -path $tasklibdir.FullName -ChildPath "VstsTaskSdk.psd1")
                        if ($manifest)
                        {
                            # probably malformed duplicated manifest. Truncate and try again.
                            $manifest = [regex]::Replace("$manifest", "(?sm:)^}\s*@{.*", "}")
                            $data = ( Invoke-Expression $manifest )
                            $version.psTaskLibVersion = $data.ModuleVersion
                        }
                    }
                }

                $task.versions += $version

                # Lets grab the vulnerable dependencies for this version
                # in the list of dependency culnerabilities, find all results that share the base path with this task
                $vulnerabilities = $depedencyResults | ?{ 
                    ([System.Uri]$version.localpath).IsBaseOf([System.Uri](join-path -path $currentDirectory -ChildPath $_.displayTargetFile))
                }
                $version.vulnerableDependencies = $vulnerabilities
                
                if ($extension.scanResults)
                {
                    # lets add the codescan results
                    $codescanResults = $extension.scanResults.runs.results | ?{ 
                        ([System.Uri]$version.localpath).IsBaseOf([System.Uri](join-path -path $extension.localPath -ChildPath $_.locations[0].physicalLocation.artifactLocation.uri))
                    }
                    $version.codescanResults = $codescanResults
                }
                
                $task.executionHandlers += @($version.executionHandlers)
                $task.executionHandlers = @($task.executionHandlers | Select-Object -Unique )
            }

            $task.isDeprecated = ($task.versions | ?{ $_.taskManifest.deprecated -eq $true }).Count -gt 0
            (@($task.versions | Sort-Object -Property version))[-1].isLatest = $true
            
            $extension.tasks += $task
        }
    }
}

write-report

# find all dependency vulnerabilities for this folder

# find all codescan vulnerabilities for this folder

# break down by criticality

# find all execution handlers for this task

# find the tasklib version for this task

# find the extension for this task
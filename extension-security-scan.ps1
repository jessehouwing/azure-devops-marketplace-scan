# create a function in powershell that takes 2 parameters called page and pagesize
function Get-Extensions
{
    [cmdletbinding()]
    Param (
        [int]$Page,
        [int]$PageSize
    )

    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $result = Invoke-WebRequest -UseBasicParsing -Uri "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery" `
        -Method "POST" `
        -WebSession $session `
        -Headers @{
        "authority"="marketplace.visualstudio.com"
        "method"="POST"
        "path"="/_apis/public/gallery/extensionquery"
        "scheme"="https"
        "accept"="application/json;api-version=7.1-preview.1;excludeUrls=true"
        "accept-encoding"="gzip, deflate, br"
        "accept-language"="en-US,en;q=0.9"
        "cache-control"="no-cache"
        "origin"="https://marketplace.visualstudio.com"
        "x-vss-reauthenticationaction"="Suppress"
        } `
        -ContentType "application/json" `
        -Body "{`"assetTypes`":[`"Microsoft.VisualStudio.Services.Icons.Default`",`"Microsoft.VisualStudio.Services.Icons.Branding`",`"Microsoft.VisualStudio.Services.Icons.Small`"],`"filters`":[{`"criteria`":[{`"filterType`":8,`"value`":`"Microsoft.VisualStudio.Services`"},{`"filterType`":8,`"value`":`"Microsoft.VisualStudio.Services.Integration`"},{`"filterType`":8,`"value`":`"Microsoft.VisualStudio.Services.Cloud`"},{`"filterType`":8,`"value`":`"Microsoft.TeamFoundation.Server`"},{`"filterType`":8,`"value`":`"Microsoft.TeamFoundation.Server.Integration`"},{`"filterType`":8,`"value`":`"Microsoft.VisualStudio.Services.Cloud.Integration`"},{`"filterType`":8,`"value`":`"Microsoft.VisualStudio.Services.Resource.Cloud`"},{`"filterType`":10,`"value`":`"target:\`"Microsoft.VisualStudio.Services\`" target:\`"Microsoft.VisualStudio.Services.Integration\`" target:\`"Microsoft.VisualStudio.Services.Cloud\`" target:\`"Microsoft.TeamFoundation.Server\`" target:\`"Microsoft.TeamFoundation.Server.Integration\`" target:\`"Microsoft.VisualStudio.Services.Cloud.Integration\`" target:\`"Microsoft.VisualStudio.Services.Resource.Cloud\`" `"},{`"filterType`":12,`"value`":`"37888`"},{`"filterType`":5,`"value`":`"Azure Pipelines`"}],`"direction`":2,`"pageSize`":$PageSize,`"pageNumber`":$Page,`"sortBy`":4,`"sortOrder`":0,`"pagingToken`":null}],`"flags`":870}"

    return ($result.Content | ConvertFrom-Json).results[0];
}

& fnm use v16

$pageSize= 100;
$page = 1
$totalFetched = 0
$max = 0
$extensions = @()
$cacheFile = "Extensions.json"
if (-not (Test-Path -path $cacheFile -PathType Leaf))
{
    do 
    {
        $result = Get-Extensions -PageSize $pageSize -Page $page
        $totalFetched += $result.extensions.Count
        
        $max = $result.resultMetaData[0].metadataItems[0].count
        $extensions += $result.extensions
        $page += 1
    }
    while ($totalFetched -lt $max)

    Set-Content -path $cacheFile -Value ($extensions | ConvertTo-Json -Depth 100)
}
else {
    $extensions = Get-Content -raw -Path $cacheFile | ConvertFrom-Json
}

if ($max -eq 0)
{
    $max = $extensions.Count
}

$token = ""
$marketplace = "https://marketplace.visualstudio.com"
& tfx login --auth-type pat --token $token --service-url $marketplace --no-color --no-prompt
mkdir "vsixs" -force

$count = 1
foreach ($extension in $extensions)
{
    $publisherId = $extension.publisher.publisherName
    $extensionId = $extension.extensionName
    $savePath = "vsixs/$publisherId/$extensionId/$($extension.versions[0].version).vsix"
    $extractedPath = "vsixs/$publisherId/$extensionId/$($extension.versions[0].version)/"
    mkdir -path "vsixs/$publisherId/$extensionId/" -Force
    if (-not (Test-Path -Path $savepath -PathType Leaf))
    {
        $extensionData = (& tfx extension show --auth-type pat --token $token --service-url $marketplace --publisher $publisherId --extension-id $extensionId --json --no-color --no-prompt) | ConvertFrom-Json
        $vsixUrl = $extensionData.versions[0].files | ?{ $_.assetType -eq "Microsoft.VisualStudio.Services.VSIXPackage" } | select -ExpandProperty source
        Invoke-WebRequest -Uri $vsixUrl -OutFile $savePath
    }

    if (-not (Test-path -Path $extractedPath -PathType Container))
    {
        Expand-Archive -Path $savePath -DestinationPath $extractedPath
    }

    write-host "##### COUNT: $count / $max "
    $count += 1
}

$count = 1
foreach ($extension in $extensions)
{
    $publisherId = $extension.publisher.publisherName
    $extensionId = $extension.extensionName
    $savePath = "vsixs/$publisherId/$extensionId/$($extension.versions[0].version).vsix"
    $extractedPath = "vsixs/$publisherId/$extensionId/$($extension.versions[0].version)/"
    
    if (-not ((Test-Path -Path (join-path -path $extractedPath -childpath "..\results-code.json") -PathType Leaf) -or (Test-Path -Path (join-path -path $extractedPath -childpath "..\results-code.completed") -PathType Leaf)))
    {
        pushd $extractedPath
        & snyk code test --json-file-output=..\results-code.json
        set-content -path ..\results-code.completed -value "completed"
        popd
    }

    write-host "##### COUNT: $count / $max "
    $count += 1
}


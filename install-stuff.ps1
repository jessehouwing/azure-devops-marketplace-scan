fnm use v16

foreach($line in Get-Content -Path "missing-node_modules.txt") 
{
    $path = Split-Path -path $line -Parent
    cd $path
    & npm install
}
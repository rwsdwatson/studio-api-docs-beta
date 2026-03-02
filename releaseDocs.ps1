param(
[string]$ACTOR="user",
[string]$TOKEN="password"
)

write-host  "Build the documentation site" 
write-host  "`ACTOR is $ACTOR" 

$SOURCE_DIR=$psscriptroot
$TEMP_REPO_DIR=[System.IO.Path]::GetFullPath("$psscriptroot/../docs-gh-pages")

# Determine current repo from the GitHub environment variable, with fallback to directory name
$GITHUB_REPO = $env:GITHUB_REPOSITORY
if ($GITHUB_REPO) {
    $betaSuffix = if ($GITHUB_REPO -match '-beta$') { '-beta' } else { '' }
} else {
    $currentRepoName = Split-Path -Leaf $SOURCE_DIR
    $betaSuffix = if ($currentRepoName -match '-beta$') { '-beta' } else { '' }
    $GITHUB_REPO = "rws/studio-api-docs${betaSuffix}"
}

$remote_repo = "https://github-actions:${TOKEN}@github.com/${GITHUB_REPO}.git"

write-host "Cloning the repo $remote_repo with the gh-pages branch"
git clone $remote_repo --branch gh-pages $TEMP_REPO_DIR
Set-Location $TEMP_REPO_DIR

#delete gh-pages_temp branch if already exist 
$checkBranch =  git show-ref origin/gh-pages_temp
Write-Output($checkBranch)
if($checkBranch){
	Write-Output("delete existing branch gh-pages_temp")
	git push origin --delete gh-pages_temp
}

git checkout -b gh-pages_temp
$items = Get-ChildItem
$keepVersions = @("15.2", "16.1", "16.2", "17.0", "17.1", "17.2", "18.0", "18.1")
foreach ($item in $items){
 if ($item.Name -notin $keepVersions){
  git rm $item -r
 }
}
write-host "Stripping previously embedded beta headers from kept HTML files"
Get-ChildItem -Recurse -Filter "*.html" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw -Encoding UTF8
    if ($content -notmatch 'Beta / Prerelease Documentation') { return }

    # Remove the injected <style> block
    $content = $content -replace '\s*<style>\.navbar \{ top: 50px !important; \} body \{ padding-top: 100px !important; \}<\/style>', ''

    # Remove the injected beta banner <div> (single line, inserted after <body>)
    $content = $content -replace '\r?\n\s*<div[^>]+background:\s*#fff3cd[^>]*>[\s\S]*?<\/div>', ''

    Set-Content -Path $_.FullName -Value $content -Encoding UTF8
}

write-host "Copy documentation into the repo"

Copy-Item "$SOURCE_DIR\_site\*" .\ -Recurse -force

# Generate beta-config.js so beta-banner.js knows whether to show the banner
$metadataPath = Join-Path $SOURCE_DIR "source-version-metadata.json"
$version = ""
$timestamp = ""
if (Test-Path $metadataPath) {
    try {
        $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
        $version = $metadata.ProductVersion
        if (-not $version) { $version = $metadata.AssemblyVersion }
        $timestamp = $metadata.Timestamp
    } catch {
        write-host "Unable to read source-version-metadata.json; continuing without metadata"
    }
}

$betaConfigPath = ".\styles\beta-config.js"
if ($betaSuffix -eq '-beta') {
    write-host "Writing beta-config.js (isBeta=true, version=$version)"
    $betaConfigContent = "window.betaConfig = { isBeta: true, version: `"$version`", timestamp: `"$timestamp`" };"
} else {
    $betaConfigContent = "window.betaConfig = { isBeta: false };"
}
Set-Content -Path $betaConfigPath -Value $betaConfigContent -Encoding UTF8

write-host "Push the new docs to the remote branch"
git config --local user.email "github-actions[bot]@users.noreply.sdl.com"
git config --local user.name "github-actions[bot]"
git add .\ -A
git commit -m "Update generated documentation"
git push "$remote_repo" HEAD:gh-pages_temp
Write-Output (${TOKEN}) | gh auth login --with-token
gh pr create --title "Update generated documentation" --body "Update generated documentation" -H gh-pages_temp -B gh-pages

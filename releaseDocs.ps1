param(
[string]$ACTOR="user",
[string]$TOKEN="password"
)

write-host  "Build the documentation site" 
write-host  "`ACTOR is $ACTOR" 

$SOURCE_DIR=$psscriptroot
$TEMP_REPO_DIR=[System.IO.Path]::GetFullPath("$psscriptroot/../docs-gh-pages")

# Determine if current repo ends with -beta
$currentRepoName = Split-Path -Leaf $SOURCE_DIR
$betaSuffix = if ($currentRepoName -match '-beta$') { '-beta' } else { '' }

$remote_repo="https://github-actions:${TOKEN}@github.com/rws/studio-api-docs${betaSuffix}.git"

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
write-host "Copy documentation into the repo"

Copy-Item "$SOURCE_DIR\_site\*" .\ -Recurse -force

# Inject beta header into all HTML files (only for beta branch)
if ($betaSuffix -eq '-beta') {
    write-host "Injecting beta header into HTML files"
    $metadataPath = Join-Path $SOURCE_DIR "source-version-metadata.json"
    $metadataSuffix = ""
    if (Test-Path $metadataPath) {
        try {
            $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
            $version = $metadata.ProductVersion
            if (-not $version) { $version = $metadata.AssemblyVersion }
            $timestamp = $metadata.Timestamp
            if ($version -or $timestamp) {
                $metadataSuffix = " (Version: $version; Date: $timestamp)"
            }
        } catch {
            write-host "Unable to read source-version-metadata.json; continuing without metadata"
        }
    }

    $betaHeaderHtml = @"
<div style="background: #fff3cd; border-bottom: 2px solid #ffc107; padding: 12px 0; position: sticky; top: 0; z-index: 1000; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
    <div class="container" style="text-align: center;">
        <p style="margin: 0; color: #856404; font-weight: 500; font-size: 14px;">
            <strong>⚠️ Beta / Prerelease Documentation</strong> - This documentation is subject to change and may not reflect the final product.$metadataSuffix
        </p>
    </div>
</div>
"@

    Get-ChildItem -Recurse -Filter "*.html" | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        # Insert beta header after <body> tag
        $newContent = $content -replace '(<body[^>]*>)', "`$1`n$betaHeaderHtml"
        Set-Content -Path $_.FullName -Value $newContent -Encoding UTF8
    }
}

write-host "Push the new docs to the remote branch"
git config --local user.email "github-actions[bot]@users.noreply.sdl.com"
git config --local user.name "github-actions[bot]"
git add .\ -A
git commit -m "Update generated documentation"
git push "$remote_repo" HEAD:gh-pages_temp
Write-Output (${TOKEN}) | gh auth login --with-token
gh pr create --title "Update generated documentation" --body "Update generated documentation" -H gh-pages_temp -B gh-pages

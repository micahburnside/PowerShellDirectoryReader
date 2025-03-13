<#
.SYNOPSIS
    Generates a JSON representation and an ASCII tree of a directory while respecting ignore patterns.

.DESCRIPTION
    This script reads ignore patterns from ignore files (default: .gitignore, .dockerignore, .npmignore) in the target directory.
    It builds a folder tree, skipping files/directories matching the ignore patterns. If no .gitignore is found, it ignores items 
    starting with a dot (e.g., .venv, .idea). Always ignores short, lowercase build artifact directories (e.g., bin, obj). The result is output as JSON and an ASCII tree.

.PARAMETER TargetDirectory
    The directory to scan. In -UseCLI mode, you can specify it or be prompted; in -UseGUI mode, it’s always selected via dialog.

.PARAMETER OutputPath
    (Optional) The file path for the JSON output. In -UseCLI mode, ignored; in -UseGUI mode, prompted via dialog if not provided.

.PARAMETER UseCLI
    (Switch) Runs in CLI mode, prompting the user to choose between GUI folder selection or manual entry; JSON output defaults to "<foldername>-tree.json".

.PARAMETER UseGUI
    (Switch) Runs in GUI mode, using dialogs for directory and output selection.

.PARAMETER IncludeExtensions
    (Optional) An array of file extensions to include. If empty (default), all files not excluded by ignore patterns are included.

.EXAMPLE
    .\FolderTreeGenerator.ps1 -UseGUI
    Runs in GUI mode, prompting with dialogs for directory and JSON output file.

.EXAMPLE
    .\FolderTreeGenerator.ps1 -UseCLI
    Runs in CLI mode, asking if you want to select a folder with GUI or enter a path manually; JSON saved as "<foldername>-tree.json".
#>

param(
    [string]$TargetDirectory,
    [string]$OutputPath,
    [switch]$UseCLI,
    [switch]$UseGUI,
    [string[]]$IncludeExtensions = @()
)

# Ensure exactly one mode is specified.
if (-not $UseCLI -and -not $UseGUI) {
    Write-Error "You must specify either -UseCLI or -UseGUI."
    exit 1
}
if ($UseCLI -and $UseGUI) {
    Write-Error "You cannot specify both -UseCLI and -UseGUI."
    exit 1
}

# Set console output encoding to UTF-8 for proper Unicode display (e.g., ├──, └──, │).
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Handle directory selection based on mode.
if ($UseGUI -or ($UseCLI -and [string]::IsNullOrEmpty($TargetDirectory))) {
    if ($UseGUI -or ($UseCLI -and $(Write-Host "Do you want to select the folder with a GUI? (Y/N): "; $response = Read-Host; $response -eq 'Y'))) {
        Add-Type -AssemblyName System.Windows.Forms
        $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderDialog.Description = "Select the target directory to scan for the folder tree."
        if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $TargetDirectory = $folderDialog.SelectedPath
        } else {
            Write-Output "Operation cancelled by user."
            exit
        }
    } else {
        # CLI manual entry.
        $TargetDirectory = Read-Host "Enter the target directory path"
        if ([string]::IsNullOrEmpty($TargetDirectory)) {
            Write-Error "No directory specified."
            exit 1
        }
    }
}

# Function to load ignore patterns from multiple ignore files.
function Get-IgnorePatterns {
    param(
        [string]$BasePath,
        [string[]]$IgnoreFiles = @(".gitignore", ".dockerignore", ".npmignore")
    )
    
    $patterns = @()
    $hasGitignore = $false
    foreach ($file in $IgnoreFiles) {
        $filePath = Join-Path $BasePath $file
        if (Test-Path -LiteralPath $filePath) {
            if ($file -eq ".gitignore") {
                $hasGitignore = $true
            }
            $lines = Get-Content -LiteralPath $filePath | Where-Object {
                $_.Trim() -ne "" -and $_.Trim() -notmatch "^\s*#" -and $_ -notmatch "^\s*!"
            } | ForEach-Object { $_.Trim().TrimEnd('/') }
            $patterns += $lines
        }
    }
    Write-Output "Ignore patterns loaded from $BasePath : $patterns"
    Write-Output "Has .gitignore: $hasGitignore"
    return [PSCustomObject]@{
        Patterns = $patterns
        HasGitignore = $hasGitignore
    }
}

# Recursive function to build the folder tree while respecting ignore patterns.
function Get-FolderTree {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [string[]]$IgnorePatterns = @(),
        [bool]$HasGitignore = $false,
        [string[]]$IncludeExtensions = @()
    )
    
    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    } catch {
        Write-Warning "Cannot access path: $Path"
        return $null
    }
    
    # Ignore build artifact-like directories: short, all-lowercase names.
    if ($item.PSIsContainer -and $item.Name.Length -le 6 -and $item.Name -cmatch "^[a-z]+$") {
        Write-Verbose "Ignoring $($item.FullName) as a potential build artifact directory"
        return $null
    }
    
    # Check ignore patterns from files.
    foreach ($pattern in $IgnorePatterns) {
        if ($item.Name -like $pattern -or $item.FullName -like "*$pattern*") {
            Write-Verbose "Ignoring $($item.FullName) due to pattern: $pattern"
            return $null
        }
    }
    
    # Ignore dot-files if no .gitignore is present.
    if (-not $HasGitignore -and $item.Name -match "^\..*$") {
        Write-Verbose "Ignoring $($item.FullName) as a dot-item with no .gitignore"
        return $null
    }
    
    $result = [PSCustomObject]@{
        Name = $item.Name
        Type = if ($item.PSIsContainer) { "Folder" } else { "File" }
    }
    
    if ($item.PSIsContainer) {
        $result | Add-Member -MemberType NoteProperty -Name Children -Value @()
        foreach ($child in Get-ChildItem -LiteralPath $Path) {
            $childTree = Get-FolderTree -Path $child.FullName -IgnorePatterns $IgnorePatterns -HasGitignore $HasGitignore -IncludeExtensions $IncludeExtensions
            if ($childTree -ne $null) {
                $result.Children += $childTree
            }
        }
    } else {
        if ($IncludeExtensions.Count -gt 0) {
            $extension = [System.IO.Path]::GetExtension($item.Name)
            if (-not ($IncludeExtensions -contains $extension)) {
                return $null
            }
        }
    }
    return $result
}

# Function to generate an ASCII tree from the folder tree object using Unicode characters.
function Get-AsciiTree {
    param(
        [Parameter(Mandatory=$true)]
        $Node,
        [string]$Prefix = "",
        [bool]$IsLast = $true
    )
    
    $output = @()
    $currentPrefix = $Prefix
    $symbol = if ($IsLast) { "└── " } else { "├── " }
    $output += "$currentPrefix$symbol$($Node.Name)"
    
    if ($Node.Type -eq "Folder" -and $Node.Children) {
        $validChildren = $Node.Children | Where-Object { $_ -ne $null -and $_.PSObject.Properties.Name -contains "Name" }
        $childrenCount = $validChildren.Count
        for ($i = 0; $i -lt $childrenCount; $i++) {
            $child = $validChildren[$i]
            $isLastChild = ($i -eq $childrenCount - 1)
            $newPrefix = $Prefix + $(if ($IsLast) { "    " } else { "│   " })
            $output += Get-AsciiTree -Node $child -Prefix $newPrefix -IsLast $isLastChild
        }
    }
    return $output
}

# Resolve the target directory.
try {
    $resolvedPath = Resolve-Path -Path $TargetDirectory -ErrorAction Stop
    $basePath = $resolvedPath.Path
} catch {
    Write-Error "Target directory not found: $TargetDirectory"
    exit 1
}

# Read ignore patterns from the target directory.
$ignoreInfo = Get-IgnorePatterns -BasePath $basePath
$ignorePatterns = $ignoreInfo.Patterns
$hasGitignore = $ignoreInfo.HasGitignore

# Build the folder tree using the ignore patterns from the ignore files.
$folderTree = Get-FolderTree -Path $basePath -IgnorePatterns $ignorePatterns -HasGitignore $hasGitignore -IncludeExtensions $IncludeExtensions

if ($null -eq $folderTree) {
    Write-Error "Failed to generate folder tree. The directory might be empty or all items ignored."
    exit 1
}

# Convert the folder tree to JSON.
$jsonOutput = $folderTree | ConvertTo-Json -Depth 10

# Generate the ASCII tree.
$asciiTree = Get-AsciiTree -Node $folderTree
if ($null -eq $asciiTree -or $asciiTree.Count -eq 0) {
    Write-Warning "ASCII tree generation resulted in an empty tree."
    $asciiTree = @("Empty tree generated for $($folderTree.Name)")
}

# Define the paths using the directory name.
$folderName = [System.IO.Path]::GetFileName($basePath)
$asciiOutputPath = Join-Path -Path $basePath -ChildPath "$folderName.txt"
$defaultJsonOutputPath = Join-Path -Path $basePath -ChildPath "$folderName-tree.json"

# Handle JSON output based on mode.
if ($UseGUI) {
    if ([string]::IsNullOrEmpty($OutputPath)) {
        Add-Type -AssemblyName System.Windows.Forms
        $OutputPath = $defaultJsonOutputPath
        
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.InitialDirectory = $basePath
        $saveFileDialog.FileName = "$folderName-tree.json"
        $saveFileDialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
        $saveFileDialog.Title = "Confirm output file for folder tree JSON"
        if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $OutputPath = $saveFileDialog.FileName
        } else {
            Write-Output "Operation cancelled by user."
            exit
        }
    }
} else {
    # CLI mode: Use default JSON path if not specified.
    if ([string]::IsNullOrEmpty($OutputPath)) {
        $OutputPath = $defaultJsonOutputPath
    }
}

# Output the JSON to a file.
$jsonOutput | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Output "JSON output written to: $OutputPath"

# Output the ASCII tree to console and file with UTF-8 encoding.
Write-Output "`nASCII Folder Tree:"
Write-Output $asciiTree
try {
    $asciiTree | Out-File -FilePath $asciiOutputPath -Encoding UTF8
    Write-Output "ASCII tree written to: $asciiOutputPath"
} catch {
    Write-Error "Failed to write ASCII tree to $asciiOutputPath : $_"
}


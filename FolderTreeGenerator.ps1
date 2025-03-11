<#
.SYNOPSIS
    Generates a JSON representation of a directory tree while respecting ignore patterns.

.DESCRIPTION
    This script reads ignore patterns from one or more ignore files (default: .gitignore, .dockerignore, .npmignore)
    found in the target directory. It then recursively builds a folder tree of that directory, skipping any files or
    directories that match the ignore patterns. The result is output as JSON either to a file (if an output path is
    provided or selected via a GUI dialog) or printed to the console.

.PARAMETER TargetDirectory
    The directory to scan. Defaults to the current directory (".") if not provided. When -UseGUI is specified and no
    target directory is explicitly supplied (or if you wish to choose a different one), a folder browser dialog will prompt you to select one.

.PARAMETER OutputPath
    (Optional) The file path to which the JSON output will be saved. If not provided and -UseGUI is specified,
    a file-save dialog will open. If neither is provided, the JSON is printed to the console.

.PARAMETER UseGUI
    (Switch) If specified and no TargetDirectory or OutputPath is explicitly supplied, GUI dialogs will prompt you to select them.

.PARAMETER IncludeExtensions
    (Optional) An array of file extensions to include. If left empty (the default), all files (not excluded by ignore
    patterns) are included. This makes the script language agnostic by default.

.EXAMPLE
    .\FolderTreeGenerator.ps1 -TargetDirectory "C:\MyProject" -OutputPath "C:\MyProject\folderTree.json"
    Scans "C:\MyProject", applies ignore patterns from ignore files, and writes the resulting JSON to folderTree.json.

.EXAMPLE
    .\FolderTreeGenerator.ps1 -UseGUI
    Prompts you to select a target directory and an output file using GUI dialogs, then generates the folder tree JSON.
#>

param(
    [string]$TargetDirectory = ".",
    [string]$OutputPath,
    [switch]$UseGUI,
    [string[]]$IncludeExtensions = @()  # Empty by default for language-agnostic behavior.
)

# If UseGUI is specified and TargetDirectory is left as default or not explicitly provided,
# prompt with a folder browser dialog.
if ($UseGUI -and ([string]::IsNullOrEmpty($TargetDirectory) -or $TargetDirectory -eq ".")) {
    Add-Type -AssemblyName System.Windows.Forms
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select the target directory to scan for the folder tree."
    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
         $TargetDirectory = $folderDialog.SelectedPath
    } else {
         Write-Output "Operation cancelled by user."
         exit
    }
}

# Function to load ignore patterns from multiple ignore files.
function Get-IgnorePatterns {
    param(
        [string]$BasePath,
        [string[]]$IgnoreFiles = @(".gitignore", ".dockerignore", ".npmignore")
    )
    
    $patterns = @()
    foreach ($file in $IgnoreFiles) {
        $filePath = Join-Path $BasePath $file
        if (Test-Path -LiteralPath $filePath) {
            $lines = Get-Content -LiteralPath $filePath | Where-Object {
                $_.Trim() -ne "" -and $_.Trim() -notmatch "^\s*#" -and $_ -notmatch "^\s*!"
            } | ForEach-Object { $_.Trim().TrimEnd('/') }  # Remove trailing slash for consistency.
            $patterns += $lines
        }
    }
    return $patterns
}

# Recursive function to build the folder tree while respecting ignore patterns.
function Get-FolderTree {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [string[]]$IgnorePatterns = @(),
        [string[]]$IncludeExtensions = @()
    )
    
    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    } catch {
        Write-Warning "Cannot access path: $Path"
        return $null
    }
    
    # Check if the current item should be ignored.
    foreach ($pattern in $IgnorePatterns) {
        if ($item.Name -like $pattern -or $item.FullName -like "*$pattern*") {
            return $null
        }
    }
    
    $result = [PSCustomObject]@{
        Name = $item.Name
        Type = if ($item.PSIsContainer) { "Folder" } else { "File" }
    }
    
    if ($item.PSIsContainer) {
        $result | Add-Member -MemberType NoteProperty -Name Children -Value @()
        foreach ($child in Get-ChildItem -LiteralPath $Path) {
            $childTree = Get-FolderTree -Path $child.FullName -IgnorePatterns $IgnorePatterns -IncludeExtensions $IncludeExtensions
            if ($childTree -ne $null) {
                $result.Children += $childTree
            }
        }
    } else {
        # If an include filter is provided, only include files with matching extensions.
        if ($IncludeExtensions.Count -gt 0) {
            $extension = [System.IO.Path]::GetExtension($item.Name)
            if (-not ($IncludeExtensions -contains $extension)) {
                return $null
            }
        }
    }
    return $result
}

# Resolve the target directory.
try {
    $resolvedPath = Resolve-Path -Path $TargetDirectory -ErrorAction Stop
    $basePath = $resolvedPath.Path
} catch {
    Write-Error "Target directory not found: $TargetDirectory"
    exit 1

# Read ignore patterns from the target directory.
$ignorePatterns = Get-IgnorePatterns -BasePath $basePath

# Build the folder tree using the ignore patterns from the ignore files.
$folderTree = Get-FolderTree -Path $basePath -IgnorePatterns $ignorePatterns -IncludeExtensions $IncludeExtensions

# Convert the folder tree to JSON.
$jsonOutput = $folderTree | ConvertTo-Json -Depth 10

# If UseGUI is specified and OutputPath is empty, prompt for an output file.
if ([string]::IsNullOrEmpty($OutputPath) -and $UseGUI) {
    Add-Type -AssemblyName System.Windows.Forms
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
    $saveFileDialog.Title = "Select output file for folder tree JSON"
    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
         $OutputPath = $saveFileDialog.FileName
    } else {
         Write-Output "Operation cancelled by user."
         exit
    }
}

# Output the JSON either to a file or to the console.
if ([string]::IsNullOrEmpty($OutputPath)) {
    Write-Output $jsonOutput
} else {
    $jsonOutput | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Output "JSON output written to: $OutputPath"
}

# TODO: ADD README

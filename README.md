# FolderTreeGenerator

A PowerShell script that generates a JSON representation and an ASCII tree of a directory, respecting ignore patterns and excluding build artifacts.

## Overview

`FolderTreeGenerator.ps1` recursively scans a directory, skipping files and directories matching patterns from ignore files (`.gitignore`, `.dockerignore`, `.npmignore`). If no `.gitignore` is present, it ignores dot-files (e.g., `.venv`, `.idea`) and short, lowercase build artifact directories (e.g., `bin`, `obj`, `debug`). The output is saved as a JSON file (`<foldername>-tree.json`) and an ASCII tree file (`<foldername>.txt`) in the target directory.

## Prerequisites

- PowerShell 5.1 or later (Windows PowerShell or PowerShell Core).
- Windows Forms support (for GUI mode).

## Usage

### Allows user to choose directory to get folder tree diagram

Run the script in GUI mode to select a directory and JSON output file via dialogs:

```ps1
.\FolderTreeGenerator.ps1 -UseGUI
```
- Prompts with a folder selection dialog.
- Followed by a file save dialog for the JSON output (defaults to <foldername>-tree.json).

## CLI Mode: Get Folder Tree Diagram for a Directory

Run the script in CLI mode with the command:
```ps1
".\FolderTreeGenerator.ps1 -UseCLI"
```
-Asks: "Do you want to select the folder with a GUI? (Y/N)".

-Y: Opens a folder selection dialog.
-N: Prompts for a manual path entry (e.g., C:\path\to\folder).

## Output
- JSON File: <foldername>-tree.json in the target directory, containing the folder structure.
- ASCII Tree: <foldername>.txt in the target directory, showing a visual tree with Unicode characters (e.g., ├──, └──).
- Console: Displays the ASCII tree during execution.

## Features
- Ignore Patterns: Respects .gitignore, .dockerignore, and .npmignore if present.
- Dot-File Exclusion: Ignores items starting with . (e.g., .venv, .idea) when no .gitignore exists.
- Build Artifact Exclusion: Automatically skips short, lowercase directories (e.g., bin, obj, debug) as potential build outputs.

## Example
To create a README.md file in PowerShell and then run the script, use the following commands:

```ps1
"echo $null > \"README.md\""
".\FolderTreeGenerator.ps1 -UseCLI"
```
- Enter N and specify a path like C:\Users\Owner\Projects\DotNetTemplate.
- Outputs DotNetTemplate-tree.json and DotNetTemplate.txt in that directory.

## Installation
Clone the repository:

```ps1
git clone https://github.com/micahburnside/PowerShellDirectoryReader.git
cd PowerShellDirectoryReader
```
- Run the script from the FolderTreeGenerator directory.

## Contributing
Feel free to submit issues or pull requests to improve functionality or add features!

## License
This project is unlicensed—use it as you see fit!

---

### What Was Done
- **Quoted Commands**: All PowerShell commands within `ps1` code blocks are now wrapped in double quotes:
  - GUI mode: `".\FolderTreeGenerator.ps1 -UseGUI"`
  - CLI mode: `".\FolderTreeGenerator.ps1 -UseCLI"`
  - Example: `"echo $null > \"README1.md\""` and `".\FolderTreeGenerator.ps1 -UseCLI"`
- **Escaped Inner Quotes**: In the `echo` command, the quotes around `README1.md` are escaped (`\"`) to ensure proper syntax within the outer quotes.
- **Preserved Context**: The rest of the `README.md` remains intact, with only the commands modified as requested.

### How to Use This
1. **Copy the Content**: Select everything inside the markdown code block above.
2. **Save as `README.md`**: Paste it into a text editor and save it as `README.md` in your project folder (e.g., `C:\path\to\FolderTreeGenerator`).
3. **Run the Commands**: Use the quoted commands exactly as shown in your PowerShell environment.


# rbxstudio-cli

A feature-rich CLI for launching Roblox Studio with various configurations.

## Installation

### Quick Install

**macOS / Linux:**

```bash
curl -fsSL "https://raw.githubusercontent.com/horsenuggets/rbxstudio-cli/main/Scripts/Install.Unix.sh" | bash
```

**Windows (PowerShell):**

```powershell
iwr "https://raw.githubusercontent.com/horsenuggets/rbxstudio-cli/main/Scripts/install-win.ps1" -useb | iex
```

### Manual Install

1. Download the appropriate binary from the [releases page](https://github.com/horsenuggets/rbxstudio-cli/releases)
2. Run `rbxstudio install` to install to `~/.rbxstudio-cli/bin` and add to PATH

## Commands

### start

Launch Roblox Studio.

```bash
rbxstudio start [flags]
```

| Flag          | Description                             |
| ------------- | --------------------------------------- |
| `--noplugins` | Disable loading user plugins on startup |
| `--reset`     | Reset Studio layout and dock settings   |

### open

Open a place file or published place by ID.

```bash
rbxstudio open <target> [flags]
```

| Short | Long          | Description                                    |
| ----- | ------------- | ---------------------------------------------- |
|       | `--noplugins` | Disable loading user plugins on startup        |
| `-v`  | `--version`   | Open a specific place version (revision)       |
| `-s`  | `--script`    | Script path to open (require-by-string format) |
| `-l`  | `--line`      | Line number to navigate to in the script       |

### new

Create a new temporary place and open it in Studio.

```bash
rbxstudio new [name] [flags]
```

| Flag          | Description                             |
| ------------- | --------------------------------------- |
| `--noplugins` | Disable loading user plugins on startup |

### list

List all running Roblox Studio processes.

```bash
rbxstudio list
```

### kill

Kill Roblox Studio processes.

```bash
rbxstudio kill [pid|all]
```

### api

Dump the Luau scripting API as JSON.

```bash
rbxstudio api [output] [flags]
```

| Short | Long      | Description                                    |
| ----- | --------- | ---------------------------------------------- |
| `-f`  | `--force` | Overwrite the output file if it already exists |

### install

Install rbxstudio CLI globally.

```bash
rbxstudio install
```

### update

Update rbxstudio CLI to the latest version.

```bash
rbxstudio update [flags]
```

| Long        | Description                |
| ----------- | -------------------------- |
| `--version` | Install a specific version |

## Examples

```bash
# Launch Studio
rbxstudio start

# Launch Studio without plugins
rbxstudio start --noplugins

# Open a place file
rbxstudio open MyPlace.rbxl

# Open a published place by ID
rbxstudio open 123456789

# Open a specific version of a place
rbxstudio open 123456789 --version 42

# Open a place and navigate to a script
rbxstudio open 123456789 --script "@game/ServerScriptService/Main" --line 10

# Create a new temporary place
rbxstudio new

# Create a named temporary place
rbxstudio new my-test-place

# List running Studio processes
rbxstudio list

# Kill all Studio processes
rbxstudio kill all

# Dump the scripting API
rbxstudio api

# Self-update to latest version
rbxstudio update
```

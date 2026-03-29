# Clockify Quick Switch

A blazing-fast, DevOps-friendly shell script to automate [Clockify](https://clockify.me/) time tracking context switching.

Stop wrestling with browser tabs in the middle of a troubleshooting session. Instantly transition your timesheet tracking to your current project using your terminal, shell aliases, or global OS hotkeys.

## Why this exists

As engineers balancing multiple projects, the friction of manually tracking time leads to inaccurate timesheets. This script:

- Instantly stops whatever timer is currently running.
- Fuzzy-searches your Clockify workspace for the right project.
- Starts a new timer automatically.
- Caches your Workspace and User IDs for `< 1 sec` execution times.

## Prerequisites

- `curl`
- `jq` (JSON processor)

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

## Installation

1. Clone this repository:

```bash
git clone https://github.com/HussainTechSavvy/clockify-quick-switch.git
cd clockify-quick-switch
```

1. Make the script executable:

```bash
chmod +x clockify_switch.sh
```

1. Copy the example configuration and insert your API Key (Generated from Clockify -> Profile Settings -> API):

```bash
cp .clockify_config.example .clockify_config
```

Edit `.clockify_config` to contain your key:

```bash
export CLOCKIFY_API_KEY='your_api_key_here'
```

## Usage

### 1. Direct Terminal Usage

Run the script with your project name (no exact match needed, it uses case-insensitive fuzzy matching) and an optional task description.

```bash
# Switch to the "Infrastructure Team" project
./clockify_switch.sh "infra" "Debugging database latency"
```

To stop the current timer, run it with no project argument:

```bash
./clockify_switch.sh ""
```

### 2. Shell Aliases (`.zshrc` or `.bashrc`)

To make it completely seamless, add a custom wrapper and aliases to your shell config file.

```bash
# Append to ~/.zshrc or ~/.bashrc
track() {
    /path/to/clockify-quick-switch/clockify_switch.sh "$1" "$2"
}

alias c-stop="track ''"
alias c-infra="track 'infrastructure'"
alias c-client="track 'client name'"
```

Now, you simply type `c-infra` anywhere in your terminal.

### 3. Global Desktop Hotkeys (GNOME / KDE)

Bind your most common projects directly to keyboard shortcuts so you can switch your timer without even launching a terminal window.

1. Open your Desktop Environment Keyboard Settings.
2. Add a Custom Shortcut.
3. Name: `Clockify: Project 1`
4. Command: `/path/to/clockify-quick-switch/clockify_switch.sh "project 1"`
5. Bind it to something like `Super + 1`.

## Security

This script keeps your `CLOCKIFY_API_KEY` stored inside `.clockify_config`, which is explicitly ignored in `.gitignore`. **NEVER** commit your `.clockify_config` file publically.

## License

MIT License

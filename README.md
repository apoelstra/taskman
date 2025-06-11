# Taskman

A Pomodoro-style task tracking system that uses `jj` (Jujutsu) version control to store time blocks and tasks in commit messages. Each 25-minute work block is tracked as a commit with JSON data containing tasks, timestamps, and pause information.

I maintain a git repository for tracking my time in 25-minute blocks. Each commit has empty contents (or rather, updates to my todo list or working notes, which usually have an empty diff) and its description has a structured list of everything I did during that 25-minute block.

This is a standard "pomodoro timer" technique based loosely on David Cain's book ["How To Do Things"](https://www.raptitude.com/2021/11/how-to-do-things/).

## Overview

Taskman helps you track focused work sessions by:
- Creating 25-minute time blocks stored as `jj` commits
- Recording tasks worked on during each block
- Tracking pauses and breaks
- Providing summaries and statistics across multiple blocks
- Integrating with desktop environments through rofi and xmobar

## Tools

### `taskman` - Core CLI Tool

The main command-line interface for managing time blocks and tasks. All output is in JSON format.

**Key commands:**
- `taskman start` - Begin a new 25-minute block
- `taskman task-start "description"` - Start working on a specific task
- `taskman pause` / `taskman unpause` - Pause/resume the current block
- `taskman status` - Show current block status
- `taskman summary [revset]` - Show summary of blocks (defaults to last 7 days)
- `taskman cancel` - Cancel the current block
- `taskman restart` - Cancel current block and start a new one

### `rofi-taskman` - GUI Interface

A rofi-based graphical interface that provides point-and-click access to taskman functionality. Shows different menu options based on current state (no block, active block, paused block).

**Features:**
- Context-sensitive menus
- Task autocomplete from previous sessions
- Copy status/summary to clipboard
- Error logging to `~/.config/taskman/errors.log`

### `taskman-xmobar` - Status Bar Integration

A Python script that displays current block status in xmobar or similar status bars. Updates every 0.25 seconds.

**Display format:** `[weekly total] | [current block time] | [current task]`

**Features:**
- Color-coded time remaining (green → yellow → red)
- Flashing yellow in final 10 seconds
- 8-minute cooldown period after block completion
- Weekly time totals
- Pause/active state indicators

## Setup

### 1. Configuration

Create `~/.config/taskman/config.json`:

```json
{
  "block_duration": 1500,
  "repo_path": "$HOME/code/taskman-blocks",
  "summary_revset": "all() & committer_date(after:\"7 days ago\")",
  "timezone": "local"
}
```

### 2. Repository Setup

Create and initialize the jj repository:

```bash
mkdir -p ~/code/taskman-blocks
cd ~/code/taskman-blocks
jj git init --git-repo .
```

### 3. Tool Installation

Place the scripts in your `$PATH` (e.g., `~/bin/`) and make them executable:

```bash
chmod +x ~/bin/taskman ~/bin/rofi-taskman ~/bin/taskman-xmobar
```

## Dependencies

- `jj` (Jujutsu version control)
- `jq` (JSON processor)
- `bc` (calculator for floating point math)
- `rofi` (for rofi-taskman)
- `xsel` (for clipboard functionality)
- `python3` (for taskman-xmobar)

## Data Storage

All data is stored in `jj` commit messages as JSON. Each block creates a commit with:
- Block metadata (start time, duration, block number)
- Task list with descriptions and timestamps
- Pause periods with start/end times

Block numbers reset daily at midnight (local timezone) and are sequential within each day.

## Time Tracking

- **Active blocks**: Have remaining time > 0
- **Expired blocks**: Remaining time ≤ 0, no longer considered active
- **Paused blocks**: Timer stops, can be resumed
- **Tasks**: Tracked from start time until next task begins or block ends
- **Cooldown**: 8-minute break period after block completion (xmobar only)

## Error Handling

Errors are logged to `~/.config/taskman/errors.log` with ISO 8601 timestamps. The CLI tool outputs JSON error objects, while GUI tools log errors and may exit gracefully.

See `DESIGN.md` for detailed technical specifications.

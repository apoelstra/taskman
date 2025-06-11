# rofi-Based Task Manager

This tool uses `rofi` in dmenu mode to provide a pop-up menu allowing the user to track
tasks done during 25-minute blocks. The blocks are tracked using `jj` and the tasks are
tracked by attaching specially-formatted commit descriptions to these blocks.

## Data Model

Each block tracks the following data in a JSON structure stored in the commit message:

```json
{
  "start_time": "2025-06-11T14:30:00.000Z",
  "duration": 1500,
  "tasks": [
    {
      "description": "Review pull request #123",
      "start_time": "2025-06-11T14:30:00.000Z"
    },
    {
      "description": "Write unit tests",
      "start_time": "2025-06-11T14:45:00.000Z"
    }
  ],
  "pauses": [
    {
      "start_time": "2025-06-11T14:40:00.000Z",
      "end_time": "2025-06-11T14:42:00.000Z"
    }
  ]
}
```

Fields:
* `start_time`: ISO 8601 timestamp in UTC when the block was started
* `duration`: Block duration in seconds (defaults to 1500 = 25 minutes)
* `tasks`: Array of tasks worked on during the block
* `pauses`: Array of pause periods with start and end times (end_time is null for active pauses)

## Time Calculations

All timestamps use UTC except for the daily block numbering reset which occurs at 00:00 in the user's local timezone.

Task durations are calculated from when a task starts until either:
1. The next task starts, or
2. The block ends (either by completion, pause, or cancellation)

When a block is paused, the current task (if any) continues until the pause begins.

## Configuration

The tool uses a configuration file at `$HOME/.config/taskman/config.json`:

```json
{
  "block_duration": 1500,
  "repo_path": "$HOME/code/taskman-blocks",
  "summary_revset": "all() & committers(after:\"7 days ago\")",
  "timezone": "local"
}
```

Fields:
* `block_duration`: Duration of blocks in seconds (default: 1500 = 25 minutes)
* `repo_path`: Path to the jj repository (default: `$HOME/code/taskman-blocks`)
* `summary_revset`: Default jj revset for summary command (default: last 7 days)
* `timezone`: Timezone for daily reset, "local" or IANA timezone name (default: "local")

If this file does not exist, the CLI tool should output an error message explaining how to create it with the default values shown above.

## Error Handling

* CLI tool: If jj commands fail or configuration is invalid, output a JSON error object with `{"error": "description of what failed"}`
* Rofi interface: Log errors to `$HOME/.config/taskman/errors.log` in the format: `[ISO 8601 timestamp] ERROR: description`

Do not attempt retries, automatic fixes, or degraded operation modes.

## CLI User Interface

All CLI output is in JSON format. Commands:

### `summary [revset]`
Outputs summary of blocks matching the revset (defaults to config's `summary_revset`).

Output format:
```json
{
  "blocks": [
    {
      "commit_id": "abc123",
      "block_number": 1,
      "date": "2025-06-11",
      "start_time": "2025-06-11T14:30:00.000Z",
      "duration": 1500,
      "active": true,
      "paused": false,
      "time_remaining": 1200,
      "tasks": [
        {
          "description": "Review pull request #123",
          "start_time": "2025-06-11T14:30:00.000Z",
          "total_duration": 600,
          "switch_count": 1
        }
      ],
      "total_pause_time": 120
    }
  ],
  "aggregate": {
    "total_blocks": 1,
    "total_time": 1500,
    "total_active_time": 1380,
    "total_pause_time": 120,
    "tasks": [
      {
        "description": "Review pull request #123",
        "total_duration": 600,
        "earliest_start": "2025-06-11T14:30:00.000Z",
        "switch_count": 1
      }
    ]
  }
}
```

### `start`
Begins a new block. Fails if a block is currently active.

Implementation:
1. Run `jj new` to create new commit
2. Run `jj describe` with message: "Block N of YYYY-MM-DD\n\n{json_data}"
   - N is sequential within the day (starting from 1 at 00:00 local time)
   - Date is in local timezone
   - json_data is the initial block data structure

### `pause`
Pauses the current active block by adding a pause entry with current timestamp.

### `unpause`
Unpauses the current block by setting the end_time of the most recent pause.

### `cancel`
Cancels the current block using `jj abandon @`.

### `restart`
Equivalent to `cancel` followed by `start`.

### `status`
Equivalent to `summary @` (summary of current/most recent block).

### `task-start <description>`
Begins a new task in the current active block. Fails if no block is active or if block is paused.

## Rofi User Interface

The rofi interface is implemented as a separate script that calls the CLI tool and uses `jq` to parse JSON output.

### When no block is active:
* `start` - calls CLI `start`
* `copy-status` - calls CLI `status` and pipes output to `xsel -b`
* `copy-summary` - calls CLI `summary` and pipes output to `xsel -b`

### When block is active and not paused:
* `task-start` - shows second rofi menu with:
  - All unique task descriptions from `summary` output as autocomplete options
  - User can type new description or select existing one
  - Calls CLI `task-start <description>`
* `pause` - calls CLI `pause`
* `cancel` - calls CLI `cancel`
* `restart` - calls CLI `restart`
* `copy-status` - calls CLI `status` and pipes output to `xsel -b`
* `copy-summary` - calls CLI `summary` and pipes output to `xsel -b`

### When block is paused:
* `unpause` - calls CLI `unpause`
* `cancel` - calls CLI `cancel`
* `copy-status` - calls CLI `status` and pipes output to `xsel -b`

## Block Numbering

Blocks are numbered sequentially within each day, starting from 1. The day boundary is determined by 00:00 in the user's local timezone (or the timezone specified in config). Block numbers reset to 1 at the start of each new day.

The commit message format is: "Block N of YYYY-MM-DD" where the date is in the local timezone.

## Task Aggregation

When multiple tasks have identical descriptions (either within a single block or across multiple blocks in a summary), they are aggregated:
* `total_duration`: Sum of all durations for that task
* `earliest_start`: Earliest start time across all instances
* `switch_count`: Number of times the task was started (i.e., number of task instances)




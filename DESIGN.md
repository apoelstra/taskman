# rofi-Based Task Manager

This tool uses `rofi` in dmenu mode to provide a pop-up menu allowing the user to track
tasks done during 25-minute blocks. The blocks are tracked using `jj` and the tasks are
tracked by attaching specially-formatted commit descriptions to these blocks.

Each block traks the following data:

* The total time of the block (which is set to 25 minutes at the start of the block,
  though this value may be configured).
* A list of tasks that were completed or worked on during the block, along with a
  timestamp of when they were started.
* The timestamp when the block was started.
* A list of timestamps when the block was paused, along with the pause duration if
  the block has since been un-paused.

From this data, it is possible to look at the latest block and determine:

* Whether the block is currently paused and for how long.
* How many times the block has been paused and for how long.
* What tasks were worked on and for how long.
* Whether the block is currently active and how much time is remaining.

To compute the currently-remaining time, the software simply compares the current time
to the start time of the block, subtracting the total pause lengths (if the block is
currently paused this is treated as a pause that ends at the current time).

The location of the repo is configurable but defaults to

# Configuration

The tool uses a configuration file at $HOME/.config/taskman/config.json which specifies

* The duration of blocks (defaults to 25 minutes)
* The location of the `jj` repo to add blocks to.
* The default "summary revset" which by default contains all blocks since 00:00 on
  the most recent Monday. (Or, if that is too difficult to implement, all blocks
  in the last 168 hours.)

If this file does not exist, the software should offer to create it with sensible
defaults, and tell the user how to edit it.

# CLI User Interface

The CLI interface exposes the following commands:

* `summary` takes a jj revset and outputs a summary of all the individual blocks in
  the revset, as well as an aggregate combination of all the blocks' data (total number
  of tasks done, total time, total number of blocks, etc). If two tiasks in different
  blocks are the same they should be combined in the aggregate. All output is in JSON.
  The output should include a boolean `active` which indicates whether the block's 25
  minutes are up.

  If no revset is specified it uses the "summary revset" specified in the configuration
  file.
* `start` begins a new block. If a block is currently in progress then this yields an
  error and `restart` must be used. (When accessed through the rofi menu it is simply
  not available.) This is implemented simply as `jj new` followed by `jj describe`
  setting the first line of the commit message to "Block N of <date>" and the remainder
  of the commit message to a pretty-printed JSON blob containing the data of the block.
* `pause` pauses the block.
* `cancel` cancels the current block (by abandoning its jj commit)
* `restart` is the same as `cancel` followed by `start`.
* `status` is the same as `summary @`, i.e. it gives a summary of the current or most
  recent block.
* `task-start` begins a new task and takes a text description of the block.

In the CLI interface all output should be in JSON.

# Rofi User Interface

Separately there is a user interface based on `rofi -dmenu` which acts as follows:

When invoked, it gives the user a list of actions. If no block is currently active, these
actions are:

* `start` which simply starts a new block.
* `copy-status` which outputs the output of status into the clipboard using `xsel`
* `copy-summary` which outputs the output of summary into the clipboard using `xsel`

If a block is currently active, the actions are:

* `task-start` leads to a second rofi menu to type an action (all tasks in the
  output of `summary` should be shown as menu options to help rofi autocomplete them
  in case the user is continuing)
* `pause` pauses the current block with no further output.
* `cancel` cancels the current block with no further output.
* `restart` restarts the current block with no further output.
* `copy-status` which outputs the output of status into the clipboard using `xsel`
* `copy-summary` which outputs the output of summary into the clipboard using `xsel`

Note that because rofi does not have a sensible place to put output, we replace the
output commands with ones that use `xsel` to put stuff into the X buffer.




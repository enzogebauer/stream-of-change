# Stream of change

A native macOS Pomodoro timer and task list, written in SwiftUI. It works fully offline.

> Everything flows, and through our work we become the people we will be.
> (after Heraclitus of Ephesus)

## Features

- **Pomodoro timer** with Focus, Short break and Long break modes.
- **Editable durations.** Type the minutes directly (defaults: 25 / 5 / 15). Restore the defaults with one click.
- **Tasks with subtasks**, each with a planned number of pomodoros (`spent/estimate`).
- **Summary:** pomodoros left, time needed, and the time you should be done, based on the current time. A long break comes after every 4th focus session.
- **Offline:** tasks are stored locally in `~/Library/Application Support/StreamOfChange/tasks.json`.

## Requirements

- macOS 13 or newer
- Xcode command line tools (`xcode-select --install`)

## Build

```sh
./build.sh
```

This builds the app and puts **Stream of change.app** on your Desktop.

## Project layout

```
Sources/
  StreamOfChangeApp.swift   app entry point
  ContentView.swift         timer and task views
  PomodoroTimer.swift      timer logic and durations
  Models.swift              tasks and storage
  Planner.swift             time estimates
Resources/
  logo.svg / logo.png       the logo
  Info.plist
LICENSE
build.sh
```

## License

MIT. See [LICENSE](LICENSE).

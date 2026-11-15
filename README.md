# Stream of change

A native macOS Pomodoro timer and task manager, written in SwiftUI. It works fully offline, in a light black-and-white look that follows macOS conventions.

> Everything flows, and through our work we become the people we will be.
> (after Heraclitus of Ephesus)

## Features

- **Timer** with Focus, Short break and Long break modes. Durations are editable (defaults: 25 / 5 / 15 minutes). A long break comes after every 4th focus session, and the app plays a sound and bounces the Dock icon when it ends.
- **Rivers instead of pomodoros.** One river is one focus block. Click the wave icon on any task or subtask to open a popover and set its size either in rivers or in hours, minutes and seconds. The two convert into each other automatically.
- **Tasks and subtasks.** A parent shows the sum of its subtasks. Setting a parent splits its rivers evenly across the subtasks.
- **Today and Backlog.** Only Today counts towards the summary. Drag the handle on a task to reorder it or move it between sections.
- **Summary:** rivers left, time needed (with breaks), and when you should be done, based on the current time.
- **Focus mode:** full screen with only the big timer, the estimate and your next few tasks. Press Esc to leave.
- **Done log:** finished tasks grouped by day, with counts for today and this week and the total rivers logged.
- **Menu bar item** with the remaining time, plus start, pause, reset and mode controls.
- **Edit JSON:** edit all tasks as JSON in a separate window, for example with an AI assistant. Fields: `id`, `title`, `isDone`, `parentID`, `estimate`, `spent` (both in rivers, decimals allowed), `isBacklog`, `completedAt`.
- **Daily quote** from a built-in collection of philosophy, science, computing and literature, changing at midnight.
- **Local storage:** tasks live in `~/Library/Application Support/StreamOfChange/tasks.json`, settings in the app's preferences. Nothing is sent anywhere.

## Requirements

- macOS 13 or newer
- Xcode command line tools (`xcode-select --install`)

## Build

```sh
./build.sh
```

This builds the app and installs **Stream of change.app** in `/Applications`. Run it with `open "/Applications/Stream of change.app"`.

## Project layout

```
Sources/
  StreamOfChangeApp.swift   app entry point, windows and menu bar item
  ContentView.swift         timer panel, task list, Done log
  RiverEditor.swift         river icon and the popover to set rivers or time
  FocusView.swift           full-screen focus mode
  PomodoroTimer.swift       timer logic and durations
  Models.swift              tasks, storage and river maths
  Planner.swift             time estimates
  DailyQuote.swift          the daily quote
  JSONEditorView.swift      JSON editing window
  MenuBarView.swift         menu bar item
Resources/
  logo.svg / logo.png       the logo
  Info.plist
LICENSE
build.sh
```

## License

MIT. See [LICENSE](LICENSE).

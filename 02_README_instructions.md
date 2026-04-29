# README / Instructions

## VR Backrooms Spatial Memory Prototype

## 1. Project Overview

This APK is a VR spatial memory prototype built for Meta Quest. The user starts from a fixed Home area, explores a backrooms-style maze, and tries to return to Home under different navigation support conditions.

The project compares three conditions:

1. No system guidance and no manual markers
2. System guidance ON and no manual markers
3. System guidance OFF and manual markers allowed

The APK records each completed trial in a CSV log for later analysis.

## 2. APK Setup

1. Install the APK on a Meta Quest headset.
2. Open the app named **Tao-project**.
3. The user will begin inside the VR maze at the Home area.
4. Make sure the participant understands the controls before starting the test.

## 3. Trial Flow

Each participant completes three trials in the fixed order listed above.

For each trial:

1. The participant starts from Home.
2. The timer starts after the participant leaves Home.
3. The participant explores the maze.
4. When the timer ends, the overhead display tells the participant to return to Home.
5. The participant tries to return to Home.
6. When the participant reaches Home, the trial is completed.
7. The system resets for the next trial.

After each completed trial, old markers are cleared, marker count is reset, and the next trial is recorded as a new row in the CSV log.

## 4. Controls

| Action                       | Control              |
| ---------------------------- | -------------------- |
| Move                         | Left joystick        |
| Turn                         | Right joystick       |
| Toggle system guidance arrow | B button             |
| Preview marker placement     | Hold left trigger    |
| Place marker                 | Release left trigger |
| Interact with optional ball  | A button             |

## 5. System Guidance

The system guidance arrow points back toward the Home area.

* In Trial 1, system guidance should remain OFF.
* In Trial 2, system guidance should be ON.
* In Trial 3, system guidance should remain OFF.

The B button toggles the guidance arrow on or off.

## 6. Manual Markers

Manual markers are only allowed in Trial 3.

The participant can place markers to remember the route back to Home.

Each trial has a limit of **12 markers**. The overhead display shows how many markers remain. When all 12 markers are used, no more markers can be placed until the next trial reset.

## 7. Optional Pickup Balls

Small balls may appear in the environment.

The participant can press **A** to interact with them. These balls are only for interaction and engagement. They are not part of the score and are not used in the main result analysis.

## 8. Log File

The APK saves a CSV log automatically on the Quest.

Log folder:

```text
Internal shared storage/Documents/tao-project/
```

Each completed trial is saved as one row in the CSV file.

The log records key information such as:

* trial index
* system guidance status
* number of markers used
* return time
* completion status

After each participant finishes all three trials, copy the CSV file from the Quest to the computer and rename it using this format:

```text
YYYYMMDD_ParticipantName_log.csv
```

Example:

```text
20260428_AnXingyu_log.csv
```

Keep each participant's log file separate.

## 9. Safety and Testing Rules

* Each trial starts from Home.
* Do not give navigation hints during the trial.
* Stop the test immediately if the participant feels uncomfortable or dizzy.
* If the participant gets lost in Trial 1, the proctor may help them return to Home.
* For Trial 2 and Trial 3, let the participant use the available support method unless they ask to stop or clearly need assistance.

## 10. Materials Included

This Checkpoint 2 submission includes:

* current APK or GitHub link to the APK
* one-page Checkpoint 2 status report
* this README / instruction file
* sample CSV log
* screenshots, if available

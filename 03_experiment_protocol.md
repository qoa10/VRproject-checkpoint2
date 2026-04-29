# Experiment Protocol

## VR Backrooms Spatial Memory Prototype

## 1. Purpose

This protocol explains how to run the pilot test for the VR Backrooms Spatial Memory Prototype. The goal is to compare how different navigation support conditions affect a participant's ability to return to a fixed Home location in a confusing VR maze.

## 2. Participant Task

Each participant starts from the Home area, explores the maze, and then tries to return to Home. The timer starts after the participant leaves Home. When the countdown ends, the participant should return to Home as quickly as possible.

The participant should not receive navigation hints during the trial unless safety assistance is needed.

## 3. Test Conditions

Each participant completes three trials in this fixed order:

1. **No system guidance + no manual markers**
2. **System guidance ON + no manual markers**
3. **System guidance OFF + manual markers allowed**

The order is fixed so that all participants experience the same testing sequence.

## 4. Trial 1: No Guidance / No Markers

* System guidance: OFF
* Manual markers: NOT allowed
* Participant must rely on memory only
* This condition is expected to be the most difficult

If the participant cannot return or says they are lost, the proctor may help them return to Home.

## 5. Trial 2: System Guidance ON

* System guidance: ON
* Manual markers: NOT allowed
* Participant may use the system arrow to return to Home

The proctor should not provide additional navigation hints.

## 6. Trial 3: Manual Markers Allowed

* System guidance: OFF
* Manual markers: allowed
* Participant may place markers to remember the route back to Home
* Maximum markers per trial: 12

The overhead display shows the remaining marker count. After all 12 markers are used, no more markers can be placed until the next reset.

## 7. Controls

| Action                       | Control              |
| ---------------------------- | -------------------- |
| Move                         | Left joystick        |
| Turn                         | Right joystick       |
| Toggle system guidance arrow | B button             |
| Preview marker placement     | Hold left trigger    |
| Place marker                 | Release left trigger |
| Interact with optional ball  | A button             |

## 8. Proctor Instructions

Before the test, tell the participant:

"You will start from the Home area. After you leave Home, a 60-second countdown will start. During the 60 seconds, you can freely explore the maze. When the time ends, try to return to Home as quickly as possible."

For Trial 3, also tell the participant:

"In this trial, you can place your own markers to help remember the route back to Home. You have 12 markers available."

During the test:

* Make sure each trial starts from Home.
* Do not give navigation hints during the trial.
* Watch for discomfort, dizziness, or confusion.
* Stop the test immediately if the participant feels uncomfortable.
* After the participant returns to Home, allow the system to reset before starting the next trial.

## 9. Data to Save

After each participant finishes all three trials, save the CSV log file from:

```text
Internal shared storage/Documents/tao-project/
```

Rename the file using this format:

```text
YYYYMMDD_ParticipantName_log.csv
```

Example:

```text
20260428_AnXingyu_log.csv
```

Keep each participant's log file separate.

## 10. Notes to Record

For each participant, record:

* Participant name
* Date
* Whether each trial was completed
* Whether the participant needed help
* Whether markers were used in Trial 3
* Any confusion, getting lost, dizziness, or technical problems

## 11. Post-Test Questions

After all three trials, ask:

1. Which condition helped you return to Home most easily?
2. What was the difference between the system arrow and your own markers?
3. Which condition felt more comfortable?
4. Did you feel lost in any trial?
5. Do you have any suggestions for improvement?

## 12. Safety Rule

Participant comfort has priority over data collection. If the participant feels dizzy, uncomfortable, or asks to stop, end the test immediately.

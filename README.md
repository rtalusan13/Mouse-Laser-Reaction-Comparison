# Sound Localization Analysis Suite

**For researchers with no programming background.**  
Read this top to bottom once before running anything. It takes about 10 minutes.

---

## What this software does

You run behavioral experiments where a mouse hears a sound and licks for water. Some trials use a laser, some do not. This software takes the raw data files that LabVIEW records and automatically calculates:

- **Accuracy** — how often the animal licked correctly on laser vs. non-laser trials
- **Omissions** — how often the animal did not respond in time
- **Latency** — how quickly the animal licked after the sound

Results are saved to a spreadsheet and a graphical app lets you explore them interactively.

---

## File overview (what you will work with)

| File | What you do with it |
|------|-------------------|
| `Setup_Global_Paths.m` | Run **once** on each computer to configure folder locations |
| `Batch_Processing.m` | Run **after each session** to process new data files |
| `SoundLocalizationGUI.m` | Open the **graphical app** to explore results |
| `Function_LaserAnalysis.m` | Do not open — runs automatically |

---

## Step 1 — Requirements

### MATLAB version
- **MATLAB R2022b or newer** is required.  
  To check your version: type `ver` in the MATLAB Command Window. The first line shows your version.

### Required Toolboxes
You need these two toolboxes installed. To check, go to **Home → Add-Ons → Manage Add-Ons** and look for them in your installed list.

| Toolbox | Why it is needed |
|---------|-----------------|
| **Statistics and Machine Learning Toolbox** | Required for `ttest`, `anova1`, `prctile`, `boxplot` in the GUI |
| **MATLAB App Designer** | Built into MATLAB R2022b+ — no separate install needed |

If a toolbox is missing, go to **Home → Add-Ons → Get Add-Ons** and search for it by name.

### TDTMatlabSDK (optional)
The current pipeline does **not** require the TDT SDK. Raw LabVIEW files are read directly using MATLAB's built-in `readtable`. If a future version adds TDT tank support, install the SDK from:  
`https://www.tdt.com/docs/sdk/offline-data-analysis/offline-data-matlab/`  
and add its folder to your MATLAB path using `Setup_Global_Paths.m`.

---

## Step 2 — Folder structure

Before running anything, organize your files like this:

```
MyExperiment/
├── labview_copy/               ← put ALL raw LabVIEW files here
│   ├── 12312025-121753-1034    ← one file per session, no extension
│   ├── 01072026-093245-1034
│   └── ...
├── Batch_Processing.m
├── Function_LaserAnalysis.m
├── Setup_Global_Paths.m
└── SoundLocalizationGUI.m
```

**Important:** Raw LabVIEW files have no file extension (no `.csv`, no `.txt`). They must stay that way. Do not rename them or add extensions.

---

## Step 3 — One-time setup (run once per computer)

1. Open MATLAB
2. In the MATLAB toolbar, click the folder icon to navigate to your `MyExperiment/` folder
3. Open `Setup_Global_Paths.m`
4. Edit the one line that says `DATA_ROOT = 'C:\your\path\here'` and replace the path with your actual folder path
5. Press **F5** (or click Run)
6. You should see: `Setup complete. Paths saved.`

You only need to do this once. After that, MATLAB remembers the paths.

---

## Step 4 — Processing your data

After each recording session, or when you want to update results:

1. Make sure your new LabVIEW files are inside the `labview_copy/` folder
2. Open `Batch_Processing.m`
3. Press **F5** (or click Run)
4. Watch the Command Window — it prints one line per file processed
5. When finished, two files are created in your experiment folder:
   - `Batch_Analysis_Results.xlsx` — open this in Excel to see your data
   - `Batch_Analysis_Results_Snapshot.mat` — used by the GUI (do not delete)

---

## Step 5 — Opening the graphical app

1. In the MATLAB Command Window, type:
   ```matlab
   app = SoundLocalizationGUI;
   ```
   and press Enter.
2. The app window opens.
3. Click **Load Snapshot** and select `Batch_Analysis_Results_Snapshot.mat`.
4. Your data loads and the Dashboard fills in automatically.

---

## Hardware-to-software column mapping

This section explains how the numbers in your LabVIEW files connect to what the code calculates. You only need to read this if your rig is configured differently from the standard setup.

LabVIEW records 13 channels simultaneously. Each column in the data file corresponds to one physical DAQ channel:

| Column | Variable name in code | Physical channel | What it records |
|--------|----------------------|-----------------|-----------------|
| 1 | `timestamps` | Analog input (continuous clock) | Time in seconds since session start |
| 2 | *(not used)* | Digital input | Left lick spout contact |
| 3 | *(not used)* | Digital input | Right lick spout contact |
| 4 | *(not used)* | Digital output | Left water solenoid fired |
| 5 | *(not used)* | Digital output | Right water solenoid fired |
| 6 | `trigger_by_lick` | Digital output | Water was delivered because animal licked (reward event) |
| 7 | `soundonset` | Digital output | Sound stimulus started — marks the beginning of a trial |
| 8 | `trial_num` | Counter | Integer that increments by 1 each new trial |
| 9 | `soundAB` | Digital output | Sound type code: **1 or 2** = Non-Laser trial, **3 or 4** = Laser trial |
| 10 | *(not used)* | Digital output | ITI (inter-trial interval) flag |
| 11 | *(not used)* | Digital output | Free water release (not contingent on licking) |
| 12 | *(not used)* | Digital output | Mistake on left spout |
| 13 | *(not used)* | Digital output | Mistake on right spout |

**If your rig uses different column assignments**, open `Function_LaserAnalysis.m` and change the column numbers at lines 33–38 (the section labeled "Extract columns by index"). The rest of the logic does not need to change.

---

## Troubleshooting matrix

Use this table when something goes wrong. Find your error message or symptom in the left column, then follow the fix.

| Symptom | Most likely cause | Fix |
|---------|-----------------|-----|
| `Batch_Processing.m` prints `No raw files found` | The `labview_copy` folder is empty or named differently | Make sure your LabVIEW files are inside a folder named exactly `labview_copy`. Check spelling and capitalization. |
| A file prints `FAILED: Unable to read file` | The file has an extension (e.g. `.csv`) or is corrupted | Raw LabVIEW files must have no extension. Remove any extension from the filename. |
| `AccuracyLaser` is NaN for some sessions | That session had zero laser trials, or all laser trials were omissions | Normal — check if the laser was actually on during that session. NaN means the denominator was zero. |
| GUI shows `Variable 'T' not found in .mat file` | You selected the wrong .mat file at Load Snapshot | Select the file named `Batch_Analysis_Results_Snapshot.mat`, not any other .mat file. |
| GUI loads but all KPI cards show `—` | Snapshot loaded but filter is set to an animal with no data | Check the Animal filter dropdown in the sidebar. Set it back to `All`. |
| Trial numbers jump unexpectedly in replay | Normal for sessions where ITI was cut short or the rig was reset | Not an error. The replay shows raw data exactly as recorded. |
| `Function not found: ttest` | Statistics and Machine Learning Toolbox is not installed | Go to Home → Add-Ons → Get Add-Ons and install the Statistics toolbox. |
| `Function not found: anova1` | Same as above | Same fix. |
| Date shows as `NaN` in the spreadsheet | Filename does not follow the `MMDDYYYY-HHMMSS-ID` format | The date will fall back to the file's last-modified date. Rename the file to match the standard format for correct dates. |
| Angle and Power columns are all NaN | These are not auto-detected — they must be filled in manually | Open `Batch_Analysis_Results.xlsx`, fill in the Angle and Power columns for each row, then re-run `Batch_Processing.m` — it preserves your entered values. |
| GUI `Re-Sync` button produces fewer records than `Batch_Processing.m` | Some files failed silently inside the GUI | Run `Batch_Processing.m` directly — it prints each failure with a reason. Fix those files, then reload the snapshot. |
| `Error: Cancelled` when running `Batch_Processing.m` | You clicked Cancel on the folder picker dialog | Run the script again and select your `labview_copy` folder, or run `Setup_Global_Paths.m` first so the folder is found automatically. |
| App window opens but is mostly grey / blank | Screen resolution is below 1440×900 | The GUI is designed for a 1440×900 or larger display. Try maximizing the window or running on a larger monitor. |
| `Out of memory` error during Re-Sync | Dataset is very large (500+ sessions) | Run `Batch_Processing.m` as a standalone script instead of using the GUI's Re-Sync button. The standalone script has a smaller memory footprint. |

---

## Glossary

| Term | Plain-English meaning |
|------|--------------------|
| Laser trial | A trial where the laser was on (sound type 3 or 4 in the data) |
| Non-laser trial | A control trial without laser (sound type 1 or 2) |
| Omission | The animal did not lick within 2.775 seconds of the sound |
| Accuracy | Percentage of non-omission trials where the animal got a reward |
| Latency | Average time from sound onset to first rewarded lick |
| Snapshot (.mat) | A fast-loading binary copy of the processed results, used by the GUI |
| IQR outlier | A session where accuracy falls unusually far from the group median |

---

## Contact and support

If you encounter an error not listed above, copy the full red error text from the MATLAB Command Window and share it with your lab's data analyst or the code maintainer.
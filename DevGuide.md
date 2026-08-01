# Developer's Guide to Scaling

**Audience:** Graduate students or research engineers who want to extend this pipeline beyond the current sound localization paradigm.

**Prerequisite:** Read `FILE_DIRECTORY_MANIFESTO.m` and `README.md` first so you understand the existing architecture.

---

## 1. Adapting `Function_LaserAnalysis.m` for a different paradigm

The analysis engine is built around two configurable concepts: **trial classification** (which column defines trial type) and **outcome detection** (how you decide whether an animal responded correctly). Everything else — saving, loading, plotting — does not care about those details.

### How trial classification works now

```matlab
% Column 9 (soundAB) decides trial type:
trial_ind_laser    = trial_ind(soundAB(trial_ind) == 3 | soundAB(trial_ind) == 4);
trial_ind_nonlaser = trial_ind(soundAB(trial_ind) == 1 | soundAB(trial_ind) == 2);
```

The code reads column 9 and splits trials into two groups based on the integer code. The rest of the function counts rewards and omissions separately for each group, then computes accuracy and latency for both.

### Swapping to a different stimulus variable

The pattern is identical regardless of what the stimulus is. The only things you change are:

**1. Which column to read:**

```matlab
% Current: sound type from column 9
STIMULUS_COL = 9;
stimulusCode = datab(:, STIMULUS_COL);

% For visual stimulus (if your rig writes it to column 10):
STIMULUS_COL = 10;
stimulusCode = datab(:, STIMULUS_COL);
```

**2. Which code values define each group:**

```matlab
% Current: Laser = 3 or 4, Non-Laser = 1 or 2
GROUP_A_CODES = [3, 4];   % e.g. laser-on trials
GROUP_B_CODES = [1, 2];   % e.g. laser-off trials

% For optogenetic frequency:
GROUP_A_CODES = [10, 20, 40];   % stimulation frequencies in Hz
GROUP_B_CODES = [0];            % no stimulation

% For visual vs auditory stimulus:
GROUP_A_CODES = [1];   % visual trial
GROUP_B_CODES = [2];   % auditory trial
```

**3. Rename the output fields** to match your paradigm:

```matlab
% Current naming
result.AccuracyLaser    = accuracyGroupA;
result.AccuracyNonLaser = accuracyGroupB;

% Rename for clarity (optional but recommended)
result.AccuracyStimOn  = accuracyGroupA;
result.AccuracyStimOff = accuracyGroupB;
```

The batch script and GUI read output fields by name. If you rename them here, update the field names in `Batch_Processing.m` (the `buildResultRow` function) and in `SoundLocalizationGUI.m` (the column references in `renderDashboard`, `populateRawTable`, and `exportExcel`). There are about 12 field name references total — use MATLAB's Find & Replace (Ctrl+H) to update them all at once.

### Adding a third group

If your paradigm has three conditions (e.g., laser-low, laser-high, no-laser), call `countRewardsAndOmissions` three times with three sets of trial indices, then add three sets of output fields. The GUI's Dashboard KPI cards are configured in a loop of six — you would add two more KPI titles and values in `buildTab1_Dashboard` and `renderDashboard`.

---

## 2. Adding a new visualization tab to the GUI

The GUI sidebar has six nav buttons, one per tab. Each tab is built by a dedicated `buildTab_N` method. Adding a new tab requires four steps.

### Step 1 — Declare the new tab's UI components

In the `properties (Access = private)` block near the top of `SoundLocalizationGUI.m`, add a section for your new tab's components. Follow the existing pattern exactly:

```matlab
% ── Tab 7: Psychometric Curve ─────────────────────────────────────────
Tab7                    matlab.ui.container.Tab
PsychAxes               matlab.ui.control.UIAxes
PsychAnimalDD           matlab.ui.control.DropDown
PsychRenderBtn          matlab.ui.control.Button
```

### Step 2 — Build the tab layout

Add a new method to the `methods (Access = private)` build section:

```matlab
function buildTab7_PsychometricCurve(app)
    app.Tab7 = uitab(app.TabGroup, 'Title', 'Psychometric');
    W = app.TabGroup.Position(3);
    H = app.TabGroup.Position(4) - 30;

    % Animal selector dropdown
    uilabel(app.Tab7, 'Text', 'Animal:', 'Position', [10 H-50 55 22], ...
        'FontWeight', 'bold', 'FontSize', 11);
    app.PsychAnimalDD = uidropdown(app.Tab7, ...
        'Items', {'All'}, 'Position', [68 H-50 110 26]);

    % Render button
    app.PsychRenderBtn = uibutton(app.Tab7, ...
        'Text', 'Plot Curve', 'Position', [200 H-50 110 28], ...
        'BackgroundColor', app.Colors.Accent1, 'FontColor', 'white', ...
        'ButtonPushedFcn', @(~,~) app.renderPsychometric());

    % Axes for the curve
    app.PsychAxes = uiaxes(app.Tab7, ...
        'Position', [10 10 W-20 H-80], ...
        'BackgroundColor', app.Colors.CardBG);
    title(app.PsychAxes, 'Psychometric Curve — Accuracy vs Angle');
    xlabel(app.PsychAxes, 'Angle (°)');
    ylabel(app.PsychAxes, 'Accuracy (%)');
end
```

### Step 3 — Register the tab in `buildUI`

In the `buildUI` method, add one line after the last `buildTab` call:

```matlab
function buildUI(app)
    app.buildFigure();
    app.buildSidebar();
    app.buildStatusBar();
    app.buildWorkspace();
    app.buildFilterPanel();
    app.buildTab1_Dashboard();
    app.buildTab2_RawInspection();
    app.buildTab3_TrendAnalysis();
    app.buildTab4_3DManifold();
    app.buildTab5_Statistics();
    app.buildTab6_TrialReplay();
    app.buildTab7_PsychometricCurve();   % ← add this line
    app.styleAllAxes();
end
```

### Step 4 — Add the nav button

In `buildSidebar`, increase the nav button arrays from 6 to 7 and add the new label:

```matlab
navLabels = {'  Dashboard', '  Raw Data', '  Trend Analysis', ...
             '  3D Manifold', '  Statistics', '  Trial Replay', ...
             '  Psychometric'};    % ← add this
navIcons  = {'📊', '🔬', '📈', '🌐', '📐', '▶', '📉'};  % ← add icon
```

Change `cell(6,1)` to `cell(7,1)` and update the `highlightNav` loop from `1:6` to `1:7`. The tab-switching logic in `onTabChanged` will detect the new tab automatically because it loops over `app.TabGroup.Children`.

### Writing the render function

Add a method called `renderPsychometric` to the rendering section. It follows the same pattern as `renderManifold` — check for data, subset by animal, plot, label axes:

```matlab
function renderPsychometric(app)
    T = app.DC.FilteredTable;
    if isempty(T), return; end

    animal = app.PsychAnimalDD.Value;
    if ~strcmp(animal, 'All')
        T = T(strcmp(string(T.ID), animal), :);
    end

    % Group by angle and compute mean accuracy
    angles     = unique(T.Angle(~isnan(T.Angle)));
    meanAccL   = zeros(numel(angles), 1);
    meanAccNL  = zeros(numel(angles), 1);

    for k = 1:numel(angles)
        subset       = T(T.Angle == angles(k), :);
        meanAccL(k)  = nanmean(subset.AccuracyLaser);
        meanAccNL(k) = nanmean(subset.AccuracyNonLaser);
    end

    ax = app.PsychAxes;
    cla(ax); hold(ax, 'on');
    plot(ax, angles, meanAccL,  '-o', 'Color', app.Colors.Accent1, ...
        'LineWidth', 2, 'DisplayName', 'Laser');
    plot(ax, angles, meanAccNL, '-s', 'Color', app.Colors.Accent2, ...
        'LineWidth', 2, 'DisplayName', 'Non-Laser');
    yline(ax, 50, '--', 'Color', [0.6 0.6 0.6], 'Label', 'Chance');
    legend(ax, 'Location', 'best');
    ylim(ax, [0 105]);
    title(ax, sprintf('Psychometric Curve — %s', animal));
end
```

That is all that is required to add a fully functional new tab.

---

## 3. Scaling the DataSnapshot engine for longitudinal studies

The current snapshot stores everything in a single table `T` inside one `.mat` file. This works well for datasets up to roughly 500 sessions (approximately 5 MB). Beyond that, loading the entire dataset into memory on startup becomes slow and wasteful if the researcher is only looking at one animal.

### Option A — Partitioned .mat files (recommended for most labs)

Split the snapshot by animal ID. Each animal gets its own `.mat` file. The GUI loads only the animals currently selected in the filter.

**Saving partitioned snapshots in `Batch_Processing.m`:**

```matlab
% Replace the single save() call with this:
animalIDs = unique(string(T.ID));
snapshotDir = fullfile(pwd, 'snapshots');
if ~isfolder(snapshotDir), mkdir(snapshotDir); end

for k = 1:numel(animalIDs)
    animalData  = T(strcmp(string(T.ID), animalIDs(k)), :);
    lastUpdated = datetime('now');
    outFile = fullfile(snapshotDir, sprintf('snapshot_%s.mat', animalIDs(k)));
    save(outFile, 'animalData', 'lastUpdated');
end

% Also save a master index file
masterIndex = table(animalIDs', ...
    arrayfun(@(id) fullfile(snapshotDir, sprintf('snapshot_%s.mat', id)), ...
        animalIDs, 'UniformOutput', false)', ...
    'VariableNames', {'ID', 'FilePath'});
save(fullfile(snapshotDir, 'master_index.mat'), 'masterIndex');
```

**Loading in the GUI:** Modify `loadSnapshot` in `SoundLocalizationGUI.m` to detect whether the user selected a `master_index.mat` file, then load only the partitions for the selected animals. Add a second "Load All" button that loads all partitions concatenated. This requires changing approximately 20 lines in the data engine section.

### Option B — Database-lite approach using SQLite

For datasets exceeding 1,000 sessions or multi-year longitudinal studies, consider storing results in an SQLite database. MATLAB does not include a native SQLite driver, but you can use the freely available `mksqlite` MEX library:

`https://github.com/AndreasMartin72/mksqlite`

The schema mirrors the current table exactly:

```sql
CREATE TABLE sessions (
    ID           TEXT,
    Angle        REAL,
    Power        REAL,
    Date         TEXT,
    AccuracyLaser    REAL,
    AccuracyNonLaser REAL,
    OmissionsLaser   INTEGER,
    OmissionsNonLaser INTEGER,
    LaserReward      INTEGER,
    NonLaserReward   INTEGER,
    LaserTrials      INTEGER,
    NonLaserTrials   INTEGER,
    oLaserPercent    REAL,
    oNonLaserPercent REAL,
    LatencyLaser     REAL,
    LatencyNonLaser  REAL
);
```

Replace the `writetable` and `save` calls in `Batch_Processing.m` with `mksqlite` insert calls. In the GUI, replace `load(snapshotPath)` with a `SELECT` query that filters by animal and date range directly in the database, returning only the rows needed for display. This eliminates the in-memory table entirely and makes the GUI responsive for datasets of any size.

---

## 4. Integrating Python-based machine learning for lick-pattern classification

The pipeline can call Python from MATLAB without requiring the researcher to interact with Python directly. The GUI presents results as if they came from a normal MATLAB analysis.

### Setup

Install Python 3.9–3.11 (the range MATLAB R2022b supports). In MATLAB, verify the connection:

```matlab
pyenv('Version', 'C:\Python311\python.exe')   % Windows
pyenv('Version', '/usr/bin/python3')           % Mac/Linux
py.importlib.import_module('numpy');            % test import
```

Install required Python packages from the MATLAB Command Window:

```matlab
system('pip install numpy scipy scikit-learn');
```

### Architecture

Create a Python script `lick_classifier.py` in your project folder that accepts a path to a raw LabVIEW file, loads it with `numpy`, runs a classifier, and prints results as JSON:

```python
# lick_classifier.py
import sys, json, numpy as np
from sklearn.ensemble import RandomForestClassifier

def classify_lick_patterns(filepath):
    data = np.loadtxt(filepath)
    # ... feature extraction and classification logic ...
    result = {'pattern': 'anticipatory', 'confidence': 0.87}
    print(json.dumps(result))

classify_lick_patterns(sys.argv[1])
```

In `Function_LaserAnalysis.m`, call the Python script after the standard analysis and merge the result into the output struct:

```matlab
% At the end of Function_LaserAnalysis, after existing result fields:
try
    pyScript = fullfile(fileparts(mfilename('fullpath')), 'lick_classifier.py');
    [~, jsonOut] = system(sprintf('python "%s" "%s"', pyScript, filename));
    mlResult = jsondecode(jsonOut);
    result.LickPattern   = string(mlResult.pattern);
    result.MLConfidence  = mlResult.confidence;
catch
    result.LickPattern   = "unavailable";
    result.MLConfidence  = NaN;
end
```

Add `LickPattern` and `MLConfidence` to the column order in `buildOutputTable` inside `Batch_Processing.m`. In `SoundLocalizationGUI.m`, add these columns to `populateRawTable`. The researcher sees them as two extra columns in the Raw Inspection tab — no other changes to the UI are needed.

### Keeping the UI simple

The researcher does not need to know Python is running. From their perspective, `Batch_Processing.m` just produces two extra columns in the spreadsheet. If the Python environment is missing or the classifier fails, the `try-catch` above fills those columns with `"unavailable"` and `NaN` so the rest of the pipeline continues normally.

### Integrating external DSP libraries

The same pattern applies to digital signal processing. If you want to compute lick-rate spectrograms using SciPy:

```matlab
% In Function_LaserAnalysis.m
pyResult = py.scipy.signal.periodogram( ...
    py.numpy.array(double(trigger_by_lick)), ...
    pyargs('fs', 1000));   % assuming 1 kHz sampling
frequencies = double(pyResult{1});
power       = double(pyResult{2});
result.DominantLickFrequency = frequencies(power == max(power));
```

This approach requires no wrapper scripts — MATLAB calls Python functions directly and converts the output to standard MATLAB arrays. The GUI can display the dominant lick frequency as a KPI card or a new column in the Raw Inspection table without any further changes to the analysis logic.
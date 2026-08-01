%% Batch_Processing.m
% =========================================================================
% USER-FACING INTERFACE — run this script to process all raw LabView files.
%
% What it does (in plain English):
%   1. Finds the labview_copy folder on your computer
%   2. Loops over every raw data file inside it
%   3. Calls Function_LaserAnalysis on each file to compute accuracy,
%      omissions, and latency
%   4. Saves results to two places:
%        Batch_Analysis_Results.xlsx  — human-readable spreadsheet
%        Batch_Analysis_Results_Snapshot.mat — fast-loading binary for GUI
%
% How to run:
%   Just press F5 (or click Run) while this file is open in MATLAB.
%   A folder-picker dialog appears if the data folder is not found.
%
% Dependencies: Function_LaserAnalysis.m must be in the same folder.
% =========================================================================

clc; clear;

% ── CONFIGURATION (only section you may need to edit) ─────────────────────
TARGET_FOLDER = 'labview_copy';        % name of your raw data folder
OUTPUT_EXCEL  = 'Batch_Analysis_Results.xlsx';
OUTPUT_SHEET  = 'ProcessedResults';
% ──────────────────────────────────────────────────────────────────────────

% Step 1: Locate the data folder
dataDir = findDataFolder(TARGET_FOLDER);

% Step 2: Load any previously processed results so we can update them
existingData = loadExistingResults(OUTPUT_EXCEL, OUTPUT_SHEET);

% Step 3: Find all raw LabView files (files with no extension)
allFiles = dir(fullfile(dataDir, '**', '*'));
allFiles = allFiles(~[allFiles.isdir]);
rawFiles = allFiles(~cellfun(@(n) contains(n,'.'), {allFiles.name}));

if isempty(rawFiles)
    fprintf('No raw files found in: %s\n', dataDir);
    return;
end
fprintf('Found %d raw file(s) to process.\n', numel(rawFiles));

% Step 4: Process each file
resultsList = [];
count       = 0;

for i = 1:numel(rawFiles)
    thisFile = rawFiles(i);
    fullPath = fullfile(thisFile.folder, thisFile.name);

    % Parse animal ID and date from the filename
    [specimenID, isoDate] = parseFilename(thisFile);

    fprintf('Processing %s (ID: %s, Date: %s)... ', thisFile.name, specimenID, isoDate);

    try
        calcData = Function_LaserAnalysis(fullPath);
        row = buildResultRow(specimenID, isoDate, calcData, existingData);
        if isempty(resultsList)
            resultsList = row;
        else
            resultsList(end+1) = row; %#ok<AGROW>
        end

        count = count + 1;
        fprintf('Done.\n');

    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
end

if isempty(resultsList)
    fprintf('No valid data found. Nothing saved.\n');
    return;
end
T = buildOutputTable(resultsList);

% Write only the computed columns (A through N) - never touch O, P, Q (Angle, Power, Visualize)
% These columns contain Excel formulas that we must preserve
try
    writetable(T(:, {'ID'}), OUTPUT_EXCEL, 'Sheet', OUTPUT_SHEET, 'Range', 'A1');
    writetable(T(:, {'Date'}), OUTPUT_EXCEL, 'Sheet', OUTPUT_SHEET, 'Range', 'B1');
    
    % Write only the 12 computed metric columns (C through N)
    metricsBlock = T(:, {'AccuracyLaser', 'AccuracyNonLaser', ...
                         'OmissionsLaser', 'OmissionsNonLaser', ...
                         'LaserReward', 'NonLaserReward', ...
                         'LaserTrials', 'NonLaserTrials', ...
                         'oLaserPercent', 'oNonLaserPercent', ...
                         'LatencyLaser', 'LatencyNonLaser'});
    writetable(metricsBlock, OUTPUT_EXCEL, 'Sheet', OUTPUT_SHEET, 'Range', 'C1');
    
    fprintf('\nExcel updated: ID(A), Date(B), Metrics(C-N). Formula columns (O-Q) preserved.\n');
catch
    warning('Excel write failed. Please CLOSE the file and run again.');
end

[~, baseName] = fileparts(OUTPUT_EXCEL);
snapshotFile  = [baseName '_Snapshot.mat'];
lastUpdated   = datetime('now');
save(snapshotFile, 'T', 'lastUpdated');
fprintf('Snapshot saved: %s\n', snapshotFile);


% =========================================================================
% LOCAL HELPER FUNCTIONS
% These are called by the main script above. You do not need to edit them.
% =========================================================================

function dataDir = findDataFolder(targetName)
    scriptFolder = fileparts(mfilename('fullpath'));

    if isfolder(fullfile(scriptFolder, targetName))
        dataDir = fullfile(scriptFolder, targetName);

    elseif isfolder(fullfile(pwd, targetName))
        dataDir = fullfile(pwd, targetName);

    else
        fprintf('Folder "%s" not found automatically. Please select it.\n', targetName);
        dataDir = uigetdir(scriptFolder, ['Select the ' targetName ' folder']);
        if isequal(dataDir, 0)
            error('No folder selected. Batch processing cancelled.');
        end
    end
    fprintf('Data folder: %s\n', dataDir);
end


function existingData = loadExistingResults(excelPath, sheetName)
% Reads any previously saved results from the Excel file.
% Returns an empty table if the file does not exist yet.

    existingData = table();
    if ~isfile(excelPath)
        return;
    end

    [~, sheets] = xlsfinfo(excelPath);
    if ~ismember(sheetName, sheets)
        return;
    end

    try
        opts = detectImportOptions(excelPath, 'Sheet', sheetName);
        opts.VariableNamingRule = 'preserve';
        opts = setvartype(opts, {'ID','Date'}, 'string');
        existingData = readtable(excelPath, opts);
        fprintf('Loaded %d existing records from %s.\n', height(existingData), excelPath);
    catch
        warning('Could not read existing results. Starting fresh.');
    end
end


function [specimenID, isoDate] = parseFilename(fileInfo)
% Extracts animal ID and recording date from the filename.
%
% Expected filename format: MMDDYYYY-HHMMSS-AnimalID
% Example: 12312025-121753-1034  →  ID=1034, Date=2025-12-31
%
% If the filename does not match this pattern, the parent folder name
% is used as the ID and the file modification date is used.

    parts = split(fileInfo.name, '-');

    if numel(parts) >= 3
        specimenID = string(parts{end});
        rawDate    = parts{1};
        if numel(rawDate) == 8
            % Reformat MMDDYYYY → YYYY-MM-DD
            isoDate = string([rawDate(5:8) '-' rawDate(1:2) '-' rawDate(3:4)]);
        else
            isoDate = string(rawDate);
        end
    else
        % Fallback: use folder name as ID, file date as date
        [~, specimenID] = fileparts(fileInfo.folder);
        specimenID = string(specimenID);
        isoDate    = string(datestr(fileInfo.datenum, 'yyyy-mm-dd'));
    end
end


function row = buildResultRow(specimenID, isoDate, calcData, existingData)
    row = struct();
    row.ID    = specimenID;
    row.Date  = isoDate;

    % Computed metrics from Function_LaserAnalysis
    % Note: Angle, Power, and Visualize are NOT included here
    % They are managed by Excel formulas in columns O, P, Q
    row.AccuracyLaser    = calcData.AccuracyLaser;
    row.AccuracyNonLaser = calcData.AccuracyNonLaser;
    row.OmissionsLaser   = calcData.OmissionsLaser;
    row.OmissionsNonLaser= calcData.OmissionsNonLaser;
    row.LaserReward      = calcData.LaserReward;
    row.NonLaserReward   = calcData.NonLaserReward;
    row.LaserTrials      = calcData.LaserTrials;
    row.NonLaserTrials   = calcData.NonLaserTrials;
    row.oLaserPercent    = calcData.oLaserPercent;
    row.oNonLaserPercent = calcData.oNonLaserPercent;
    row.LatencyLaser     = calcData.LatencyLaser;
    row.LatencyNonLaser  = calcData.LatencyNonLaser;
end


function T = buildOutputTable(resultsList)
% Converts the struct array into a table with a fixed, predictable
% column order. Only includes columns computed by MATLAB.
% Angle, Power, and Visualize are managed by Excel formulas.

    T = struct2table(resultsList);

    % Order for MATLAB-computed columns only (A through N in Excel)
    desiredOrder = { ...
        'ID', 'Date', ...
        'AccuracyLaser', 'AccuracyNonLaser', ...
        'OmissionsLaser', 'OmissionsNonLaser', ...
        'LaserReward', 'NonLaserReward', ...
        'LaserTrials', 'NonLaserTrials', ...
        'oLaserPercent', 'oNonLaserPercent', ...
        'LatencyLaser', 'LatencyNonLaser' ...
    };

    % Only reorder columns that actually exist
    presentCols = intersect(desiredOrder, T.Properties.VariableNames, 'stable');
    T = movevars(T, presentCols, 'Before', 1);
    T = sortrows(T, {'ID', 'Date'});
end
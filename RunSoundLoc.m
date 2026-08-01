%% RunSoundLoc.m
% =========================================================================
% MAIN LAUNCHER — Single-click workflow for the Sound Localization system
%
% What it does:
%   1. Finds your labview_copy folder automatically.
%   2. Processes new raw data (Batch_Processing logic).
%   3. Pulls your Excel formula results (Angle/Power) into the GUI snapshot.
%   4. Launches the SoundLocalizationGUI with all data synchronized.
% =========================================================================

function RunSoundLoc()
    clc;
    fprintf('\n');   
    fprintf('╔════════════════════════════════════════════════════════════════╗\n');
    fprintf('║        Sound Localization Analysis System — Quick Launch       ║\n');
    fprintf('╚════════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');

    % ── Step 1: Environment Setup ─────────────────────────────────────────
    scriptFolder = fileparts(mfilename('fullpath'));
    addpath(scriptFolder);
    
    OUTPUT_EXCEL   = fullfile(scriptFolder, 'Batch_Analysis_Results.xlsx');
    OUTPUT_SHEET   = 'ProcessedResults';
    snapshotFile   = fullfile(scriptFolder, 'Batch_Analysis_Results_Snapshot.mat');
    TARGET_FOLDER  = 'labview_copy';

    % ── Step 2: Find Data Folder ──────────────────────────────────────────
    dataDir = findDataFolder(TARGET_FOLDER, scriptFolder);

    % ── Step 3: Process Raw Data ──────────────────────────────────────────
    fprintf('STEP 2: Processing raw data files...\n');
    try
        processAndSave(dataDir, OUTPUT_EXCEL, OUTPUT_SHEET, snapshotFile);
    catch ME
        fprintf('\n✗ ERROR during processing: %s\n', ME.message);
        return;
    end

    % ── Step 4: Sync Excel Formulas to GUI Snapshot ───────────────────────
    fprintf('\nSTEP 3: Pulling formula results from Excel to GUI...\n');
    try
        syncExcelToSnapshot(OUTPUT_EXCEL, OUTPUT_SHEET, snapshotFile);
    catch ME
        fprintf('  ⚠ Warning: Excel sync failed: %s\n', ME.message);
    end

    % ── Step 5: Launch GUI ────────────────────────────────────────────────
    fprintf('\nSTEP 4: Launching GUI...\n');
    if isfile(snapshotFile)
        try
            app = SoundLocalizationGUI(snapshotFile); %#ok<NASGU>
            fprintf('✓ GUI launched successfully.\n\n');
        catch ME
            fprintf('✗ ERROR launching GUI: %s\n', ME.message);
        end
    else
        fprintf('✗ ERROR: Snapshot file not found.\n');
    end
end

% =========================================================================
% HELPER: DATA FOLDER DISCOVERY
% =========================================================================
function dataDir = findDataFolder(targetName, startDir)
    if isfolder(fullfile(startDir, targetName))
        dataDir = fullfile(startDir, targetName);
    elseif isfolder(fullfile(pwd, targetName))
        dataDir = fullfile(pwd, targetName);
    else
        fprintf('"%s" not found. Please select it manually.\n', targetName);
        dataDir = uigetdir(startDir, ['Select your ' targetName ' folder']);
        if isequal(dataDir, 0), error('No folder selected.'); end
    end
    fprintf('  ✓ Data folder: %s\n', dataDir);
end

% =========================================================================
% HELPER: BATCH PROCESSING LOGIC
% =========================================================================
function processAndSave(dataDir, excelPath, sheetName, snapshotPath)
    allFiles = dir(fullfile(dataDir, '**', '*'));
    allFiles = allFiles(~[allFiles.isdir]);
    rawFiles = allFiles(~cellfun(@(n) contains(n, '.'), {allFiles.name}));

    if isempty(rawFiles)
        if isfile(snapshotPath), return; else error('No data found.'); end
    end

    if isfile(snapshotPath)
        if all([rawFiles.datenum] <= dir(snapshotPath).datenum)
            fprintf('  ✓ Snapshot up to date. Skipping processing.\n');
            return;
        end
    end

    fprintf('  → Processing %d files...\n', numel(rawFiles));
    resultsList = [];

    for i = 1:numel(rawFiles)
        try
            fullPath = fullfile(rawFiles(i).folder, rawFiles(i).name);
            [specID, isoDate] = parseFilename(rawFiles(i));
            calcData = Function_LaserAnalysis(fullPath);
            
            % Create row with only computed metrics (no Angle/Power/Visualize)
            row = struct('ID', specID, 'Date', isoDate);
            fields = fieldnames(calcData);
            for f = 1:length(fields)
                row.(fields{f}) = calcData.(fields{f});
            end
            
            if isempty(resultsList), resultsList = row; else resultsList(end+1) = row; end
        catch
            fprintf('    ! Failed: %s\n', rawFiles(i).name);
        end
    end

    T = struct2table(resultsList);
    T = sortrows(T, {'ID', 'Date'});
    
    % Save .mat (This T has no Angle/Power/Visualize yet; syncExcelToSnapshot will add them)
    lastUpdated = datetime('now');
    save(snapshotPath, 'T', 'lastUpdated');

    % Excel Write: Only write computed columns (A-N), preserve formulas in O-Q
    writetable(T(:, 'ID'), excelPath, 'Sheet', sheetName, 'Range', 'A1');
    writetable(T(:, 'Date'), excelPath, 'Sheet', sheetName, 'Range', 'B1');
    
    % Write only the 12 computed metric columns (C through N)
    metricsOnly = T(:, {'AccuracyLaser', 'AccuracyNonLaser', ...
                        'OmissionsLaser', 'OmissionsNonLaser', ...
                        'LaserReward', 'NonLaserReward', ...
                        'LaserTrials', 'NonLaserTrials', ...
                        'oLaserPercent', 'oNonLaserPercent', ...
                        'LatencyLaser', 'LatencyNonLaser'});
    writetable(metricsOnly, excelPath, 'Sheet', sheetName, 'Range', 'C1');
    
    fprintf('  ✓ Excel core data updated (A-N). Formula columns (O-Q) preserved.\n');
end

% =========================================================================
% HELPER: EXCEL TO SNAPSHOT SYNC
% =========================================================================
function syncExcelToSnapshot(excelFile, sheetName, snapshotFile)
    if ~isfile(excelFile) || ~isfile(snapshotFile), return; end
    
    % Read Excel (including formula results from columns O, P, Q)
    opts = detectImportOptions(excelFile, 'Sheet', sheetName, 'VariableNamingRule', 'preserve');
    excelData = readtable(excelFile, opts, 'Sheet', sheetName);
    excelData.Properties.VariableNames = matlab.lang.makeValidName(excelData.Properties.VariableNames);

    % Load current Snapshot
    load(snapshotFile, 'T');
    
    % Initialize Angle, Power, Visualize in table T if they don't exist
    if ~ismember('Angle', T.Properties.VariableNames), T.Angle = NaN(height(T),1); end
    if ~ismember('Power', T.Properties.VariableNames), T.Power = NaN(height(T),1); end
    if ~ismember('Visualize', T.Properties.VariableNames), T.Visualize = true(height(T),1); end

    % Prepare matching keys
    exIDs = string(excelData.ID);
    snIDs = string(T.ID);
    exDates = normalizeDates(excelData.Date);
    snDates = normalizeDates(T.Date);

    % Convert Excel formula outputs to proper types
    exAngle = safeConvertToDouble(excelData.Angle);
    exPower = safeConvertToDouble(excelData.Power);
    
    % Handle Visualize as boolean (may come as numeric or logical from Excel)
    if isnumeric(excelData.Visualize)
        exVisualize = logical(excelData.Visualize);
    elseif islogical(excelData.Visualize)
        exVisualize = excelData.Visualize;
    else
        % Handle string/cell representation
        exVisualize = strcmpi(string(excelData.Visualize), 'true') | ...
                      strcmpi(string(excelData.Visualize), '1');
    end

    updatedCount = 0;
    for i = 1:height(T)
        idx = find((exIDs == snIDs(i)) & (exDates == snDates(i)), 1);
        if ~isempty(idx)
            T.Angle(i) = exAngle(idx);
            T.Power(i) = exPower(idx);
            T.Visualize(i) = exVisualize(idx);
            updatedCount = updatedCount + 1;
        end
    end

    lastUpdated = datetime('now');
    save(snapshotFile, 'T', 'lastUpdated');
    fprintf('  ✓ Synced %d records (Angle, Power, Visualize) from Excel to GUI.\n', updatedCount);
end

%function removeOutliers(excelFile, sheetName, snapshotFile)

% =========================================================================
% UTILITIES
% =========================================================================
function d = normalizeDates(dateCol)
    if isdatetime(dateCol), d = dateshift(dateCol, 'start', 'day');
    else d = datetime(string(dateCol), 'InputFormat', 'yyyy-MM-dd'); end
end

function v = safeConvertToDouble(data)
    if isnumeric(data), v = double(data);
    elseif isstring(data) || iscell(data), v = str2double(string(data));
    else v = NaN(size(data,1),1); end
end

function [specID, isoDate] = parseFilename(fileInfo)
    parts = split(fileInfo.name, '-');
    if numel(parts) >= 3
        specID = string(parts{end});
        rawDate = parts{1};
        isoDate = string([rawDate(5:8) '-' rawDate(1:2) '-' rawDate(3:4)]);
    else
        [~, specID] = fileparts(fileInfo.folder);
        specID = string(specID);
        isoDate = string(datestr(fileInfo.datenum, 'yyyy-mm-dd'));
    end
end
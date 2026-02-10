%% Run_Batch_Processing.m
clc; clear; 

% --- CONFIGURATION ---
targetFolderName = 'labview_copy'; 
outputExcel = 'Batch_Analysis_Results.xlsx';
% ---------------------

% 1. INTELLIGENT PATH SETUP
currentDir = pwd;
[~, currentFolderName] = fileparts(currentDir);

if strcmpi(currentFolderName, targetFolderName)
    dataDir = currentDir;
elseif isfolder(fullfile(currentDir, targetFolderName))
    dataDir = fullfile(currentDir, targetFolderName);
else
    dataDir = uisetdir(currentDir, 'Select the labview_copy folder');
    if dataDir == 0, error('Cancelled'); end
end

fprintf('Target Data Directory: %s\n', dataDir);

% 2. LOAD EXISTING DATA (TO PRESERVE MANUAL ENTRIES)
fullExcelPath = fullfile(pwd, outputExcel);
existingData = table();

if isfile(fullExcelPath)
    fprintf('Loading existing Excel file to preserve manual edits...\n');
    opts = detectImportOptions(fullExcelPath);
    opts.VariableNamingRule = 'preserve';
    
    % Force ID to be string to avoid type mismatches
    opts = setvartype(opts, 'ID', 'string');
    opts = setvartype(opts, 'Date', 'string');
    
    try
        existingData = readtable(fullExcelPath, opts);
    catch
        warning('Could not read existing Excel file. Starting fresh.');
    end
end

% 3. RECURSIVE SEARCH
allFiles = dir(fullfile(dataDir, '**', '*'));
allFiles = allFiles(~[allFiles.isdir]);

resultsList = [];
count = 0;

% 4. LOOP THROUGH FILES
for i = 1:length(allFiles)
    thisFile = allFiles(i);
    fileName = thisFile.name;
    
    if contains(fileName, '.')
        continue; 
    end
    
    % --- PARSE METADATA ---
    parts = split(fileName, '-');
    if length(parts) >= 3
        specimenID = parts{end}; 
        rawDate = parts{1};      
        if length(rawDate) == 8
             isoDate = [rawDate(5:8) '-' rawDate(1:2) '-' rawDate(3:4)];
        else
             isoDate = rawDate;
        end
    else
        [~, specimenID] = fileparts(thisFile.folder);
        isoDate = datestr(thisFile.datenum, 'yyyy-mm-dd');
    end
    
    fprintf('Processing %s (ID: %s)... ', fileName, specimenID);
    
    try
        % CALL ANALYSIS FUNCTION
        calcData = Function_LaserAnalysis(fullfile(thisFile.folder, fileName));
        
        % Check if this row already exists in Excel
        % We match based on ID and Date (and Filename if you added it)
        matchIdx = [];
        if ~isempty(existingData)
             % Find row where ID matches AND Date matches
             matchIdx = find(strcmp(existingData.ID, specimenID) & ...
                             strcmp(existingData.Date, isoDate));
        end
        
        % Initialize row with existing data if found, or empty if new
        if ~isempty(matchIdx)
            % Grab the FIRST match (in case of duplicates)
            rowEntry = table2struct(existingData(matchIdx(1), :));
            isNew = false;
        else
            rowEntry = struct();
            rowEntry.ID = string(specimenID);
            rowEntry.Date = string(isoDate);
            % Initialize manual columns with NaN if they don't exist
            rowEntry.Angle = NaN;
            rowEntry.Power = NaN;
            isNew = true;
        end
        
        % --- OVERWRITE CALCULATED FIELDS ONLY ---
        rowEntry.AccuracyLaser = calcData.AccuracyLaser;
        rowEntry.AccuracyNonLaser = calcData.AccuracyNonLaser;
        rowEntry.OmissionsLaser = calcData.OmissionsLaser;
        rowEntry.OmissionsNonLaser = calcData.OmissionsNonLaser;
        rowEntry.LaserReward = calcData.LaserReward;
        rowEntry.NonLaserReward = calcData.NonLaserReward;
        rowEntry.LaserTrials = calcData.LaserTrials;
        rowEntry.NonLaserTrials = calcData.NonLaserTrials;
        rowEntry.oNonLaserPercent = calcData.oNonLaserPercent;
        rowEntry.oLaserPercent = calcData.oLaserPercent;
        rowEntry.LatencyLaser = calcData.LatencyLaser;
        rowEntry.LatencyNonLaser = calcData.LatencyNonLaser;
        
        % Append to our master list
        if isempty(resultsList)
            resultsList = rowEntry;
        else
            % Handle mismatched fields (e.g. if Excel has extra columns)
            % This aligns the struct fields
            fields = fieldnames(rowEntry);
            existingFields = fieldnames(resultsList);
            
            % Add missing fields to resultsList
            for k = 1:length(fields)
                if ~isfield(resultsList, fields{k})
                    [resultsList.(fields{k})] = deal(NaN);
                end
            end
            % Add missing fields to rowEntry
            for k = 1:length(existingFields)
                if ~isfield(rowEntry, existingFields{k})
                    rowEntry.(existingFields{k}) = NaN;
                end
            end
            
            resultsList(end+1) = rowEntry;
        end
        
        if isNew
            fprintf('Done (New Entry).\n');
        else
            fprintf('Done (Updated).\n');
        end
        count = count + 1;
        
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
end

% 5. SAVE TO EXCEL
if ~isempty(resultsList)
    T = struct2table(resultsList);
    
    % Ensure column order (ID, Angle, Power first)
    desiredOrder = {'ID', 'Angle', 'Power', 'Date', ...
                    'AccuracyLaser', 'AccuracyNonLaser', 'OmissionsLaser', ...
                    'OmissionsNonLaser', 'LaserReward', 'NonLaserReward', ...
                    'LaserTrials', 'NonLaserTrials', 'oLaserPercent', ...
                    'oNonLaserPercent', 'LatencyLaser', 'LatencyNonLaser'};
    
    % Find which desired columns actually exist in T
    validVars = intersect(desiredOrder, T.Properties.VariableNames, 'stable');
    
    % Move them to the front
    T = movevars(T, validVars, 'Before', 1);
    
    % Sort by ID then Date
    T = sortrows(T, {'ID', 'Date'});
    
    writetable(T, outputExcel);
    fprintf('Success! Saved %d records to %s. Manual entries preserved.\n', count, outputExcel);
else
    fprintf('No valid data found.\n');
end
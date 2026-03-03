%% Batch_Processing.m
clc; clear; 

% --- CONFIGURATION ---

% Change folder name based on the raw data directory
targetFolderName = 'labview_copy'; 

% Change excel sheet name to either generate a new file or rewrite in a
% previous one
outputExcel = 'Batch_Analysis_Results.xlsx';

% Change this to specify which Sheet of the .xlsx should be read/write
targetSheet = 'ProcessedResults'; 
% ---------------------
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
fullExcelPath = fullfile(pwd, outputExcel);
existingData = table();

if isfile(fullExcelPath)
    [~, sheets] = xlsfinfo(fullExcelPath);
    if ismember(targetSheet, sheets)
        fprintf('Loading existing data from sheet: %s...\n', targetSheet);
        opts = detectImportOptions(fullExcelPath, 'Sheet', targetSheet);
        opts.VariableNamingRule = 'preserve';
        opts = setvartype(opts, {'ID', 'Date'}, 'string'); 
        
        try
            existingData = readtable(fullExcelPath, opts);
        catch
            warning('Could not read existing sheet. Starting fresh.');
        end
    else
        fprintf('Sheet "%s" not found. It will be created.\n', targetSheet);
    end
end

allFiles = dir(fullfile(dataDir, '**', '*'));
allFiles = allFiles(~[allFiles.isdir]);
resultsList = [];
count = 0;

for i = 1:length(allFiles)
    thisFile = allFiles(i);
    fileName = thisFile.name;
    if contains(fileName, '.'), continue; end
    
    % Extraction of ID and Date
    parts = split(fileName, '-');
    if length(parts) >= 3
        specimenID = string(parts{end}); 
        rawDate = parts{1};      
        if length(rawDate) == 8
             isoDate = string([rawDate(5:8) '-' rawDate(1:2) '-' rawDate(3:4)]);
        else
             isoDate = string(rawDate);
        end
    else
        [~, specimenID] = fileparts(thisFile.folder);
        specimenID = string(specimenID);
        isoDate = string(datestr(thisFile.datenum, 'yyyy-mm-dd'));
    end
    
    fprintf('Processing %s (ID: %s)... ', fileName, specimenID);
    
    try
        calcData = Function_LaserAnalysis(fullfile(thisFile.folder, fileName));
        
        matchIdx = [];
        if ~isempty(existingData)
             matchIdx = find(strcmp(existingData.ID, specimenID) & ...
                             strcmp(existingData.Date, isoDate));
        end

        if ~isempty(matchIdx)
            rowEntry = table2struct(existingData(matchIdx(1), :));
            isNew = false;
        else
            rowEntry = struct();
            rowEntry.ID = specimenID;
            rowEntry.Date = isoDate;
            rowEntry.Angle = NaN; 
            rowEntry.Power = NaN;
            isNew = true;
        end
        
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
        
        if isempty(resultsList)
            resultsList = rowEntry;
        else
            f_names = fieldnames(rowEntry);
            for k = 1:length(f_names)
                if ~isfield(resultsList, f_names{k})
                    [resultsList.(f_names{k})] = deal(NaN);
                end
            end
            resultsList(end+1) = rowEntry;
        end
        
        if isNew, fprintf('Done (New).\n'); else, fprintf('Done (Updated).\n'); end
        count = count + 1;
        
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
end

if ~isempty(resultsList)
    T = struct2table(resultsList);
    desiredOrder = {'ID', 'Angle', 'Power', 'Date', 'AccuracyLaser', 'AccuracyNonLaser', 'OmissionsLaser', 'OmissionsNonLaser', 'LaserReward', 'NonLaserReward', 'LaserTrials', 'NonLaserTrials', 'oLaserPercent', 'oNonLaserPercent', 'LatencyLaser', 'LatencyNonLaser'};
    validVars = intersect(desiredOrder, T.Properties.VariableNames, 'stable');
    T = movevars(T, validVars, 'Before', 1);
    T = sortrows(T, {'ID', 'Date'});
    writetable(T, outputExcel, 'Sheet', targetSheet);
    
    fprintf('Success! Saved %d records to tab "%s" in %s.\n', count, targetSheet, outputExcel);
else
    fprintf('No valid data found.\n');
end
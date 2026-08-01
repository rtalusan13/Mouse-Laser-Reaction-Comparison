%% Setup_Global_Paths.m
% =========================================================================
% USER-FACING INTERFACE — run this ONCE on each computer before anything else.
%
% What it does:
%   Saves your folder locations so that Batch_Processing.m can find your
%   data automatically without you having to edit any other file.
%
% How to use:
%   1. Edit DATA_ROOT below to point to your experiment folder
%   2. Press F5 (or click Run)
%   3. You will see "Setup complete." when it works
%   4. You never need to run this script again on this computer
%
% =========================================================================
clc;

% ── EDIT THIS ONE LINE ────────────────────────────────────────────────────
%
% Set DATA_ROOT to the folder that CONTAINS your labview_copy folder.
%
% Windows example:  'C:\Users\YourName\Documents\MyExperiment'
% Mac example:      '/Users/YourName/Documents/MyExperiment'
% Network example:  '\\labserver\data\SoundLoc'
%
DATA_ROOT = 'C:\Users\YourName\Documents\MyExperiment';
%
% ─────────────────────────────────────────────────────────────────────────

% Validate the path the user entered
if ~isfolder(DATA_ROOT)
    error( ...
        ['The folder "%s" does not exist.\n' ...
         'Please check the DATA_ROOT path in Setup_Global_Paths.m and try again.'], ...
        DATA_ROOT);
end

% Build the standard sub-folder paths
LABVIEW_FOLDER   = fullfile(DATA_ROOT, 'labview_copy');
CODE_FOLDER      = fileparts(mfilename('fullpath'));   % folder where this script lives

% Warn if labview_copy does not exist yet (it may not on first run)
if ~isfolder(LABVIEW_FOLDER)
    warning( ...
        ['The labview_copy folder was not found inside DATA_ROOT.\n' ...
         'Expected location: %s\n' ...
         'Create this folder and move your raw LabVIEW files into it.'], ...
        LABVIEW_FOLDER);
end

% Save paths to a config file so Batch_Processing.m can read them
configFile = fullfile(CODE_FOLDER, 'soundloc_paths.mat');
save(configFile, 'DATA_ROOT', 'LABVIEW_FOLDER', 'CODE_FOLDER');

% Add code folder to MATLAB path for this session and permanently
addpath(CODE_FOLDER);
savepath;

fprintf('\n');
fprintf('Setup complete.\n');
fprintf('  Data root:      %s\n', DATA_ROOT);
fprintf('  LabVIEW folder: %s\n', LABVIEW_FOLDER);
fprintf('  Config saved:   %s\n', configFile);
fprintf('\n');
fprintf('You can now run Batch_Processing.m without editing any paths.\n');
fprintf('To open the GUI, type:  app = SoundLocalizationGUI;\n\n');
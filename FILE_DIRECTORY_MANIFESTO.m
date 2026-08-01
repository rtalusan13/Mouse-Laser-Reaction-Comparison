% FILE_DIRECTORY_MANIFESTO.m
% =========================================================================
% This file is documentation only — it does not run.
% Read it to understand what every file in the project does and whether
% you should ever need to open or edit it.
% =========================================================================
%
% ═══════════════════════════════════════════════════════════════════════════
% LAYER 1 — USER-FACING INTERFACES
% These are the files you interact with directly to run your experiment.
% ═══════════════════════════════════════════════════════════════════════════
%
% Batch_Processing.m
%   WHAT IT DOES : Scans the labview_copy folder for raw LabView files,
%                  calls the analysis engine on each one, and saves results
%                  to an Excel file and a .mat snapshot.
%   WHEN TO RUN  : After each recording session or at the end of the week
%                  when you want to update your dataset.
%   OUTPUT FILES : Batch_Analysis_Results.xlsx
%                  Batch_Analysis_Results_Snapshot.mat
%   EDIT?        : Only the CONFIGURATION block at the top (folder name,
%                  Excel filename). Nothing else.
%
% SoundLocalizationGUI.m
%   WHAT IT DOES : The graphical analysis application. Load the .mat
%                  snapshot and explore accuracy, latency, omissions,
%                  learning curves, statistics, and trial replays.
%   WHEN TO RUN  : Type  app = SoundLocalizationGUI;  in the MATLAB
%                  Command Window after running Batch_Processing.m.
%   INPUT FILES  : Batch_Analysis_Results_Snapshot.mat
%   EDIT?        : No. Use the GUI controls to filter and export.
%
% Setup_Global_Paths.m
%   WHAT IT DOES : One-time setup script. Run it once per workstation to
%                  configure all folder paths. After that, Batch_Processing
%                  finds your data automatically.
%   WHEN TO RUN  : First time only on each computer.
%   EDIT?        : Fill in your data folder path at the top. Nothing else.
%
% pairedplot_soundlocalization.m
%   WHAT IT DOES : Standalone script for generating paired accuracy plots
%                  grouped by Power level, from a specific .xlsx file.
%                  Used for quick figure generation outside the GUI.
%   WHEN TO RUN  : Manually, when you want to plot a specific animal's
%                  data by power level.
%   EDIT?        : Update the file path at line 4 to point to your xlsx.
%
% Labview_Laser_analysis.m
%   WHAT IT DOES : Single-session interactive analysis script used during
%                  early development. Loads one file by hardcoded path and
%                  plots a latency histogram with Wilcoxon test.
%   WHEN TO RUN  : Rarely — only for quick spot-checks of a single session.
%   EDIT?        : Update the hardcoded file path at line 7.
%   NOTE         : This file defines the authoritative column mapping
%                  (column_order variable) that all other scripts depend on.
%
%
% ═══════════════════════════════════════════════════════════════════════════
% LAYER 2 — INTERNAL ENGINES
% These files are called automatically. You should not need to run or
% edit them under normal circumstances.
% ═══════════════════════════════════════════════════════════════════════════
%
% Function_LaserAnalysis.m
%   WHAT IT DOES : The core analysis engine. Given one raw LabView file,
%                  computes accuracy, omissions, and latency for laser and
%                  non-laser trials. Returns a result struct.
%   CALLED BY    : Batch_Processing.m (for each file in the loop)
%                  SoundLocalizationGUI.m (via the Re-Sync button)
%   EDIT?        : Only if the column layout of your LabView files changes,
%                  or if you are adapting the paradigm. See Developer_Guide.md.
%
%
% ═══════════════════════════════════════════════════════════════════════════
% LAYER 3 — QUALITY ASSURANCE & DEVELOPMENT TOOLS
% These files exist to test and validate the engines. Researchers do not
% need to interact with them during normal use.
% ═══════════════════════════════════════════════════════════════════════════
%
% SoundLoc_TestSuite.m
%   WHAT IT DOES : Automated unit tests for Function_LaserAnalysis.m.
%                  Generates synthetic datasets with known answers and
%                  verifies the engine produces correct output.
%   WHEN TO RUN  : After any edit to Function_LaserAnalysis.m, run:
%                    results = runtests('SoundLoc_TestSuite');
%   EDIT?        : Only to add new test cases.
%
% SoundLoc_BuildRoadmap.m
%   WHAT IT DOES : A benchmarking script that measures how fast each
%                  component of the pipeline runs and prints pass/fail
%                  against time targets.
%   WHEN TO RUN  : After major code changes to check for regressions.
%   EDIT?        : No.
%
% SoundLoc_OptimizationAndDeployment.m
%   WHAT IT DOES : Memory profiling tools, accessibility patch utilities,
%                  and instructions for compiling the GUI into a standalone
%                  executable using the MATLAB Compiler.
%   WHEN TO RUN  : Only when preparing to deploy on a new workstation or
%                  compile to a standalone app for non-MATLAB users.
%   EDIT?        : No.
%
%
% ═══════════════════════════════════════════════════════════════════════════
% DATA FILE STATES — what each output file represents
% ═══════════════════════════════════════════════════════════════════════════
%
%   STATE 1 — RAW
%   Files in labview_copy/  (no extension, one file per session)
%   These are the original LabView recordings. Never modify them.
%   Example: labview_copy/12312025-121753-1034
%
%   STATE 2 — PROCESSED
%   Batch_Analysis_Results.xlsx          (human-readable, one row per session)
%   Batch_Analysis_Results_Snapshot.mat  (binary copy for fast GUI loading)
%   These are generated by Batch_Processing.m. Safe to delete and regenerate.
%
%   STATE 3 — VISUALIZED / EXPORTED
%   SoundLoc_Report.pdf   (generated by GUI Export button)
%   SoundLoc_Report.xlsx  (generated by GUI Export button — animal summaries)
%   These are final outputs for figures or sharing. Keep these separately
%   from your processed data folder to avoid confusion.
%
% =========================================================================
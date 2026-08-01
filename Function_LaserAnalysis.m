function result = Function_LaserAnalysis(filename)
% Function_LaserAnalysis  —  INTERNAL ENGINE
% =========================================================================
% Reads one raw LabView behavioral file and computes all metrics for
% a single recording session.
%
% INPUT
%   filename : full path to a raw LabView file (no extension, tab-delimited)
%
% OUTPUT
%   result   : struct with fields listed at the bottom of this file
%
% DO NOT EDIT the trial-detection or accuracy logic below unless you are
% changing the experimental paradigm. See Developer_Guide.md for details.
%
% COLUMN MAPPING (from Labview_Laser_analysis.m column_order definition):
%   Col 1  — timestamps          (seconds, continuous clock)
%   Col 2  — left lick           (1 = lick detected on left spout)
%   Col 3  — right lick          (1 = lick detected on right spout)
%   Col 4  — left water          (1 = water delivered on left)
%   Col 5  — right water         (1 = water delivered on right)
%   Col 6  — trigger_by_lick     (1 = water delivery was triggered by lick)
%   Col 7  — soundonset / trial start (1 = new trial began)
%   Col 8  — trial_num           (integer, increments each trial)
%   Col 9  — soundAB / sound type:
%              1 or 2 = Non-Laser trial
%              3 or 4 = Laser trial
%   Col 10 — ITI flag
%   Col 11 — free water release
%   Col 12 — mistake left
%   Col 13 — mistake right
% =========================================================================

    % ── Read file ─────────────────────────────────────────────────────────
    opts = detectImportOptions(filename);
    opts.VariableNamingRule = 'preserve';
    datab = table2array(readtable(filename, opts));

    % ── Timing constants (seconds) ────────────────────────────────────────
    SOUND_DUR       = 1.025;  % duration of the sound stimulus
    REACTION_PERIOD = 1.750;  % allowed time after sound for the animal to lick
    OMISSION_WINDOW = SOUND_DUR + REACTION_PERIOD;  % = 2.775 s total

    % ── Extract columns by index ──────────────────────────────────────────
    timestamps      = datab(:, 1);
    trigger_by_lick = datab(:, 6);
    soundonset      = datab(:, 7);
    trial_num       = datab(:, 8);
    soundAB         = datab(:, 9);

    % ── Find trial start rows ─────────────────────────────────────────────
    % A trial starts whenever soundonset == 1.
    % soundAB at that row tells us whether it is a Laser or Non-Laser trial.
    trial_ind         = find(soundonset == 1);
    trial_ind_laser   = trial_ind(soundAB(trial_ind) == 3 | soundAB(trial_ind) == 4);
    trial_ind_nonlaser= trial_ind(soundAB(trial_ind) == 1 | soundAB(trial_ind) == 2);

    % ── Count rewards and omissions ───────────────────────────────────────
    [reward_laser,    omiss_laser]    = countRewardsAndOmissions( ...
        trial_ind_laser,    datab, timestamps, trial_num, trigger_by_lick, OMISSION_WINDOW);

    [reward_nonlaser, omiss_nonlaser] = countRewardsAndOmissions( ...
        trial_ind_nonlaser, datab, timestamps, trial_num, trigger_by_lick, OMISSION_WINDOW);

    % ── Accuracy (hit rate among non-omission trials) ─────────────────────
    denom_laser    = numel(trial_ind_laser)    - omiss_laser;
    denom_nonlaser = numel(trial_ind_nonlaser) - omiss_nonlaser;

    if denom_laser > 0
        accuracyLaser = (reward_laser / denom_laser) * 100;
    else
        accuracyLaser = NaN;
    end

    if denom_nonlaser > 0
        accuracyNonLaser = (reward_nonlaser / denom_nonlaser) * 100;
    else
        accuracyNonLaser = NaN;
    end

    % ── Omission percentages ─────────────────────────────────────────────
    nLaser    = max(numel(trial_ind_laser),    1);  % avoid divide-by-zero
    nNonLaser = max(numel(trial_ind_nonlaser), 1);
    pct_omiss_laser    = (omiss_laser    / nLaser)    * 100;
    pct_omiss_nonlaser = (omiss_nonlaser / nNonLaser) * 100;

    % ── First-lick latency ────────────────────────────────────────────────
    [m_laser, m_nonlaser] = computeLatency( ...
        timestamps, trigger_by_lick, trial_ind_laser, trial_ind_nonlaser);

    % ── Pack results ──────────────────────────────────────────────────────
    result.AccuracyLaser    = accuracyLaser;
    result.AccuracyNonLaser = accuracyNonLaser;
    result.OmissionsLaser   = omiss_laser;
    result.OmissionsNonLaser= omiss_nonlaser;
    result.LaserReward      = reward_laser;
    result.NonLaserReward   = reward_nonlaser;
    result.LaserTrials      = numel(trial_ind_laser);
    result.NonLaserTrials   = numel(trial_ind_nonlaser);
    result.oLaserPercent    = pct_omiss_laser;
    result.oNonLaserPercent = pct_omiss_nonlaser;
    result.LatencyLaser     = m_laser;
    result.LatencyNonLaser  = m_nonlaser;
end


% =========================================================================
% LOCAL HELPER FUNCTIONS
% =========================================================================

function [rewardCount, omissionCount] = countRewardsAndOmissions( ...
        trialIndices, datab, timestamps, trial_num, trigger_by_lick, omissionWindow)
% Loops over the given trial start rows and counts:
%   rewardCount   — trials where the animal licked and got water
%   omissionCount — trials where the animal did not respond in time
%
% A reward is detected when the row immediately after the trial start has:
%   - the same trial number (still within the same trial), AND
%   - trigger_by_lick == 1 (water was given because animal licked)
%
% An omission is detected when:
%   - the trial number changed before any lick, OR
%   - the time between trial start and next row exceeds the omission window

    rewardCount   = 0;
    omissionCount = 0;

    for i = 1:numel(trialIndices)
        nextRow = trialIndices(i) + 1;

        % Skip if this is the last row in the file
        if nextRow > size(datab, 1)
            continue;
        end

        % Check for reward
        sameTrialNum = (trial_num(nextRow) == trial_num(nextRow - 1));
        animalLicked = (trigger_by_lick(nextRow) == 1);
        if sameTrialNum && animalLicked
            rewardCount = rewardCount + 1;
        end

        % Check for omission
        trialNumberChanged = (trial_num(nextRow) ~= trial_num(nextRow - 1));
        timeExceeded       = (timestamps(nextRow) - timestamps(nextRow - 1)) > omissionWindow;
        if trialNumberChanged || timeExceeded
            omissionCount = omissionCount + 1;
        end
    end
end


function [meanLatencyLaser, meanLatencyNonLaser] = computeLatency( ...
        timestamps, trigger_by_lick, trial_ind_laser, trial_ind_nonlaser)
% Computes the mean first-lick latency separately for laser and non-laser
% rewarded trials.
%
% Latency = time from trial start row to the next row where the animal
% received water by licking (trigger_by_lick == 1).

    % Find all rows where a lick-triggered reward occurred
    lick_rows = find(trigger_by_lick);
    lick_rows = lick_rows(lick_rows > 1);  % need at least one row before

    % For each lick row, check if the preceding row was a laser trial start
    laser_lick_rows    = lick_rows(ismember(lick_rows - 1, trial_ind_laser));
    nonlaser_lick_rows = lick_rows(ismember(lick_rows - 1, trial_ind_nonlaser));

    if ~isempty(laser_lick_rows)
        latencies_laser  = timestamps(laser_lick_rows) - timestamps(laser_lick_rows - 1);
        meanLatencyLaser = mean(latencies_laser);
    else
        meanLatencyLaser = NaN;
    end

    if ~isempty(nonlaser_lick_rows)
        latencies_nonlaser  = timestamps(nonlaser_lick_rows) - timestamps(nonlaser_lick_rows - 1);
        meanLatencyNonLaser = mean(latencies_nonlaser);
    else
        meanLatencyNonLaser = NaN;
    end
end
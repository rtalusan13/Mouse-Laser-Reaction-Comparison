function result = Function_LaserAnalysis(filename)
    % 1. LOAD DATA 
    % We suppress warnings about variable names to keep output clean
    opts = detectImportOptions(filename);
    opts.VariableNamingRule = 'preserve'; 
    datab = readtable(filename, opts); 
    datab = table2array(datab);

    % Constants
    sound_dur = 1.025;
    reaction_period = 1.75;
    
    % Column mapping based on your script
    timestamps = datab(:,1);
    soundonset = datab(:,7);
    trial_num = datab(:,8);
    soundAB = datab(:,9);
    trigger_by_lick = datab(:,6);

    %% Analysis on Hit Rate
    trial_ind = find(soundonset == 1);
    
    % Identify Laser vs Non-Laser trials
    trial_ind_nonlaser = trial_ind(soundAB(trial_ind)==1 | soundAB(trial_ind)==2);
    trial_ind_laser = trial_ind(soundAB(trial_ind)==3 | soundAB(trial_ind)==4);
    
    reward_by_lick_num_laser = 0;
    reward_by_lick_num_nonlaser = 0;
    omiss_laser = 0;
    omiss_nonlaser = 0;
    
    % --- Laser Loop ---
    for i = 1:numel(trial_ind_laser)
        ind = trial_ind_laser(i)+1;
        if ind <= size(datab,1)
            if (trial_num(ind) == trial_num(ind-1)) && trigger_by_lick(ind) == 1
                reward_by_lick_num_laser = reward_by_lick_num_laser + 1;    
            end
            if trial_num(ind) ~= trial_num(ind-1) || (timestamps(ind) - timestamps(ind-1) > (sound_dur+reaction_period))
                omiss_laser = omiss_laser+1;
            end
        end
    end
    
    % --- Non-Laser Loop ---
    for i = 1:numel(trial_ind_nonlaser)
        ind = trial_ind_nonlaser(i)+1;
        if ind <= size(datab,1)
            if (trial_num(ind) == trial_num(ind-1)) && trigger_by_lick(ind) == 1
                reward_by_lick_num_nonlaser = reward_by_lick_num_nonlaser + 1;
            end
            if trial_num(ind) ~= trial_num(ind-1) || (timestamps(ind) - timestamps(ind-1) > (sound_dur+reaction_period))
                omiss_nonlaser = omiss_nonlaser+1;
            end
        end
    end

    % Calculate Percentages
    denom_laser = numel(trial_ind_laser) - omiss_laser;
    if denom_laser > 0
        accuracyLaser = (reward_by_lick_num_laser / denom_laser) * 100; 
    else
        accuracyLaser = NaN;
    end
    
    denom_nonlaser = numel(trial_ind_nonlaser) - omiss_nonlaser;
    if denom_nonlaser > 0
        accuracyNonLaser = (reward_by_lick_num_nonlaser / denom_nonlaser) * 100;
    else
        accuracyNonLaser = NaN;
    end
    
    pct_omiss_laser = (omiss_laser / numel(trial_ind_laser)) * 100;
    pct_omiss_nonlaser = (omiss_nonlaser / numel(trial_ind_nonlaser)) * 100;

    %% Calculating First Lick Latency
    first_lick = find(trigger_by_lick);
    
    laser_reward_indices = [];    % Renamed to avoid confusion
    nonlaser_reward_indices = [];
    
    for i = 1:length(first_lick)
       if ismember(first_lick(i)-1, trial_ind_laser)
            laser_reward_indices = [laser_reward_indices, first_lick(i)];
       end
       if ismember(first_lick(i)-1, trial_ind_nonlaser)
            nonlaser_reward_indices = [nonlaser_reward_indices, first_lick(i)];
       end
    end
    
    if ~isempty(laser_reward_indices)
        laser_first_lick = timestamps(laser_reward_indices) - timestamps(laser_reward_indices-1);
        m_laser = mean(laser_first_lick);
    else
        m_laser = NaN;
    end

    if ~isempty(nonlaser_reward_indices)
        nonlaser_first_lick = timestamps(nonlaser_reward_indices) - timestamps(nonlaser_reward_indices-1);
        m_nonlaser = mean(nonlaser_first_lick);
    else
        m_nonlaser = NaN;
    end

    omiss_laser_FirstIndex = omiss_laser(1);
    omiss_nonLaser_FirstIndex = omiss_nonlaser(1);
    
    result.AccuracyLaser = accuracyLaser;
    result.AccuracyNonLaser = accuracyNonLaser;
    result.OmissionsLaser = omiss_laser_FirstIndex;
    result.OmissionsNonLaser = omiss_nonLaser_FirstIndex;
    result.LaserReward = reward_by_lick_num_laser;
    result.NonLaserReward = reward_by_lick_num_nonlaser;
    result.LaserTrials = numel(trial_ind_laser);
    result.NonLaserTrials = numel(trial_ind_nonlaser);
    result.oLaserPercent = pct_omiss_laser;
    result.oNonLaserPercent = pct_omiss_nonlaser;
    result.LatencyLaser = m_laser;
    result.LatencyNonLaser = m_nonlaser;

    result.Angle = NaN;
    result.Power = NaN;
end
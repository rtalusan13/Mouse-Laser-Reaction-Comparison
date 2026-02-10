clc
clear all
close all

%load this data file based on its name an d path
%datab=readtable("D:\LABVIEW sound localization\11252025\11222025-115442-1029"); 
datab=readtable("C:\Users\rapha\Research\sophie_thesis\Code\labview_copy\12312025-121753-1034"); 


% C:\Users\rapha\Research\sophie_thesis\labview_copy
% maybe need to store all data as a directory in the same folder as the
% MATLAB script?

datab = table2array(datab);
% "F:\07312025-155046-948L"  "F:\07302025-145149-948L"

sound_dur = 1.025;
reaction_period = 1.75;

column_order = {'time';
                'left lick';
                'right lick';
                'left water';
                'right water';
                'water triggered by lick';
                'trial start';
                'trial num';
                'sound type';
                'ITI';
                'free water release';
                'mistake left';
                'mistake right';}


timestamps=datab(:,1);

% set the seventh column as new trail start indicators
soundonset=datab(:,7);

trial_num = datab(:,8);
% set the ninth column as sound type indicators
soundAB=datab(:,9);

trigger_by_lick = datab(:,6);

%% analysis on hit rate (4 situations)
trial_ind = find(soundonset == 1);

trial_ind_nonlaser = trial_ind(soundAB(trial_ind)==1 |soundAB(trial_ind)==2);
trial_ind_laser = trial_ind(soundAB(trial_ind)==3 |soundAB(trial_ind)==4);

reward_by_lick_num_laser = 0;
reward_by_lick_num_nonlaser = 0;

omiss_laser = 0;
omiss_nonlaser = 0;

for i = 1:numel(trial_ind_laser)
    ind = trial_ind_laser(i)+1;
    if ind <= size(datab,1)
        if (trial_num(ind) == trial_num(ind-1)) & trigger_by_lick(ind) == 1
            reward_by_lick_num_laser = reward_by_lick_num_laser + 1;    
        end

        if trial_num(ind) ~= trial_num(ind-1) |(timestamps(ind) - timestamps(ind-1) > (sound_dur+reaction_period))
            omiss_laser = omiss_laser+1;
        end
    end
end

for i = 1:numel(trial_ind_nonlaser)
    ind = trial_ind_nonlaser(i)+1;
    if ind <= size(datab,1)
        if (trial_num(ind) == trial_num(ind-1)) & trigger_by_lick(ind) == 1
            reward_by_lick_num_nonlaser = reward_by_lick_num_nonlaser + 1;
        end
       
       if trial_num(ind) ~= trial_num(ind-1) |(timestamps(ind) - timestamps(ind-1) > (sound_dur+reaction_period))
            omiss_nonlaser = omiss_nonlaser+1;

        end
    end
end
%%
% hit_rate_laser: mistake + reward + omiss = total trials

accuracyLaser = reward_by_lick_num_laser/(numel(trial_ind_laser)-omiss_laser)

accuracyNonLaser = reward_by_lick_num_nonlaser/(numel(trial_ind_nonlaser)-omiss_nonlaser)

num_mistake = numel(trial_ind) - omiss_laser - omiss_nonlaser - reward_by_lick_num_nonlaser - reward_by_lick_num_laser;

%% analysis on lick time
% 
% % first find only trials that get reward by licking
% 
% trial_ind = find(soundonset == 1);
% reward_by_lick_num = 0;
% reward_time = [];
% left_reward_time = [];
% right_reward_time = [];
% for i = 1:numel(trial_ind)
%     ind = trial_ind(i)+1;
%     if trigger_by_lick(ind) == 1
%         reward_by_lick_num = reward_by_lick_num + 1;
%         reward_time = [reward_time; timestamps(ind) - timestamps(ind-1)];
%         if soundAB(i) == 1
%             left_reward_time = [ left_reward_time; timestamps(ind) - timestamps(ind-1)];
%         else
%             right_reward_time = [ right_reward_time; timestamps(ind) - timestamps(ind-1)];
%         end
%     end
% end
% 
% figure
% bin_edge = 0:0.01:3;
% hist(reward_time, bin_edge)
% xlabel('Time (s)')
% 
% figure
% hist(left_reward_time, bin_edge)
% xlabel('Time (s)')
% title('6hz')
% 
% figure
% hist(right_reward_time, bin_edge)
% xlabel('Time (s)')
% title('40hz')
% 
% mean(reward_time)
% median(reward_time)
% mode(reward_time)
% prctile(reward_time,80)

%% calculating the first lick latency


first_lick = find(trigger_by_lick);
first_lick_times = timestamps(first_lick) - timestamps(first_lick-1);

laser_reward = [];
nonlaser_reward = [];
for i = 1:length(first_lick)
   if ismember (first_lick(i)-1 , trial_ind_laser)
    laser_reward = [laser_reward,first_lick(i)];
   end
   if ismember (first_lick(i)-1 , trial_ind_nonlaser)
    nonlaser_reward = [nonlaser_reward,first_lick(i)];
   end
end



laser_first_lick = timestamps(laser_reward) - timestamps(laser_reward-1);
nonlaser_first_lick = timestamps(nonlaser_reward) -timestamps(nonlaser_reward-1);


figure; hold on

all_data = [laser_first_lick; nonlaser_first_lick];
edges = linspace(min(all_data), max(all_data), 15);

h1 = histogram(laser_first_lick, edges, ...
    'FaceAlpha', 0.6, 'EdgeColor', 'none');
h2 = histogram(nonlaser_first_lick, edges, ...
    'FaceAlpha', 0.6, 'EdgeColor', 'none');

ax = gca;
color_order = ax.ColorOrder;

laser_color    = color_order(h1.SeriesIndex, :);
nonlaser_color = color_order(h2.SeriesIndex, :);

m_laser    = mean(laser_first_lick);
m_nonlaser = mean(nonlaser_first_lick);

yl = ylim;

plot([m_laser m_laser], yl, 'w', 'LineWidth', 2.5)
plot([m_laser m_laser], yl, 'Color', laser_color, 'LineWidth', 2.5,'LineStyle','--')

plot([m_nonlaser m_nonlaser], yl, 'w', 'LineWidth', 2.5)
plot([m_nonlaser m_nonlaser], yl, 'Color', nonlaser_color, 'LineWidth', 2.5,'LineStyle','--')

[p, ~] = ranksum(laser_first_lick, nonlaser_first_lick);

legend({'Laser', 'Non-laser'}, 'Location', 'best')
xlabel('First lick latency (s)')
ylabel('Count')
title(sprintf('First lick latency: Laser vs Non-laser (p = %.3g)', p))

box off
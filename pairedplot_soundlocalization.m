%% Paired Accuracy Plot (Nonlaser vs Laser) by Power

% Read dataset
data = readtable("C:\Users\cvm-gritton-lab\Documents\Sound_Localization_Data\New data\ARCH_PV_1034rerun_new.xlsx",VariableNamingRule="preserve");  % <-- replace with your filename

% Get unique power and angle values
powers = unique(data.Power);
angles = unique(data.Angle);

% Assign distinct colors for each angle
colors = lines(numel(angles));  % 'lines' gives visually distinct colors

% Create tiled layout
figure;
t = tiledlayout(1, numel(powers), 'Padding', 'compact', 'TileSpacing', 'compact');

for p = 1:numel(powers)
    nexttile;
    % Subset data for this power level
    sub = data(data.Power == powers(p), :);
    
    hold on;
    % Loop through each angle
    for a = 1:numel(angles)
        thisAngle = angles(a);
        subset = sub(sub.Angle == thisAngle, :);
        
        % Extract paired accuracy values
        accNonlaser = subset.AccuracyNonlaser;
        accLaser = subset.AccuracyLaser;
        
        % X positions
        xNonlaser = ones(size(accNonlaser));
        xLaser = 2 * ones(size(accLaser));

        % Plot paired lines (thicker lines, larger markers)
        for i = 1:length(accLaser)
            plot([xNonlaser(i), xLaser(i)], [accNonlaser(i), accLaser(i)], '-o', ...
                'Color', colors(a,:), ...
                'MarkerFaceColor', colors(a,:), ...
                'MarkerSize', 6, ...      % larger marker
                'LineWidth', 2);          % thicker line
        end
    end
    
    % Formatting
    xlim([0.5 2.5]);
    ylim([0 100]);  % adjust as needed
    xticks([1 2]);
    xticklabels({'Nonlaser', 'Laser'});
    ylabel('% Accuracy');
    title(sprintf('Power = %g', powers(p)));
    grid on;
    hold off;
end

% Overall title
title(t, '1034 ARCH-PV Laser vs Nonlaser Clean (high omissions)');

% Add legend for angles
lgdLabels = arrayfun(@(x) sprintf('Angle = %.1f°', x), angles, 'UniformOutput', false);
legend(lgdLabels, 'Location', 'bestoutside');


classdef SoundLocalizationGUI < matlab.apps.AppBase

% =========================================================================
% SoundLocalizationGUI.m
%
% A professional, class-based MATLAB App Designer application for
% analyzing sound localization data from laser/non-laser behavioral
% experiments. Built around a binary .mat snapshot engine to eliminate
% repeated Excel I/O latency, with lazy-loaded graphics, vectorized
% statistics, and a publication-ready report generator.
% =========================================================================

    %% ── PUBLIC PROPERTIES ───────────────────────────────────────────────
    properties (Access = public)
        UIFigure    matlab.ui.Figure
    end

    %% ── PRIVATE UI COMPONENT PROPERTIES ─────────────────────────────────
    properties (Access = private)

        % ── Layout containers ─────────────────────────────────────────────
        SidebarPanel        matlab.ui.container.Panel
        WorkspacePanel      matlab.ui.container.Panel
        StatusBar           matlab.ui.control.Label
        TabGroup            matlab.ui.container.TabGroup

        % ── Sidebar controls ──────────────────────────────────────────────
        AppTitleLabel       matlab.ui.control.Label
        AppSubLabel         matlab.ui.control.Label
        NavButtons          cell
        LoadSnapshotBtn     matlab.ui.control.Button
        ResyncDataBtn       matlab.ui.control.Button
        ExportReportBtn     matlab.ui.control.Button
        SidebarDivider1     matlab.ui.control.Label
        SidebarDivider2     matlab.ui.control.Label

        % ── Filter panel ─────────────────────────────────────────────────
        FilterPanel         matlab.ui.container.Panel
        AnimalFilterDD      matlab.ui.control.DropDown
        AngleFilterDD       matlab.ui.control.DropDown
        PowerFilterDD       matlab.ui.control.DropDown
        DateStartPicker     matlab.ui.control.DatePicker
        DateEndPicker       matlab.ui.control.DatePicker
        ApplyFilterBtn      matlab.ui.control.Button
        ClearFilterBtn      matlab.ui.control.Button
        ShowOutliersChk     matlab.ui.control.CheckBox
        OutlierCountLabel   matlab.ui.control.Label

        % ── Tab 1: Dashboard ──────────────────────────────────────────────
        Tab1                matlab.ui.container.Tab
        DashKPI             cell
        DashKPILabel        cell
        DashKPITitle        cell
        DashAxesPaired      matlab.ui.control.UIAxes
        DashAxesLatency     matlab.ui.control.UIAxes
        DashAxesOmission    matlab.ui.control.UIAxes

        % ── Tab 2: Raw Inspection ─────────────────────────────────────────
        Tab2                matlab.ui.container.Tab
        RawTable            matlab.ui.control.Table
        RawDetailAxes       matlab.ui.control.UIAxes
        RawDetailAxes2      matlab.ui.control.UIAxes

        % ── Tab 3: Trend Analysis ─────────────────────────────────────────
        Tab3                matlab.ui.container.Tab
        TrendAxes           matlab.ui.control.UIAxes
        TrendAxes2          matlab.ui.control.UIAxes
        TrendAnimalDD       matlab.ui.control.DropDown
        TrendMetricDD       matlab.ui.control.DropDown
        TrendSmoothSlider   matlab.ui.control.Slider
        TrendSmoothLabel    matlab.ui.control.Label
        TrendStatsLabel     matlab.ui.control.Label

        % ── Tab 4: 3D Manifold ────────────────────────────────────────────
        Tab4                matlab.ui.container.Tab
        ManifoldAxes        matlab.ui.control.UIAxes
        ManifoldAnimalDD    matlab.ui.control.DropDown
        ManifoldMetricDD    matlab.ui.control.DropDown
        ManifoldColorDD     matlab.ui.control.DropDown
        ManifoldRenderBtn   matlab.ui.control.Button
        ManifoldInfoLabel   matlab.ui.control.Label

        % ── Tab 5: Statistics ─────────────────────────────────────────────
        Tab5                matlab.ui.container.Tab
        StatAxes1           matlab.ui.control.UIAxes
        StatAxes2           matlab.ui.control.UIAxes
        StatTextArea        matlab.ui.control.TextArea
        StatTestDD          matlab.ui.control.DropDown
        StatRunBtn          matlab.ui.control.Button
        StatOutlierTable    matlab.ui.control.Table

        % ── Tab 6: Trial Replay ───────────────────────────────────────────
        Tab6                matlab.ui.container.Tab
        ReplayAxes          matlab.ui.control.UIAxes
        ReplayFileBtn       matlab.ui.control.Button
        ReplayPlayBtn       matlab.ui.control.Button
        ReplayStopBtn       matlab.ui.control.Button
        ReplaySpeedDD       matlab.ui.control.DropDown
        ReplaySlider        matlab.ui.control.Slider
        ReplayInfoLabel     matlab.ui.control.Label
        ReplayTimer         timer

    end

    %% ── PRIVATE DATA & GRAPHICS CONTROLLER PROPERTIES ───────────────────
    properties (Access = private)

        % ── DataController: single source of truth ────────────────────────
        DC struct = struct( ...
            'RawTable',       [], ...   
            'FilteredTable',  [], ...   
            'SnapshotPath',   '', ...   
            'LastUpdated',    [], ...   
            'OutlierMask',    [], ...   
            'IQRMultiplier',  1.5, ...  
            'ReplayData',     [], ...   
            'ReplayIndex',    1   ...   
        )

        % ── GraphicsHandles: cache to avoid re-plotting ───────────────────
        GH struct = struct( ...
            'DashPairedLines',   matlab.graphics.chart.primitive.Line.empty, ...
            'DashLatencyLines',  matlab.graphics.chart.primitive.Line.empty, ...
            'DashOmissionLines', matlab.graphics.chart.primitive.Line.empty, ...
            'TrendLaserLine',    matlab.graphics.chart.primitive.Line.empty, ...
            'TrendNonLaserLine', matlab.graphics.chart.primitive.Line.empty, ...
            'TrendSmooth',     [], ...
            'ManifoldSurf',    [], ...
            'StatBox1',        [], ...
            'StatBox2',        [], ...
            'ReplayEventLines',[], ...
            'ReplayHead',      []  ...
        )

        % ── Color palette (Professional, colorblind-friendly) ──────────────
        Colors struct = struct( ...
            'Sidebar',      [0.173 0.243 0.314], ...  % Dark Blue-Gray
            'Workspace',    [0.925 0.941 0.945], ...  % Light Background
            'LaserBlue',    [0.00  0.40  0.65], ...   % Deep Blue (Laser)
            'CoralRed',     [0.90  0.35  0.25], ...   % Coral (Non-Laser)
            'ForestGreen',  [0.20  0.60  0.30], ...   % Forest Green (Positive)
            'BurntSienna',  [0.80  0.25  0.20], ...   % Burnt Sienna (Negative)
            'Teal',         [0.00  0.60  0.70], ...   % Teal (Channel 1)
            'Purple',       [0.70  0.20  0.90], ...   % Purple (Channel 2)
            'Magenta',      [0.95  0.20  0.55], ...   % Magenta (Channel 3)
            'Gold',         [1.00  0.65  0.00], ...   % Gold (Channel 4)
            'LimeGreen',    [0.70  0.95  0.10], ...   % Lime Green (Channel 5)
            'Cyan',         [0.00  0.95  1.00], ...   % Cyan (Channel 6)
            'CardBG',       [1.000 1.000 1.000], ...  % White Cards
            'TextDark',     [0.133 0.153 0.161], ...  % Dark Text
            'TextLight',    [0.945 0.945 0.945], ...  % Light Text
            'GridLine',     [0.750 0.760 0.770]  ...  % Enhanced Grid Visibility
        )

        % ── UI geometry constants ─────────────────────────────────────────
        Geo struct = struct( ...
            'FigW',     1440, ...
            'FigH',     900,  ...
            'SideW',    220,  ...
            'FilterH',  200,  ...
            'StatusH',  28    ...
        )

    end

    %% ══════════════════════════════════════════════════════════════════════
    %% COMPONENT INITIALIZATION
    %% ══════════════════════════════════════════════════════════════════════
    methods (Access = private)

        function buildUI(app)
            app.buildFigure();
            app.buildSidebar();
            app.buildStatusBar();
            app.buildWorkspace();
            app.buildFilterPanel();
            app.buildTab1_Dashboard();
            app.buildTab2_RawInspection();
            app.buildTab3_TrendAnalysis();
            app.buildTab4_3DManifold();
            app.buildTab5_Statistics();
            app.buildTab6_TrialReplay();
            app.styleAllAxes();
        end

        function buildFigure(app)
            app.UIFigure = uifigure( ...
                'Name',       'Sound Localization Research Platform', ...
                'Position',   [80 60 app.Geo.FigW app.Geo.FigH], ...
                'Color',      app.Colors.Workspace, ...
                'Resize',     'on', ...
                'AutoResizeChildren', 'off');
            app.UIFigure.SizeChangedFcn = @(~,~) app.onResize();
        end

        function buildSidebar(app)
            W = app.Geo.SideW; H = app.Geo.FigH;
            app.SidebarPanel = uipanel(app.UIFigure, ...
                'Position',       [1 1 W H], ...
                'BackgroundColor', app.Colors.Sidebar, ...
                'BorderType',     'none');

            % Logo / title block
            app.AppTitleLabel = uilabel(app.SidebarPanel, ...
                'Text',            'SoLoGUI', ...
                'Position',        [14 H-68 W-28 36], ...
                'FontSize',        22, ...
                'FontWeight',      'bold', ...
                'FontColor',       app.Colors.TextLight);
            %app.AppSubLabel = uilabel(app.SidebarPanel, ...
            %    'Text',            'Research Platform', ...
            %    'Position',        [14 H-88 W-28 18], ...
            %    'FontSize',        10, ...
            %    'FontColor',       [0.6 0.7 0.75]);

            % ── Nav buttons (one per tab) ──────────────────────────────────
            navLabels  = {'> Dashboard','> Raw Data','> Trend Analysis', ...
                          '> 3D Manifold','> Statistics','> Trial Replay'};
            yStart = H - 150;
            app.NavButtons = cell(6,1);
            for k = 1:6
                btn = uibutton(app.SidebarPanel, ...
                    'Text',            ['  ' navLabels{k}], ...
                    'Position',        [8 yStart-(k-1)*42 W-16 36], ...
                    'BackgroundColor', app.Colors.Sidebar, ...
                    'FontColor',       app.Colors.TextLight, ...
                    'FontSize',        12, ...
                    'HorizontalAlignment','left', ...
                    'ButtonPushedFcn', @(~,~) app.onNavButton(k));
                app.NavButtons{k} = btn;
            end
            app.highlightNav(1);

            % ── Divider ────────────────────────────────────────────────────
            app.SidebarDivider1 = uilabel(app.SidebarPanel, ...
                'Text',           repmat('─',1,22), ...
                'Position',       [8 H-400 W-16 16], ...
                'FontColor',      [0.35 0.45 0.5]);

            % ── Action buttons ─────────────────────────────────────────────
            yA = H - 430;
            app.LoadSnapshotBtn = uibutton(app.SidebarPanel, ...
                'Text',           '📂  Load New Snapshot', ...
                'Position',       [8 yA W-16 34], ...
                'BackgroundColor',[0.173 0.35 0.49], ...
                'FontColor',      app.Colors.TextLight, ...
                'FontSize',       11, ...
                'Tooltip',        'Load a .mat snapshot generated by Batch_Processing.m', ...
                'ButtonPushedFcn',@(~,~) app.loadSnapshot());

            app.ResyncDataBtn = uibutton(app.SidebarPanel, ...
                'Text',           '🔄  Regenerate Raw Data', ...
                'Position',       [8 yA-42 W-16 34], ...
                'BackgroundColor',[0.16 0.42 0.31], ...
                'FontColor',      app.Colors.TextLight, ...
                'FontSize',       11, ...
                'Tooltip',        'Re-run batch processing on raw LabView files and refresh the snapshot', ...
                'ButtonPushedFcn',@(~,~) app.resyncData());

            app.ExportReportBtn = uibutton(app.SidebarPanel, ...
                'Text',           '📄  Export Graphic Report', ...
                'Position',       [8 yA-84 W-16 34], ...
                'BackgroundColor',[0.42 0.20 0.56], ...
                'FontColor',      app.Colors.TextLight, ...
                'FontSize',       11, ...
                'Tooltip',        'Export vectorized PDF figures + curated Excel summary', ...
                'ButtonPushedFcn',@(~,~) app.exportReport());

            app.SidebarDivider2 = uilabel(app.SidebarPanel, ...
                'Text',           repmat('─',1,22), ...
                'Position',       [8 yA-105 W-16 16], ...
                'FontColor',      [0.35 0.45 0.5]);

            % ── Filter panel (embedded in sidebar) ────────────────────────
            app.FilterPanel = uipanel(app.SidebarPanel, ...
                'Title',          'FILTERS', ...
                'TitlePosition',  'centertop', ...
                'Position',       [4 8 W-8 yA-120], ...
                'BackgroundColor',app.Colors.Sidebar, ...
                'ForegroundColor',[0.6 0.7 0.75], ...
                'BorderColor',    [0.35 0.45 0.5], ...
                'FontSize',       9, ...
                'FontWeight',     'bold');
        end

        function buildStatusBar(app)
            W = app.Geo.FigW; SH = app.Geo.StatusH; SW = app.Geo.SideW;
            app.StatusBar = uilabel(app.UIFigure, ...
                'Text',           '  No data loaded — use Load Snapshot or Re-Sync Data', ...
                'Position',       [SW+1 1 W-SW-1 SH], ...
                'BackgroundColor',[0.20 0.25 0.30], ...
                'FontColor',      [0.7 0.8 0.82], ...
                'FontSize',       10, ...
                'HorizontalAlignment','left');
        end

        function buildWorkspace(app)
            SW = app.Geo.SideW; SH = app.Geo.StatusH;
            W  = app.Geo.FigW - SW;
            H  = app.Geo.FigH - SH;
            app.WorkspacePanel = uipanel(app.UIFigure, ...
                'Position',       [SW+1 SH+1 W H], ...
                'BackgroundColor', app.Colors.Workspace, ...
                'BorderType',     'none');

            app.TabGroup = uitabgroup(app.WorkspacePanel, ...
                'Position',       [0 0 W H], ...
                'TabLocation',    'top', ...
                'SelectionChangedFcn', @(~,e) app.onTabChanged(e));
        end

        function buildFilterPanel(app)
            FP = app.FilterPanel;
            fH = FP.Position(4) - 20;

            uilabel(FP,'Text','Animal ID','Position',[6 fH-30 90 16], ...
                'FontColor',app.Colors.TextLight,'FontSize',9);
            app.AnimalFilterDD = uidropdown(FP, ...
                'Items',          {'All'}, ...
                'Position',       [6 fH-52 190 22], ...
                'BackgroundColor',[0.22 0.30 0.38], ...
                'FontColor',      app.Colors.TextLight, ...
                'FontSize',       10);

            uilabel(FP,'Text','Angle (°)','Position',[6 fH-78 90 16], ...
                'FontColor',app.Colors.TextLight,'FontSize',9);
            app.AngleFilterDD = uidropdown(FP, ...
                'Items',          {'All'}, ...
                'Position',       [6 fH-100 190 22], ...
                'BackgroundColor',[0.22 0.30 0.38], ...
                'FontColor',      app.Colors.TextLight, ...
                'FontSize',       10);

            uilabel(FP,'Text','Power (mW)','Position',[6 fH-126 90 16], ...
                'FontColor',app.Colors.TextLight,'FontSize',9);
            app.PowerFilterDD = uidropdown(FP, ...
                'Items',          {'All'}, ...
                'Position',       [6 fH-148 190 22], ...
                'BackgroundColor',[0.22 0.30 0.38], ...
                'FontColor',      app.Colors.TextLight, ...
                'FontSize',       10);

            uilabel(FP,'Text','Date From','Position',[6 fH-174 90 16], ...
                'FontColor',app.Colors.TextLight,'FontSize',9);
            app.DateStartPicker = uidatepicker(FP, ...
                'Position',       [6 fH-196 90 22], ...
                'BackgroundColor',[0.22 0.30 0.38], ...
                'FontColor',      app.Colors.TextLight, ...
                'FontSize',       9);

            uilabel(FP,'Text','Date To','Position',[106 fH-174 90 16], ...
                'FontColor',app.Colors.TextLight,'FontSize',9);
            app.DateEndPicker = uidatepicker(FP, ...
                'Position',       [106 fH-196 90 22], ...
                'BackgroundColor',[0.22 0.30 0.38], ...
                'FontColor',      app.Colors.TextLight, ...
                'FontSize',       9);

            app.ShowOutliersChk = uicheckbox(FP, ...
                'Text',           'Highlight IQR Outliers', ...
                'Position',       [6 fH-222 180 20], ...
                'FontColor',      [1.0 0.7 0.4], ...
                'Value',          true, ...
                'FontSize',       9);

            app.OutlierCountLabel = uilabel(FP, ...
                'Text',           '', ...
                'Position',       [6 fH-242 180 16], ...
                'FontColor',      app.Colors.BurntSienna, ...
                'FontSize',       9);

            app.ApplyFilterBtn = uibutton(FP, ...
                'Text',           'Apply Filter', ...
                'Position',       [6 fH-272 90 26], ...
                'BackgroundColor',app.Colors.LaserBlue, ...
                'FontColor',      'white', ...
                'FontSize',       10, ...
                'ButtonPushedFcn',@(~,~) app.applyFilter());

            app.ClearFilterBtn = uibutton(FP, ...
                'Text',           'Clear', ...
                'Position',       [106 fH-272 90 26], ...
                'BackgroundColor',[0.28 0.35 0.42], ...
                'FontColor',      app.Colors.TextLight, ...
                'FontSize',       10, ...
                'ButtonPushedFcn',@(~,~) app.clearFilter());
        end

        function buildTab1_Dashboard(app)
            app.Tab1 = uitab(app.TabGroup, 'Title', 'Dashboard', 'Scrollable', 'on');
            
            % Reference dimensions for the charts
            W = app.TabGroup.Position(3);
            H = app.TabGroup.Position(4) - 30;

            % --- 1. KPI SECTION: FIXED PIXEL ANCHORING ---
            kpiTitles = {'Sessions','Selected ID','Avg Acc (L)','Avg Acc (NL)',...
                        'Avg Lat (L)','Avg Lat (NL)','Avg Om (L)','Avg Om (NL)'};
            
            % Hardcoded constants to prevent resolution-based stretching
            startMargin = 15;   % Leftmost padding
            boxWidth    = 105;  % Exact width of every box
            boxHeight   = 85;   % Exact height of every box
            gap         = 6;    % Horizontal spacing between boxes
            
            app.DashKPI      = cell(8,1);
            app.DashKPILabel = cell(8,1);
            
            for k = 1:8
                % Position is calculated solely based on box index, not screen width
                currentX = startMargin + (k-1)*(boxWidth + gap);
                
                % Create Panel
                p = uipanel(app.Tab1, ...
                    'Units', 'pixels', ...
                    'Position', [currentX, H-95, boxWidth, boxHeight], ...
                    'BackgroundColor', app.Colors.CardBG, ...
                    'BorderType', 'line', ...
                    'BorderColor', app.Colors.GridLine);
                app.DashKPI{k} = p;
                
                % Value Label (The Main Number/Text)
                app.DashKPILabel{k} = uilabel(p, ...
                    'Text', '—', ...
                    'Position', [2 30 boxWidth-4 45], ...
                    'FontSize', 22, 'FontWeight', 'bold', ...
                    'FontColor', app.Colors.LaserBlue, 'HorizontalAlignment', 'center');
                    
                % Subtitle Label
                uilabel(p, ...
                    'Text', kpiTitles{k}, ...
                    'Position', [2 8 boxWidth-4 20], ...
                    'FontSize', 9, 'FontColor', [0.5 0.5 0.55], 'HorizontalAlignment', 'center');
            end

            % --- 2. CHART SECTION: RESPONSIVE GRID ---
            gridMargin = 20;
            gridGap    = 40;
            chartW = (W - 2*gridMargin - gridGap) / 2;
            chartH = 300;
            
            % Y positions for 2-row layout
            row1Y = H - 115 - chartH;         
            row2Y = row1Y - chartH - gridGap; 
            
            % 1. Behavioral Accuracy
            app.DashAxesPaired = uiaxes(app.Tab1, 'Position', [gridMargin row1Y chartW chartH], ...
                'BackgroundColor', app.Colors.CardBG);
            title(app.DashAxesPaired, 'Behavioral Accuracy');
            ylabel(app.DashAxesPaired, 'Accuracy (%)');

            % 2. Latency
            app.DashAxesLatency = uiaxes(app.Tab1, 'Position', [gridMargin+chartW+gridGap row1Y chartW chartH], ...
                'BackgroundColor', app.Colors.CardBG);
            title(app.DashAxesLatency, 'First-Lick Latency');
            ylabel(app.DashAxesLatency, 'Latency (s)');

            % 3. Omission Rate
            app.DashAxesOmission = uiaxes(app.Tab1, 'Position', [gridMargin row2Y chartW chartH], ...
                'BackgroundColor', app.Colors.CardBG);
            title(app.DashAxesOmission, 'Omission Rate (%)');
            ylabel(app.DashAxesOmission, 'Omissions (%)');
            xlabel(app.DashAxesOmission, 'Session Number');

            % 4. Extra Space Panel
        end

        function buildTab2_RawInspection(app)
            app.Tab2 = uitab(app.TabGroup, 'Title', 'Raw Inspection');
            
            % CRITICAL: Prevent MATLAB from moving components during resize
            app.Tab2.AutoResizeChildren = 'off';
            
            W = app.TabGroup.Position(3);
            H = app.TabGroup.Position(4) - 120;

            % 1. DEFINE COLUMN ORDER (Based on your new Excel structure)
            % Mapping the technical table names to clean display names
            dispNames = {'Animal ID', 'Day', 'Session', 'Total Trials', ...
                        'Acc (L)', 'Acc (NL)', 'Lat (L)', 'Lat (NL)', ...
                        'Om (L)', 'Om (NL)'};
                    
            % Note: The actual Data mapping happens in renderRawTable, 
            % but we define the headers here.
            
            tH = round(H * 0.52);
            app.RawTable = uitable(app.Tab2, ...
                'Units', 'pixels', ...
                'Position', [10, H-tH-10, W-20, tH], ...
                'ColumnName', dispNames, ...
                'RowName', {}, ...
                'BackgroundColor', [app.Colors.CardBG; app.Colors.Workspace], ...
                'FontSize', 11, ...
                'ColumnSortable', true, ...
                'SelectionType', 'row', ...
                'CellSelectionCallback', @(~,e) app.onRawTableSelect(e));

            % 2. AXES LAYOUT (Responsive Split)
            dH = H - tH - 40;
            halfW = round((W - 30) / 2);
            
            % Accuracy by Trial Type (Bottom Left)
            app.RawDetailAxes = uiaxes(app.Tab2, ...
                'Units', 'pixels', ...
                'Position', [10, 10, halfW, dH], ...
                'BackgroundColor', app.Colors.CardBG, ...
                'GridColor', [0.8 0.8 0.8]);
            title(app.RawDetailAxes, 'Accuracy by Trial Type');
            ylabel(app.RawDetailAxes, '%');

            % Latency by Trial Type (Bottom Right)
            app.RawDetailAxes2 = uiaxes(app.Tab2, ...
                'Units', 'pixels', ...
                'Position', [halfW + 20, 10, halfW, dH], ...
                'BackgroundColor', app.Colors.CardBG, ...
                'GridColor', [0.8 0.8 0.8]);
            title(app.RawDetailAxes2, 'Latency by Trial Type');
            ylabel(app.RawDetailAxes2, 'Seconds');
        end

        function buildTab3_TrendAnalysis(app)
            app.Tab3 = uitab(app.TabGroup, 'Title', 'Trend Analysis');
            W = app.TabGroup.Position(3);
            H = app.TabGroup.Position(4) - 30;

            ctrlY = H - 50;
            uilabel(app.Tab3,'Text','Animal:','Position',[10 ctrlY 55 22], ...
                'FontWeight','bold','FontSize',11);
            app.TrendAnimalDD = uidropdown(app.Tab3, ...
                'Items',   {'All'}, ...
                'Position',[68 ctrlY 110 26], ...
                'ValueChangedFcn', @(~,~) app.renderTrend());

            uilabel(app.Tab3,'Text','Metric:','Position',[200 ctrlY 55 22], ...
                'FontWeight','bold','FontSize',11);
            app.TrendMetricDD = uidropdown(app.Tab3, ...
                'Items',   {'AccuracyLaser','AccuracyNonLaser', ...
                             'LatencyLaser','LatencyNonLaser', ...
                             'oLaserPercent','oNonLaserPercent'}, ...
                'Position',[258 ctrlY 160 26], ...
                'ValueChangedFcn', @(~,~) app.renderTrend());

            uilabel(app.Tab3,'Text','Smooth (sessions):','Position',[440 ctrlY 130 22], ...
                'FontSize',10);
            app.TrendSmoothSlider = uislider(app.Tab3, ...
                'Limits',  [1 10], 'Value', 3, ...
                'Position',[575 ctrlY+8 140 4], ...
                'ValueChangedFcn', @(~,~) app.renderTrend());
            app.TrendSmoothLabel = uilabel(app.Tab3, ...
                'Text',    '3', ...
                'Position',[722 ctrlY 30 22], ...
                'FontSize',10);

            app.TrendAxes = uiaxes(app.Tab3, ...
                'Position', [10 round(H*0.30) W-20 round(H*0.60)], ...
                'BackgroundColor', app.Colors.CardBG);
            title(app.TrendAxes, 'Session-over-Session Learning Curve');
            hold(app.TrendAxes, 'on');

            app.TrendAxes2 = uiaxes(app.Tab3, ...
                'Position', [10 10 W-20 round(H*0.25)], ...
                'BackgroundColor', app.Colors.CardBG);
            title(app.TrendAxes2, 'Δ Session Change');
            hold(app.TrendAxes2, 'on');

            app.TrendStatsLabel = uilabel(app.Tab3, ...
                'Text',    '', ...
                'Position',[10 H-28 W-20 22], ...
                'FontSize', 10, ...
                'FontColor',[0.3 0.3 0.3]);
        end

        function buildTab4_3DManifold(app)
            app.Tab4 = uitab(app.TabGroup, 'Title', '3D Manifold');
            W = app.TabGroup.Position(3);
            H = app.TabGroup.Position(4) - 30;

            ctrlY = H - 52;
            uilabel(app.Tab4,'Text','Animal:','Position',[10 ctrlY 55 22], ...
                'FontWeight','bold','FontSize',11);
            app.ManifoldAnimalDD = uidropdown(app.Tab4, ...
                'Items',   {'All'}, ...
                'Position',[68 ctrlY 110 26]);

            uilabel(app.Tab4,'Text','Z-Metric:','Position',[200 ctrlY 65 22], ...
                'FontWeight','bold','FontSize',11);
            app.ManifoldMetricDD = uidropdown(app.Tab4, ...
                'Items',   {'AccuracyLaser','AccuracyNonLaser', ...
                             'LatencyLaser','LatencyNonLaser', ...
                             'DeltaAccuracy'}, ...
                'Position',[268 ctrlY 160 26]);

            uilabel(app.Tab4,'Text','Colormap:','Position',[450 ctrlY 70 22], ...
                'FontSize',10);
            app.ManifoldColorDD = uidropdown(app.Tab4, ...
                'Items',   {'parula','jet','hot','cool','turbo'}, ...
                'Position',[524 ctrlY 100 26]);

            app.ManifoldRenderBtn = uibutton(app.Tab4, ...
                'Text',           'Render Surface', ...
                'Position',       [646 ctrlY 130 28], ...
                'BackgroundColor', app.Colors.LaserBlue, ...
                'FontColor',      'white', ...
                'ButtonPushedFcn',@(~,~) app.renderManifold());

            app.ManifoldInfoLabel = uilabel(app.Tab4, ...
                'Text',           '⚠  Angle/Power columns appear empty. Assign them via the Raw Inspection tab or .xlsx.', ...
                'Position',       [10 ctrlY-24 W-20 20], ...
                'FontColor',      app.Colors.BurntSienna, ...
                'FontSize',       9, ...
                'Visible',        'on');

            app.ManifoldAxes = uiaxes(app.Tab4, ...
                'Position',       [10 10 W-20 H-90], ...
                'BackgroundColor', app.Colors.CardBG, ...
                'Color',          app.Colors.CardBG, ...
                'Projection',     'perspective');
            xlabel(app.ManifoldAxes, 'Angle (°)');
            ylabel(app.ManifoldAxes, 'Power (mW)');
            zlabel(app.ManifoldAxes, 'Accuracy (%)');
            title(app.ManifoldAxes, '3D Performance Manifold');
            grid(app.ManifoldAxes, 'on');
            view(app.ManifoldAxes, -35, 30);
        end

        function buildTab5_Statistics(app)
            app.Tab5 = uitab(app.TabGroup, 'Title', 'Statistics');
            W = app.TabGroup.Position(3);
            H = app.TabGroup.Position(4) - 30;

            ctrlY = H - 50;
            uilabel(app.Tab5,'Text','Test:','Position',[10 ctrlY 40 22], ...
                'FontWeight','bold','FontSize',11);
            app.StatTestDD = uidropdown(app.Tab5, ...
                'Items',   {'Paired t-test (Laser vs Non-Laser)', ...
                             'One-way ANOVA by Animal', ...
                             'One-way ANOVA by Power', ...
                             'IQR Outlier Report'}, ...
                'Position',[54 ctrlY 260 26]);
            app.StatRunBtn = uibutton(app.Tab5, ...
                'Text',           '▶  Run Test', ...
                'Position',       [326 ctrlY 110 28], ...
                'BackgroundColor', app.Colors.ForestGreen, ...
                'FontColor',      'white', ...
                'ButtonPushedFcn',@(~,~) app.runStatTest());

            midH = round(H * 0.50);
            app.StatAxes1 = uiaxes(app.Tab5, ...
                'Position', [10 H-midH-60 round(W/2)-15 midH-10], ...
                'BackgroundColor', app.Colors.CardBG);
            title(app.StatAxes1, 'Distribution: Laser vs Non-Laser');
            hold(app.StatAxes1,'on');

            app.StatAxes2 = uiaxes(app.Tab5, ...
                'Position', [round(W/2)+5 H-midH-60 round(W/2)-15 midH-10], ...
                'BackgroundColor', app.Colors.CardBG);
            title(app.StatAxes2, 'Laser − Non-Laser Δ Accuracy');
            hold(app.StatAxes2,'on');

            app.StatTextArea = uitextarea(app.Tab5, ...
                'Position',   [10 10 W-20 H-midH-80], ...
                'FontName',   'Courier New', ...
                'FontSize',   11, ...
                'Editable',   'off', ...
                'Value',      {'Run a statistical test above to see results.'});

            app.StatOutlierTable = uitable(app.Tab5, ...
                'Position',   [10 10 W-20 H-midH-80], ...
                'FontSize',   10, ...
                'ColumnSortable', true, ...
                'Visible',    'off');
        end

        function buildTab6_TrialReplay(app)
            app.Tab6 = uitab(app.TabGroup, 'Title', 'Trial Replay');
            W = app.TabGroup.Position(3);
            H = app.TabGroup.Position(4) - 30;

            ctrlY = H - 50;
            app.ReplayFileBtn = uibutton(app.Tab6, ...
                'Text',           '📂  Open Raw LabView File', ...
                'Position',       [10 ctrlY 190 30], ...
                'BackgroundColor', app.Colors.LaserBlue, ...
                'FontColor',      'white', ...
                'FontSize',       11, ...
                'ButtonPushedFcn',@(~,~) app.loadReplayFile());

            app.ReplayPlayBtn = uibutton(app.Tab6, ...
                'Text',           '▶  Play', ...
                'Position',       [212 ctrlY 80 30], ...
                'BackgroundColor', app.Colors.ForestGreen, ...
                'FontColor',      'white', ...
                'Enable',         'off', ...
                'ButtonPushedFcn',@(~,~) app.startReplay());

            app.ReplayStopBtn = uibutton(app.Tab6, ...
                'Text',           '■  Stop', ...
                'Position',       [300 ctrlY 80 30], ...
                'BackgroundColor', app.Colors.BurntSienna, ...
                'FontColor',      'white', ...
                'Enable',         'off', ...
                'ButtonPushedFcn',@(~,~) app.stopReplay());

            uilabel(app.Tab6,'Text','Speed:','Position',[398 ctrlY 50 22], ...
                'FontSize',10);
            app.ReplaySpeedDD = uidropdown(app.Tab6, ...
                'Items',   {'0.25×','0.5×','1×','2×','5×'}, ...
                'Value',   '1×', ...
                'Position',[450 ctrlY 80 26]);

            app.ReplayInfoLabel = uilabel(app.Tab6, ...
                'Text',    'Load a raw LabView file (no extension, CSV-like format) to replay its trial timeline.', ...
                'Position',[10 ctrlY-24 W-20 20], ...
                'FontColor',[0.4 0.4 0.5], ...
                'FontSize', 9);

            app.ReplayAxes = uiaxes(app.Tab6, ...
                'Position', [10 50 W-20 H-110], ...
                'BackgroundColor', [0.05 0.07 0.10], ...
                'Color',    [0.05 0.07 0.10], ...
                'XColor',   [0.7 0.7 0.8], ...
                'YColor',   [0.7 0.7 0.8]);
            title(app.ReplayAxes, 'Trial Event Timeline', 'Color', [0.9 0.9 0.95]);
            xlabel(app.ReplayAxes, 'Time (s)', 'Color', [0.7 0.7 0.8]);
            ylabel(app.ReplayAxes, 'Event Channel', 'Color', [0.7 0.7 0.8]);
            yticks(app.ReplayAxes, 1:7);
            yticklabels(app.ReplayAxes, {'Timestamp','Left Lick','Right Lick', ...
                'Left Water','Right Water','Lick→Reward','Trial Start'});
            hold(app.ReplayAxes, 'on');

            app.ReplaySlider = uislider(app.Tab6, ...
                'Limits',  [0 1], ...
                'Value',   0, ...
                'Position',[10 36 W-20 4], ...
                'Enable',  'off', ...
                'ValueChangedFcn', @(s,~) app.scrubReplay(s.Value));
        end

        function styleAllAxes(app)
            allAx = findall(app.UIFigure, 'type', 'uiaxes');
            for i = 1:length(allAx)
                ax = allAx(i);
                try
                    ax.FontSize       = 10;
                    ax.GridColor      = app.Colors.GridLine;
                    ax.GridAlpha      = 0.6;
                    ax.Box            = 'off';
                    ax.TickDir        = 'out';
                    ax.LineWidth      = 0.8;
                    ax.FontName       = 'Segoe UI';
                    grid(ax, 'on');
                catch
                end
            end
        end

    end

    %% ══════════════════════════════════════════════════════════════════════
    %% DATA ENGINE
    %% ══════════════════════════════════════════════════════════════════════
    methods (Access = private)

        function loadSnapshot(app)
            [f, p] = uigetfile('*.mat', 'Select Batch_Analysis_Results_Snapshot.mat');
            if isequal(f, 0), return; end
            app.loadSnapshotFromPath(fullfile(p, f));
        end

        function resyncData(app)
            dataDir = uigetdir(pwd, 'Select LabView data folder (labview_copy)');
            if isequal(dataDir,0), return; end

            [f, p] = uiputfile('*.mat', 'Save snapshot as…', 'Batch_Analysis_Results_Snapshot.mat');
            if isequal(f,0), return; end
            outMat   = fullfile(p,f);
            outExcel = fullfile(p, strrep(f,'_Snapshot.mat','.xlsx')); % raph: changed to ensure the same sheet is used "Batch_Analysis_Results.xlsx"

            app.setStatus('Re-syncing raw data — this may take several minutes…');
            drawnow;

            try
                T = app.batchProcess(dataDir);
                if isempty(T)
                    uialert(app.UIFigure,'No valid files found in selected folder.','Re-Sync','Icon','warning');
                    app.setStatus('Re-sync: no data found.');
                    return;
                end
                lastUpdated = datetime('now');
                save(outMat, 'T', 'lastUpdated');
                writetable(T, outExcel, 'Sheet', 'ProcessedResults');

                app.DC.RawTable      = T;
                app.DC.FilteredTable = T;
                app.DC.SnapshotPath  = outMat;
                app.DC.LastUpdated   = lastUpdated;
                app.postLoadRefresh();
                uialert(app.UIFigure, ...
                    sprintf('Re-sync complete.\n%d records saved to:\n%s', height(T), outMat), ...
                    'Re-Sync Complete', 'Icon','success');
                app.setStatus(sprintf('Re-synced: %d records | %s', height(T), outMat));
            catch ME
                uialert(app.UIFigure, ME.message, 'Re-Sync Error', 'Icon','error');
                app.setStatus('Re-sync failed.');
            end
            app.renderDashboard();
        end

        function T = batchProcess(app, dataDir)
            allFiles = dir(fullfile(dataDir, '**', '*'));
            allFiles = allFiles(~[allFiles.isdir]);
            resultsList = [];

            for i = 1:length(allFiles)
                thisFile = allFiles(i);
                if contains(thisFile.name, '.'), continue; end

                parts = split(thisFile.name, '-');
                if length(parts) >= 3
                    specimenID = string(parts{end});
                    rawDate    = parts{1};
                    if length(rawDate) == 8
                        isoDate = string([rawDate(5:8) '-' rawDate(1:2) '-' rawDate(3:4)]);
                    else
                        isoDate = string(rawDate);
                    end
                else
                    [~, specimenID] = fileparts(thisFile.folder);
                    specimenID = string(specimenID);
                    isoDate    = string(datestr(thisFile.datenum,'yyyy-mm-dd'));
                end

                try
                    calcData = app.runLaserAnalysis(fullfile(thisFile.folder, thisFile.name));
                    row.ID               = specimenID;
                    row.Date             = isoDate;
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
                    %row.Angle            = NaN;
                    %row.Power            = NaN;
                    %row.Visualize        = NaN;


                    if isempty(resultsList)
                        resultsList = row;
                    else
                        resultsList(end+1) = row; %#ok<AGROW>
                    end
                catch
                end
            end

            if isempty(resultsList)
                T = table();
                return;
            end
            T = struct2table(resultsList);
            T = sortrows(T, {'ID','Date'});
        end

        function result = runLaserAnalysis(~, filename)
            opts = detectImportOptions(filename);
            opts.VariableNamingRule = 'preserve';
            datab = table2array(readtable(filename, opts));

            sound_dur       = 1.025;
            reaction_period = 1.75;
            timestamps      = datab(:,1);
            soundonset      = datab(:,7);
            trial_num       = datab(:,8);
            soundAB         = datab(:,9);
            trigger_by_lick = datab(:,6);

            trial_ind         = find(soundonset == 1);
            trial_ind_nonlaser= trial_ind(soundAB(trial_ind)==1 | soundAB(trial_ind)==2);
            trial_ind_laser   = trial_ind(soundAB(trial_ind)==3 | soundAB(trial_ind)==4);

            reward_laser    = 0;  reward_nonlaser  = 0;
            omiss_laser     = 0;  omiss_nonlaser   = 0;

            for i = 1:numel(trial_ind_laser)
                ind = trial_ind_laser(i) + 1;
                if ind > size(datab,1), continue; end
                if trial_num(ind) == trial_num(ind-1) && trigger_by_lick(ind) == 1
                    reward_laser = reward_laser + 1;
                end
                if trial_num(ind) ~= trial_num(ind-1) || ...
                        (timestamps(ind) - timestamps(ind-1)) > (sound_dur + reaction_period)
                    omiss_laser = omiss_laser + 1;
                end
            end

            for i = 1:numel(trial_ind_nonlaser)
                ind = trial_ind_nonlaser(i) + 1;
                if ind > size(datab,1), continue; end
                if trial_num(ind) == trial_num(ind-1) && trigger_by_lick(ind) == 1
                    reward_nonlaser = reward_nonlaser + 1;
                end
                if trial_num(ind) ~= trial_num(ind-1) || ...
                        (timestamps(ind) - timestamps(ind-1)) > (sound_dur + reaction_period)
                    omiss_nonlaser = omiss_nonlaser + 1;
                end
            end

            dL  = numel(trial_ind_laser)    - omiss_laser;
            dNL = numel(trial_ind_nonlaser) - omiss_nonlaser;
            accuracyLaser    = ternary(dL  > 0, (reward_laser    / dL)  * 100, NaN);
            accuracyNonLaser = ternary(dNL > 0, (reward_nonlaser / dNL) * 100, NaN);
            pct_omiss_laser    = (omiss_laser    / max(numel(trial_ind_laser),1))    * 100;
            pct_omiss_nonlaser = (omiss_nonlaser / max(numel(trial_ind_nonlaser),1)) * 100;

            first_lick = find(trigger_by_lick);
            laser_idx    = first_lick(ismember(first_lick-1, trial_ind_laser));
            nonlaser_idx = first_lick(ismember(first_lick-1, trial_ind_nonlaser));

            laser_idx    = laser_idx(laser_idx > 1);
            nonlaser_idx = nonlaser_idx(nonlaser_idx > 1);

            if ~isempty(laser_idx)
                m_laser = mean(timestamps(laser_idx) - timestamps(laser_idx-1));
            else, m_laser = NaN; end
            if ~isempty(nonlaser_idx)
                m_nonlaser = mean(timestamps(nonlaser_idx) - timestamps(nonlaser_idx-1));
            else, m_nonlaser = NaN; end

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

        function postLoadRefresh(app)
            T = app.DC.RawTable;
            if isempty(T), return; end
            if any(strcmp(T.Properties.VariableNames, 'AccuracyLaser'))
                app.DC.OutlierMask = app.detectOutliers(T.AccuracyLaser);
            end
            app.initializeFilters();
            app.applyFilter();
            app.renderDashboard();
            if ~isempty(app.DC.SnapshotPath)
                [~, name, ext] = fileparts(app.DC.SnapshotPath);
                app.setStatus(sprintf('Loaded: %s%s', name, ext));
            end
        end
        
        function initializeFilters(app)
            if isempty(app.DC.RawTable), return; end
            T = app.DC.RawTable;
            vars = T.Properties.VariableNames;
            ids = ['All'; unique(string(T.ID))];
            app.AnimalFilterDD.Items = cellstr(ids);
            app.TrendAnimalDD.Items  = cellstr(ids);
            app.ManifoldAnimalDD.Items = cellstr(ids);

            if any(strcmp(vars, 'Angle')) && ~all(isnan(T.Angle))
                ang = ['All'; string(unique(T.Angle(~isnan(T.Angle))))];
                app.AngleFilterDD.Items = cellstr(ang);
            else
                app.AngleFilterDD.Items = {'All'};
            end
            if any(strcmp(vars, 'Power')) && ~all(isnan(T.Power))
                pw = ['All'; string(unique(T.Power(~isnan(T.Power))))];
                app.PowerFilterDD.Items = cellstr(pw);
            else
                app.PowerFilterDD.Items = {'All'};
            end
        end

        function mask = detectOutliers(app, vec)
            vec  = double(vec);
            valid= ~isnan(vec);
            mask = false(size(vec));
            if sum(valid) < 4, return; end
            q1   = prctile(vec(valid), 25);
            q3   = prctile(vec(valid), 75);
            iqr_ = q3 - q1;
            lo   = q1 - app.DC.IQRMultiplier * iqr_;
            hi   = q3 + app.DC.IQRMultiplier * iqr_;
            mask = valid & (vec < lo | vec > hi);
        end

        function applyFilter(app)
            if isempty(app.DC.RawTable)
                uialert(app.UIFigure,'No data loaded.','Filter','Icon','info');
                return;
            end
            T = app.DC.RawTable;

            selID = app.AnimalFilterDD.Value;
            if ~strcmp(selID,'All')
                T = T(strcmp(string(T.ID), selID), :);
            end

            selAng = app.AngleFilterDD.Value;
            if ~strcmp(selAng,'All') && ~all(isnan(T.Angle))
                T = T(T.Angle == str2double(selAng), :);
            end

            selPow = app.PowerFilterDD.Value;
            if ~strcmp(selPow,'All') && ~all(isnan(T.Power))
                T = T(T.Power == str2double(selPow), :);
            end

            if ~isempty(app.DateStartPicker.Value) && ~isnat(app.DateStartPicker.Value)
                dStart = app.DateStartPicker.Value;
                T = T(datetime(string(T.Date),'InputFormat','yyyy-MM-dd') >= dStart, :);
            end
            if ~isempty(app.DateEndPicker.Value) && ~isnat(app.DateEndPicker.Value)
                dEnd = app.DateEndPicker.Value;
                T = T(datetime(string(T.Date),'InputFormat','yyyy-MM-dd') <= dEnd, :);
            end

            app.DC.FilteredTable = T;
            if app.ShowOutliersChk.Value
                app.DC.OutlierMask = app.detectOutliers(T.AccuracyLaser);
            else
                app.DC.OutlierMask = false(height(T),1);
            end
            nOut = sum(app.DC.OutlierMask);
            app.OutlierCountLabel.Text = sprintf('%d outlier(s) in filtered view', nOut);

            app.renderDashboard();
            app.populateRawTable();
            app.setStatus(sprintf('Filter applied: %d records visible.', height(T)));
        end

        function clearFilter(app)
            if isempty(app.DC.RawTable), return; end
            app.AnimalFilterDD.Value = 'All';
            app.AngleFilterDD.Value  = 'All';
            app.PowerFilterDD.Value  = 'All';
            app.DateStartPicker.Value = NaT;
            app.DateEndPicker.Value   = NaT;
            app.DC.FilteredTable = app.DC.RawTable;
            app.DC.OutlierMask   = app.detectOutliers(app.DC.RawTable.AccuracyLaser);
            nOut = sum(app.DC.OutlierMask);
            app.OutlierCountLabel.Text = sprintf('%d outlier session(s) flagged', nOut);
            app.renderDashboard();
            app.populateRawTable();
            app.setStatus(sprintf('Filters cleared. Showing all %d records.', height(app.DC.RawTable)));
        end

    end

    %% ══════════════════════════════════════════════════════════════════════
    %% RENDERING ENGINE
    %% ══════════════════════════════════════════════════════════════════════
    methods (Access = private)

        function renderDashboard(app)
            % 1. Get filtered data
            T = app.DC.FilteredTable;
            %{
            if isempty(T)
                %cla(app.DashAxesPaired);
                %cla(app.DashAxesLatency);
                %cla(app.DashAxesOmission);
                return; 
            end 
            %}
            if any(strcmp(T.Properties.VariableNames, 'Visualize'))
                visStr = string(T.Visualize);
                isKeep = strcmpi(visStr, "true") | (visStr == "1");
                T = T(isKeep, :);
            end
            % If no data matches the filters, clear the labels and stop
            if isempty(T)
                for k = 1:8, app.DashKPILabel{k}.Text = '0'; end
                return; 
            end
            
            % --- LOGIC FOR THE "SELECTED ID" BOX ---
            uniqueIDs = unique(string(T.ID));
            if isscalar(uniqueIDs)
                animalDisplay = uniqueIDs(1);
                % Dynamically shrink font if the ID is a long string
                if strlength(animalDisplay) > 7
                    app.DashKPILabel{2}.FontSize = 14; 
                else
                    app.DashKPILabel{2}.FontSize = 22;
                end
            else
                animalDisplay = 'All';
                app.DashKPILabel{2}.FontSize = 22;
            end

            % --- 1. UPDATE KPI LABELS ---
            kpiVals = { ...
                num2str(height(T)), ...
                animalDisplay, ...
                sprintf('%.1f%%', nanmean(T.AccuracyLaser)), ...
                sprintf('%.1f%%', nanmean(T.AccuracyNonLaser)), ...
                sprintf('%.3f s', nanmean(T.LatencyLaser)), ...
                sprintf('%.3f s', nanmean(T.LatencyNonLaser)), ...
                sprintf('%.1f%%', nanmean(T.oLaserPercent)), ...
                sprintf('%.1f%%', nanmean(T.oNonLaserPercent)) ...
            };
            for k = 1:8
                app.DashKPILabel{k}.Text = kpiVals{k};
            end

            n  = height(T);
            xv = 1:n;

            % --- 2. ACCURACY PLOT (Top Left) ---
            ax = app.DashAxesPaired;
            if isempty(app.GH.DashPairedLines) || isnumeric(app.GH.DashPairedLines) || ~isvalid(app.GH.DashPairedLines(1))
                hold(ax, 'on');
                app.GH.DashPairedLines(1) = plot(ax, xv, T.AccuracyLaser, '-o', ...
                    'Color', app.Colors.LaserBlue, 'LineWidth', 1.4, 'MarkerSize', 4, 'DisplayName', 'Laser');
                app.GH.DashPairedLines(2) = plot(ax, xv, T.AccuracyNonLaser, '-s', ...
                    'Color', app.Colors.CoralRed, 'LineWidth', 1.4, 'MarkerSize', 4, 'DisplayName', 'Non-Laser');
                
                yline(ax, 50, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.8, 'Label', 'Chance');
                legend(ax, 'Location', 'best');
            else
                set(app.GH.DashPairedLines(1), 'XData', xv, 'YData', T.AccuracyLaser);
                set(app.GH.DashPairedLines(2), 'XData', xv, 'YData', T.AccuracyNonLaser);
            end
            xlim(ax, [0 n+1]); ylim(ax, [0 105]);
        
            % --- 3. LATENCY PLOT (Top Right) ---
            ax2 = app.DashAxesLatency;
            if isempty(app.GH.DashLatencyLines) || isnumeric(app.GH.DashLatencyLines) || ~isvalid(app.GH.DashLatencyLines(1))
                hold(ax2, 'on');
                app.GH.DashLatencyLines(1) = plot(ax2, xv, T.LatencyLaser, '-o', ...
                    'Color', app.Colors.LaserBlue, 'LineWidth', 1.2, 'MarkerSize', 4, 'DisplayName', 'Laser');
                app.GH.DashLatencyLines(2) = plot(ax2, xv, T.LatencyNonLaser, '-s', ...
                    'Color', app.Colors.CoralRed, 'LineWidth', 1.2, 'MarkerSize', 4, 'DisplayName', 'Non-Laser');
                
                grid(ax2, 'on');
                legend(ax2, 'Location', 'best');
            else
                set(app.GH.DashLatencyLines(1), 'XData', xv, 'YData', T.LatencyLaser);
                set(app.GH.DashLatencyLines(2), 'XData', xv, 'YData', T.LatencyNonLaser);
            end
            xlim(ax2, [0 n+1]);
            if ~isempty(T.LatencyLaser)
                maxLat = max([nanmax(T.LatencyLaser), nanmax(T.LatencyNonLaser)]);
                ylim(ax2, [0 max([0.5, maxLat * 1.2])]); 
            end
        
            % --- 4. OMISSION PLOT (Bottom Left) ---
            ax3 = app.DashAxesOmission;
            if isempty(app.GH.DashOmissionLines) || isnumeric(app.GH.DashOmissionLines) || ~isvalid(app.GH.DashOmissionLines(1))
                hold(ax3, 'on');
                app.GH.DashOmissionLines(1) = plot(ax3, xv, T.oLaserPercent, '-o', ...
                    'Color', app.Colors.LaserBlue, 'LineWidth', 1.2, 'MarkerSize', 4, 'DisplayName', 'Laser');
                app.GH.DashOmissionLines(2) = plot(ax3, xv, T.oNonLaserPercent, '-s', ...
                    'Color', app.Colors.CoralRed, 'LineWidth', 1.2, 'MarkerSize', 4, 'DisplayName', 'Non-Laser');
                
                yline(ax3, 0, '-', 'Color', [0.8 0.8 0.8]); 
                grid(ax3, 'on');
                legend(ax3, 'Location', 'best');
            else
                set(app.GH.DashOmissionLines(1), 'XData', xv, 'YData', T.oLaserPercent);
                set(app.GH.DashOmissionLines(2), 'XData', xv, 'YData', T.oNonLaserPercent);
            end
            xlim(ax3, [0 n+1]); ylim(ax3, [0 105]);
        end

        function populateRawTable(app)
            T = app.DC.FilteredTable;
            if isempty(T), return; end
            Tdisp = T;
            outlierFlag = repmat({''},height(T),1);
            outlierFlag(app.DC.OutlierMask) = {'⚠ Outlier'};
            Tdisp.Flag = outlierFlag;

            app.RawTable.Data = Tdisp;
            app.RawTable.ColumnName = Tdisp.Properties.VariableNames;

            if any(app.DC.OutlierMask)
                s = uistyle('BackgroundColor', [1.0 0.92 0.90]);
                addStyle(app.RawTable, s, 'row', find(app.DC.OutlierMask));
            end
        end

        function onRawTableSelect(app, event)
            if isempty(event.Indices), return; end
            rowIdx = event.Indices(1,1);
            T      = app.DC.FilteredTable;
            if rowIdx > height(T), return; end
            row    = T(rowIdx,:);

            ax  = app.RawDetailAxes;
            cla(ax);
            vals = [row.AccuracyLaser, row.AccuracyNonLaser];
            b = bar(ax, [1 2], vals, 'FaceColor','flat');
            b.CData = [app.Colors.LaserBlue; app.Colors.CoralRed];
            ax.XTickLabel = {'Laser','Non-Laser'};
            ylabel(ax,'Accuracy (%)');
            ylim(ax,[0 105]);
            title(ax, sprintf('Accuracy — %s (%s)', string(row.ID), string(row.Date)));

            ax2 = app.RawDetailAxes2;
            cla(ax2);
            vals2 = [row.LatencyLaser, row.LatencyNonLaser];
            b2 = bar(ax2, [1 2], vals2, 'FaceColor','flat');
            b2.CData = [app.Colors.LaserBlue; app.Colors.CoralRed];
            ax2.XTickLabel = {'Laser','Non-Laser'};
            ylabel(ax2,'Latency (s)');
            title(ax2, sprintf('First-Lick Latency — %s (%s)', string(row.ID), string(row.Date)));
        end

        function renderTrend(app)
            if isempty(app.DC.FilteredTable), return; end
            T       = app.DC.FilteredTable;
            animal  = app.TrendAnimalDD.Value;
            metric  = app.TrendMetricDD.Value;
            smoothN = round(app.TrendSmoothSlider.Value);
            app.TrendSmoothLabel.Text = num2str(smoothN);

            if ~strcmp(animal,'All')
                T = T(strcmp(string(T.ID), animal), :);
            end
            if height(T) < 2, return; end

            T = sortrows(T, 'Date');
            try
                dates = datetime(string(T.Date), 'InputFormat','yyyy-MM-dd');
            catch
                dates = (1:height(T))';
            end

            vals  = double(T.(metric));
            valid = ~isnan(vals);
            smoothed = movmean(vals, smoothN, 'omitnan');

            ax  = app.TrendAxes;
            ax2 = app.TrendAxes2;

            if isempty(app.GH.TrendLaserLine)
                hold(ax,'on');
                l1 = plot(ax, dates(valid), vals(valid), 'o', ...
                    'Color', app.Colors.LaserBlue, 'MarkerSize',5, ...
                    'MarkerFaceColor', app.Colors.LaserBlue, 'DisplayName','Raw');
                l2 = plot(ax, dates, smoothed, '-', ...
                    'Color', app.Colors.LaserBlue, 'LineWidth',2.0, ...
                    'DisplayName', sprintf('Moving Avg (n=%d)',smoothN));
                se  = nanstd(vals) / sqrt(sum(valid));
                xx  = [dates; flipud(dates)];
                yy  = [smoothed+se; flipud(smoothed-se)];
                l3  = fill(ax, xx, yy, app.Colors.LaserBlue, ...
                    'FaceAlpha',0.15, 'EdgeColor','none', 'DisplayName','±SEM');
                legend(ax,'Location','best');
                app.GH.TrendLaserLine    = l1;
                app.GH.TrendNonLaserLine = l2;
                app.GH.TrendSmooth       = l3;
            else
                set(app.GH.TrendLaserLine,    'XData', dates(valid), 'YData', vals(valid));
                set(app.GH.TrendNonLaserLine, 'XData', dates,        'YData', smoothed);
            end

            xlabel(ax,'Session Date'); ylabel(ax, strrep(metric,'_',' '));
            title(ax, sprintf('Learning Curve — %s (%s)', metric, animal));

            delta = diff(vals);
            cla(ax2); hold(ax2,'on');
            posIdx = delta >= 0;
            negIdx = ~posIdx;
            ddates = dates(2:end);
            if any(posIdx)
                bar(ax2, ddates(posIdx), delta(posIdx), 'FaceColor', app.Colors.ForestGreen, ...
                    'EdgeColor','none', 'FaceAlpha',0.8);
            end
            if any(negIdx)
                bar(ax2, ddates(negIdx), delta(negIdx), 'FaceColor', app.Colors.BurntSienna, ...
                    'EdgeColor','none', 'FaceAlpha',0.8);
            end
            yline(ax2, 0, 'k--', 'LineWidth',0.8);
            xlabel(ax2,'Session Date'); ylabel(ax2,'Δ Value');
            title(ax2,'Session-to-Session Change');

            app.TrendStatsLabel.Text = sprintf( ...
                'n=%d valid sessions  |  Mean=%.2f  |  SD=%.2f  |  Min=%.2f  |  Max=%.2f  |  Linear trend slope=%.4f', ...
                sum(valid), nanmean(vals), nanstd(vals), nanmin(vals), nanmax(vals), ...
                app.computeSlope(1:height(T), vals));
        end

        function renderManifold(app)
            if isempty(app.DC.FilteredTable), return; end
            T      = app.DC.FilteredTable;
            animal = app.ManifoldAnimalDD.Value;
            metric = app.ManifoldMetricDD.Value;
            cmap   = app.ManifoldColorDD.Value;

            if ~strcmp(animal,'All')
                T = T(strcmp(string(T.ID), animal), :);
            end

            hasAngle = any(~isnan(T.Angle));
            hasPower = any(~isnan(T.Power));

            ax = app.ManifoldAxes;
            cla(ax); hold(ax,'on'); view(ax,-35,30);

            if ~hasAngle || ~hasPower
                app.ManifoldInfoLabel.Visible = 'on';
                n  = height(T);
                xv = (1:n)';
                yv = zeros(n,1);

                if strcmp(metric,'DeltaAccuracy')
                    zv = T.AccuracyLaser - T.AccuracyNonLaser;
                else
                    zv = T.(metric);
                end
                valid = ~isnan(zv);
                scatter3(ax, xv(valid), yv(valid), zv(valid), 50, zv(valid), 'filled');
                xlabel(ax,'Session Index'); ylabel(ax,'(No Power data)');
                zlabel(ax, strrep(metric,'_',' '));
                colormap(ax, cmap); colorbar(ax);
                title(ax,'Performance over Sessions (Assign Angle/Power for full manifold)');
                return;
            end

            app.ManifoldInfoLabel.Visible = 'off';

            if strcmp(metric,'DeltaAccuracy')
                zData = T.AccuracyLaser - T.AccuracyNonLaser;
                zLabel= 'Δ Accuracy (Laser − Non-Laser)';
            else
                zData = T.(metric);
                zLabel= strrep(metric,'_',' ');
            end

            xData = T.Angle;
            yData = T.Power;
            valid = ~isnan(xData) & ~isnan(yData) & ~isnan(zData);
            xv = xData(valid); yv = yData(valid); zv = zData(valid);

            if numel(unique(xv)) < 3 || numel(unique(yv)) < 3
                scatter3(ax, xv, yv, zv, 60, zv, 'filled', 'MarkerEdgeColor','none');
                xlabel(ax,'Angle (°)'); ylabel(ax,'Power (mW)'); zlabel(ax,zLabel);
                colormap(ax,cmap); colorbar(ax);
                title(ax,sprintf('%s Surface — Insufficient grid points (showing scatter)', metric));
                return;
            end

            xi = linspace(min(xv), max(xv), 50);
            yi = linspace(min(yv), max(yv), 50);
            [XI,YI] = meshgrid(xi, yi);

            try
                ZI = griddata(xv, yv, zv, XI, YI, 'natural');
            catch
                ZI = griddata(xv, yv, zv, XI, YI, 'linear');
            end

            s = surf(ax, XI, YI, ZI, 'EdgeColor','none', 'FaceAlpha',0.85);
            colormap(ax, cmap);
            colorbar(ax, 'Label', zLabel);
            clim(ax, [nanmin(zv) nanmax(zv)]);

            scatter3(ax, xv, yv, zv, 50, 'k', 'filled', 'MarkerEdgeColor','w', 'LineWidth',0.5);

            xlabel(ax,'Angle (°)'); ylabel(ax,'Power (mW)'); zlabel(ax,zLabel);
            title(ax, sprintf('3D Performance Manifold — %s (%s)', metric, animal));
            shading(ax,'interp');
            lighting(ax,'gouraud');
            light(ax,'Position',[1 1 2]);

            app.GH.ManifoldSurf = s;
        end

        function runStatTest(app)
            if isempty(app.DC.FilteredTable)
                uialert(app.UIFigure,'No data loaded.','Statistics','Icon','info');
                return;
            end
            T    = app.DC.FilteredTable;
            test = app.StatTestDD.Value;

            app.StatOutlierTable.Visible = 'off';
            app.StatTextArea.Visible     = 'on';

            try
                switch test
                    case 'Paired t-test (Laser vs Non-Laser)'
                        app.runPairedTtest(T);
                    case 'One-way ANOVA by Animal'
                        app.runANOVA(T, 'ID');
                    case 'One-way ANOVA by Power'
                        app.runANOVA(T, 'Power');
                    case 'IQR Outlier Report'
                        app.runOutlierReport(T);
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'Statistics Error','Icon','error');
            end
        end

        function runPairedTtest(app, T)
            L  = double(T.AccuracyLaser);
            NL = double(T.AccuracyNonLaser);
            valid = ~isnan(L) & ~isnan(NL);
            Lv = L(valid); NLv = NL(valid);

            if sum(valid) < 3
                app.StatTextArea.Value = string({'Not enough valid paired observations (need ≥ 3).'});
                return;
            end

            [h, p, ci, stats] = ttest(Lv, NLv);
            diffs  = Lv - NLv;
            sem_   = std(diffs) / sqrt(numel(diffs));
            meanD  = mean(diffs);
            cohend = meanD / std(diffs);

            % Handle edge cases for Cohen's d
            if isnan(cohend) || isinf(cohend)
                cohend = 0;  % Set to 0 for undefined cases
                cohendLabel = 'undefined';
            else
                cohendLabel = app.cohenLabel(abs(cohend));
            end

            ax = app.StatAxes1;
            cla(ax); hold(ax,'on');
            boxplot(ax, [Lv, NLv], {'Laser','Non-Laser'}, ...
                'Colors', [app.Colors.LaserBlue; app.Colors.CoralRed], ...
                'Symbol', 'r+', 'Widths', 0.5);
            scatter(ax, ones(numel(Lv),1)  + randn(numel(Lv),1)*0.05, Lv,  ...
                20, app.Colors.LaserBlue,'filled','MarkerFaceAlpha',0.5);
            scatter(ax, 2*ones(numel(NLv),1)+randn(numel(NLv),1)*0.05, NLv, ...
                20, app.Colors.CoralRed,'filled','MarkerFaceAlpha',0.5);
            ylabel(ax,'Accuracy (%)');
            title(ax, sprintf('Distribution (p = %.4f)', p));
            ylim(ax,[0 110]); grid(ax,'on');

            ax2 = app.StatAxes2;
            cla(ax2); hold(ax2,'on');
            scatter(ax2, 1:numel(diffs), diffs, 30, app.Colors.LaserBlue, 'filled', 'MarkerFaceAlpha',0.7);
            yline(ax2, 0,       'k--', 'LineWidth',1.2);
            yline(ax2, meanD,   'Color',app.Colors.BurntSienna, 'LineWidth',1.5,'Label',sprintf('Mean Δ = %.2f',meanD));
            yline(ax2, meanD+1.96*sem_, ':', 'Color',[0.5 0.5 0.5], 'Label','±1.96 SEM');
            yline(ax2, meanD-1.96*sem_, ':', 'Color',[0.5 0.5 0.5]);
            xlabel(ax2,'Session'); ylabel(ax2,'Laser − Non-Laser (%)');
            title(ax2,'Paired Difference');

            lines = { ...
                '═══════════════════════════════════════════════', ...
                '  Paired t-Test: AccuracyLaser vs AccuracyNonLaser', ...
                '═══════════════════════════════════════════════', ...
                sprintf('  n (valid pairs)     = %d', sum(valid)), ...
                sprintf('  Mean Laser          = %.3f ± %.3f %%  (mean ± SEM)', nanmean(Lv), std(Lv)/sqrt(numel(Lv))), ...
                sprintf('  Mean Non-Laser      = %.3f ± %.3f %%  (mean ± SEM)', nanmean(NLv), std(NLv)/sqrt(numel(NLv))), ...
                sprintf('  Mean Difference (L-NL) = %.3f %%', meanD), ...
                sprintf('  SEM of Difference   = %.3f %%', sem_), ...
                sprintf('  95%% CI of Diff     = [%.3f, %.3f]', ci(1), ci(2)), ...
                sprintf('  t-statistic         = %.4f', stats.tstat), ...
                sprintf('  degrees of freedom  = %d', stats.df), ...
                sprintf('  p-value             = %.6f  (%s)', p, ternaryStr(h,'SIGNIFICANT','not significant')), ...
                sprintf("  Cohen's d           = %.3f  (%s)", cohend, cohendLabel), ...
                '───────────────────────────────────────────────', ...
                '  Formulas used:', ...
                '    SEM = SD / sqrt(n)', ...
                '    t   = mean(D) / (SD(D)/sqrt(n))', ...
                sprintf("    Cohen's d = mean(D) / SD(D)"), ...
                '═══════════════════════════════════════════════' ...
            };
            app.StatTextArea.Value = string(lines);
        end

        function runANOVA(app, T, groupVar)
            if ~ismember(groupVar, T.Properties.VariableNames)
                app.StatTextArea.Value = string({sprintf('Column "%s" not found in data.',groupVar)});
                return;
            end
            vals  = double(T.AccuracyLaser);
            grps  = string(T.(groupVar));
            valid = ~isnan(vals) & ~ismissing(grps) & grps ~= "NaN";
            vals  = vals(valid); grps = grps(valid);

            if numel(unique(grps)) < 2
                app.StatTextArea.Value = string({'Need ≥ 2 groups for ANOVA.'});
                return;
            end

            [p, tbl, stats] = anova1(vals, grps, 'off');
            c = multcompare(stats, 'Display','off');

            ax = app.StatAxes1; cla(ax);
            boxplot(ax, vals, grps, 'Symbol','r+', 'Widths',0.5);
            ylabel(ax,'AccuracyLaser (%)');
            title(ax, sprintf('One-way ANOVA by %s (p = %.4f)',groupVar,p));
            xtickangle(ax,30); grid(ax,'on');

            ax2 = app.StatAxes2; cla(ax2); hold(ax2,'on');
            ugrps = unique(grps,'stable');
            gMeans = arrayfun(@(g) nanmean(vals(grps==g)), ugrps);
            gSEM   = arrayfun(@(g) nanstd(vals(grps==g))/sqrt(sum(grps==g)), ugrps);
            errorbar(ax2, 1:numel(ugrps), gMeans, gSEM, 'o', ...
                'Color',app.Colors.LaserBlue,'LineWidth',1.5,'MarkerSize',7, ...
                'MarkerFaceColor',app.Colors.LaserBlue);
            xticks(ax2,1:numel(ugrps)); xticklabels(ax2,ugrps);
            xtickangle(ax2,30); ylabel(ax2,'Mean ± SEM');
            title(ax2,'Group Means ± SEM');

            lines = { ...
                '═══════════════════════════════════════════════', ...
                sprintf('  One-Way ANOVA: AccuracyLaser by %s', groupVar), ...
                '═══════════════════════════════════════════════', ...
                sprintf('  p-value   = %.6f (%s)', p, ternaryStr(p<0.05,'SIGNIFICANT','not significant')), ...
                sprintf('  F-stat    = %.4f', tbl{2,5}), ...
                sprintf('  df_group  = %d   df_error = %d', tbl{2,3}, tbl{3,3}), ...
                sprintf('  SS_group  = %.4f  SS_error = %.4f', tbl{2,2}, tbl{3,2}), ...
                '───────────────────────────────────────────────', ...
                '  Post-hoc Tukey HSD (all pairs):', ...
            };
            for k = 1:size(c,1)
                sig = ternaryStr(c(k,6)<0.05,'*','ns');
                lines{end+1} = sprintf('    %s vs %s : p=%.4f  [%.2f, %.2f] %s', ...
                    ugrps{c(k,1)}, ugrps{c(k,2)}, c(k,6), c(k,3), c(k,5), sig); %#ok<AGROW>
            end
            lines{end+1} = '═══════════════════════════════════════════════';
            app.StatTextArea.Value = string(lines);
        end

        function runOutlierReport(app, T)
            app.StatTextArea.Visible     = 'off';
            app.StatOutlierTable.Visible = 'on';

            numCols = {'AccuracyLaser','AccuracyNonLaser', ...
                       'LatencyLaser','LatencyNonLaser', ...
                       'oLaserPercent','oNonLaserPercent'};
            numCols = numCols(ismember(numCols, T.Properties.VariableNames));

            allOutliers = {};
            for k = 1:numel(numCols)
                col   = numCols{k};
                mask  = app.detectOutliers(double(T.(col)));
                idxs  = find(mask);
                for j = 1:numel(idxs)
                    r = idxs(j);
                    allOutliers(end+1,:) = { ...
                        char(string(T.ID(r))), ...
                        char(string(T.Date(r))), ...
                        col, ...
                        round(double(T.(col)(r)),3), ...
                        sprintf('IQR×%.1f', app.DC.IQRMultiplier) ...
                    }; %#ok<AGROW>
                end
            end

            if isempty(allOutliers)
                app.StatOutlierTable.Data = {'No outliers detected at IQR×1.5 threshold.'};
                app.StatOutlierTable.ColumnName = {'Result'};
            else
                app.StatOutlierTable.Data = allOutliers;
                app.StatOutlierTable.ColumnName = {'ID','Date','Column','Value','Method'};
            end

            ax = app.StatAxes1; cla(ax);
            nCols = numel(numCols);
            data  = zeros(height(T), nCols);
            for k = 1:nCols, data(:,k) = double(T.(numCols{k})); end
            boxplot(ax, data, numCols, 'Symbol','r+', 'Widths',0.5);
            xtickangle(ax,25);
            title(ax,'All Metrics — Boxplot with Outlier Markers');
            grid(ax,'on');

            cla(app.StatAxes2);
            title(app.StatAxes2, sprintf('%d total outlier observations flagged', size(allOutliers,1)));
        end

        function loadReplayFile(app)
            [f,p] = uigetfile('*', 'Select raw LabView file (no extension)');
            if isequal(f,0), return; end
            app.setStatus('Loading replay file…');
            try
                fpath = fullfile(p,f);
                opts  = detectImportOptions(fpath);
                opts.VariableNamingRule = 'preserve';
                datab = table2array(readtable(fpath, opts));

                app.DC.ReplayData  = struct('raw', datab, 'filename', f);
                app.DC.ReplayIndex = 1;

                app.drawReplayFrame(1);
                app.ReplayPlayBtn.Enable = 'on';
                app.ReplaySlider.Limits  = [1 size(datab,1)];
                app.ReplaySlider.Value   = 1;
                app.ReplaySlider.Enable  = 'on';
                app.ReplayInfoLabel.Text = sprintf('Loaded: %s  |  %d rows', f, size(datab,1));
                app.setStatus(sprintf('Replay loaded: %s', fpath));
            catch ME
                uialert(app.UIFigure, ME.message, 'Replay Error','Icon','error');
                app.setStatus('Replay load failed.');
            end
        end

        function drawReplayFrame(app, upToRow)
            if isempty(app.DC.ReplayData), return; end
            datab    = app.DC.ReplayData.raw;
            upToRow  = min(upToRow, size(datab,1));
            ax       = app.ReplayAxes;
            cla(ax); hold(ax,'on');

            ts  = datab(1:upToRow, 1);
            channels = datab(1:upToRow, 2:7);

            chanColors = { ...
                app.Colors.Teal, ...
                app.Colors.Purple, ...
                app.Colors.Magenta, ...
                app.Colors.Gold, ...
                app.Colors.LimeGreen, ...
                app.Colors.Cyan ...
            };

            for ch = 1:6
                mask = channels(:,ch) == 1;
                if any(mask)
                    scatter(ax, ts(mask), ch*ones(sum(mask),1), 10, ...
                        chanColors{ch}, 'filled', 'MarkerFaceAlpha', 0.8);
                end
            end

            if upToRow <= size(datab,1)
                xline(ax, datab(upToRow,1), '--', 'Color',[1 1 0.4], 'LineWidth',1.5);
            end

            xlim(ax, [datab(1,1), datab(end,1)]);
            ylim(ax, [0.5 7.5]);
            xlabel(ax,'Time (s)','Color',[0.7 0.7 0.8]);
            title(ax, sprintf('Trial Replay — %s  (row %d / %d)', ...
                app.DC.ReplayData.filename, upToRow, size(datab,1)), ...
                'Color',[0.9 0.9 0.95]);
        end

        function startReplay(app)
            if isempty(app.DC.ReplayData), return; end
            app.stopReplay();
            speeds   = [0.25, 0.5, 1, 2, 5];
            speedStrs= {'0.25×','0.5×','1×','2×','5×'};
            spd      = speeds(strcmp(app.ReplaySpeedDD.Value, speedStrs));
            stepInterval = 0.05 / spd;

            app.ReplayPlayBtn.Enable = 'off';
            app.ReplayStopBtn.Enable = 'on';
            app.DC.ReplayIndex       = 1;

            nRows = size(app.DC.ReplayData.raw, 1);
            stepSize = max(1, round(nRows / 500));

            app.ReplayTimer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period',        stepInterval, ...
                'TimerFcn',      @(~,~) app.replayTick(stepSize, nRows));
            start(app.ReplayTimer);
        end

        function replayTick(app, stepSize, nRows)
            app.DC.ReplayIndex = app.DC.ReplayIndex + stepSize;
            if app.DC.ReplayIndex > nRows
                app.stopReplay(); return;
            end
            app.drawReplayFrame(app.DC.ReplayIndex);
            app.ReplaySlider.Value = app.DC.ReplayIndex;
        end

        function stopReplay(app)
            if ~isempty(app.ReplayTimer) && isvalid(app.ReplayTimer)
                stop(app.ReplayTimer);
                delete(app.ReplayTimer);
            end
            app.ReplayPlayBtn.Enable = 'on';
            app.ReplayStopBtn.Enable = 'off';
        end

        function scrubReplay(app, val)
            if isempty(app.DC.ReplayData), return; end
            app.DC.ReplayIndex = round(val);
            app.drawReplayFrame(app.DC.ReplayIndex);
        end

    end

    %% ══════════════════════════════════════════════════════════════════════
    %% REPORT GENERATOR
    %% ══════════════════════════════════════════════════════════════════════
    methods (Access = private)

        function exportReport(app)
            if isempty(app.DC.FilteredTable)
                uialert(app.UIFigure,'No data loaded.','Export','Icon','info');
                return;
            end

            [fName, fPath] = uiputfile( ...
                {'*.pdf','PDF Report (*.pdf)'; '*.xlsx','Excel Summary (*.xlsx)'}, ...
                'Export Report As…', 'SoundLoc_Report');
            if isequal(fName,0), return; end

            app.setStatus('Generating report…');
            T     = app.DC.FilteredTable;
            fFull = fullfile(fPath, fName);
            [~,~,ext] = fileparts(fName);

            try
                switch lower(ext)
                    case '.pdf'
                        app.exportPDF(fFull, T);
                    case '.xlsx'
                        app.exportExcel(fFull, T);
                    otherwise
                        app.exportPDF(fFull, T);
                end
                uialert(app.UIFigure, ...
                    sprintf('Report saved:\n%s', fFull), ...
                    'Export Complete','Icon','success');
                app.setStatus(sprintf('Report exported: %s', fFull));
            catch ME
                uialert(app.UIFigure, ME.message, 'Export Error','Icon','error');
                app.setStatus('Export failed.');
            end
        end

        function exportPDF(app, outPath, T)
            fig = figure('Visible','off','Units','inches', ...
                'Position',[0 0 11 8.5], 'PaperSize',[11 8.5], ...
                'PaperPositionMode','auto');
            tl = tiledlayout(fig, 2, 3, 'Padding','compact','TileSpacing','compact');
            title(tl, sprintf('Sound Localization Report — %s', ...
                char(datetime('now','Format','yyyy-MM-dd'))), ...
                'FontSize',14,'FontWeight','bold');

            ax1 = nexttile(tl);
            L  = double(T.AccuracyLaser);
            NL = double(T.AccuracyNonLaser);
            hold(ax1,'on');
            plot(ax1, 1:height(T), L,  '-o','Color',app.Colors.LaserBlue,'LineWidth',1.2,'DisplayName','Laser');
            plot(ax1, 1:height(T), NL, '-s','Color',app.Colors.CoralRed,'LineWidth',1.2,'DisplayName','Non-Laser');
            yline(ax1,50,'--','Color',[0.6 0.6 0.6],'Label','Chance');
            xlabel(ax1,'Session'); ylabel(ax1,'Accuracy (%)');
            title(ax1,'Paired Accuracy'); legend(ax1,'Location','best'); ylim(ax1,[0 105]);

            ax2 = nexttile(tl);
            hold(ax2,'on');
            plot(ax2, 1:height(T), T.LatencyLaser, '-o','Color',app.Colors.LaserBlue,'LineWidth',1.2);
            plot(ax2, 1:height(T), T.LatencyNonLaser,'-s','Color',app.Colors.CoralRed,'LineWidth',1.2);
            xlabel(ax2,'Session'); ylabel(ax2,'Latency (s)');
            title(ax2,'First-Lick Latency'); legend({'Laser','Non-Laser'},'Location','best');

            ax3 = nexttile(tl);
            hold(ax3,'on');
            area(ax3, 1:height(T), T.oLaserPercent, ...
                'FaceColor',app.Colors.BurntSienna,'FaceAlpha',0.6,'EdgeColor','none');
            xlabel(ax3,'Session'); ylabel(ax3,'%');
            title(ax3,'Omission Rate (Laser)');

            ax4 = nexttile(tl);
            valid = ~isnan(L) & ~isnan(NL);
            boxplot(ax4, [L(valid), NL(valid)], {'Laser','Non-Laser'}, ...
                'Colors',[app.Colors.LaserBlue; app.Colors.CoralRed], ...
                'Symbol','r+','Widths',0.5);
            ylabel(ax4,'Accuracy (%)'); title(ax4,'Distribution Comparison');
            grid(ax4,'on');

            ax5 = nexttile(tl);
            hold(ax5,'on');
            IDs = unique(string(T.ID));
            baseColors = [app.Colors.LaserBlue; app.Colors.CoralRed; ...
                         app.Colors.ForestGreen; app.Colors.BurntSienna; ...
                         app.Colors.Teal; app.Colors.Purple];  % Extended palette
            for k = 1:numel(IDs)
                sub = T(strcmp(string(T.ID),IDs(k)),:);
                sub = sortrows(sub,'Date');
                idxColor = mod(k-1,size(baseColors,1))+1; % Cycle through colors
                plot(ax5, 1:height(sub), movmean(sub.AccuracyLaser,3,'omitnan'), ...
                    '-','Color',baseColors(idxColor,:),'LineWidth',1.2,'DisplayName',IDs{k});
            end
            xlabel(ax5,'Session'); ylabel(ax5,'AccuracyLaser (%)');
            title(ax5,'Learning Curves by Animal'); legend(ax5,'Location','best');
            ylim(ax5,[0 105]);

            ax6 = nexttile(tl);
            axis(ax6,'off');
            text(ax6, 0.05, 0.95, sprintf( ...
                'SUMMARY STATISTICS\n\nN sessions: %d\nN animals: %d\n\nAccuracy Laser\n  Mean ± SEM: %.2f ± %.2f %%\n\nAccuracy Non-Laser\n  Mean ± SEM: %.2f ± %.2f %%\n\nLatency Laser\n  Mean ± SEM: %.3f ± %.3f s\n\nOmission Rate (Laser)\n  Mean ± SEM: %.2f ± %.2f %%', ...
                height(T), numel(unique(string(T.ID))), ...
                nanmean(L), nanstd(L)/sqrt(sum(~isnan(L))), ...
                nanmean(NL), nanstd(NL)/sqrt(sum(~isnan(NL))), ...
                nanmean(T.LatencyLaser), nanstd(T.LatencyLaser)/sqrt(sum(~isnan(T.LatencyLaser))), ...
                nanmean(T.oLaserPercent), nanstd(T.oLaserPercent)/sqrt(sum(~isnan(T.oLaserPercent)))), ...
                'Units','normalized','VerticalAlignment','top', ...
                'FontName','Courier New','FontSize',9);

            exportgraphics(fig, outPath, 'ContentType','vector','Resolution',300);
            close(fig);
        end

        function exportExcel(~, outPath, T)
            writetable(T, outPath, 'Sheet','All Sessions');

            IDs = unique(string(T.ID));
            summRows = cell(numel(IDs),1);
            for k = 1:numel(IDs)
                sub = T(strcmp(string(T.ID),IDs(k)),:);
                summRows{k} = table( ...
                    IDs(k), height(sub), ...
                    nanmean(sub.AccuracyLaser), nanstd(sub.AccuracyLaser)/sqrt(height(sub)), ...
                    nanmean(sub.AccuracyNonLaser), nanstd(sub.AccuracyNonLaser)/sqrt(height(sub)), ...
                    nanmean(sub.LatencyLaser), nanmean(sub.oLaserPercent), ...
                    'VariableNames', {'ID','N','MeanAccL','SEM_AccL','MeanAccNL','SEM_AccNL','MeanLatL','MeanOmissL'});
            end
            summTable = vertcat(summRows{:});
            writetable(summTable, outPath, 'Sheet','Animal Summary');
        end

    end

    %% ══════════════════════════════════════════════════════════════════════
    %% UTILITY HELPER METHODS
    %% ══════════════════════════════════════════════════════════════════════
    methods (Access = private)

        function setStatus(app, msg)
            app.StatusBar.Text = sprintf('  %s', msg);
            drawnow limitrate;
        end

        function highlightNav(app, idx)
            for i = 1:6
                if i == idx
                    app.NavButtons{i}.BackgroundColor = [0.204 0.596 0.859];
                    app.NavButtons{i}.FontWeight       = 'bold';
                else
                    app.NavButtons{i}.BackgroundColor = app.Colors.Sidebar;
                    app.NavButtons{i}.FontWeight       = 'normal';
                end
            end
        end

        function onNavButton(app, index)
            switch index
                case 1, app.TabGroup.SelectedTab = app.Tab1;
                case 2, app.TabGroup.SelectedTab = app.Tab2;
                case 3, app.TabGroup.SelectedTab = app.Tab3;
                case 4, app.TabGroup.SelectedTab = app.Tab4;
                case 5, app.TabGroup.SelectedTab = app.Tab5;
                case 6, app.TabGroup.SelectedTab = app.Tab6;
            end
            app.highlightNav(index);
        end

        function onTabChanged(app, event)
            tabs = app.TabGroup.Children;
            for k = 1:numel(tabs)
                if tabs(k) == event.NewValue
                    app.highlightNav(k);
                    switch k
                        case 3, app.renderTrend();
                    end
                    break;
                end
            end
        end

        function onResize(app)
            fW = app.UIFigure.Position(3);
            fH = app.UIFigure.Position(4);
            SW = app.Geo.SideW; SH = app.Geo.StatusH;
            W  = fW - SW;
            app.WorkspacePanel.Position = [SW+1 SH+1 W fH-SH];
            app.StatusBar.Position      = [SW+1 1 W SH];
            app.SidebarPanel.Position   = [1 1 SW fH];
        end

        function s = computeSlope(~, x, y)
            valid = ~isnan(y(:));
            xv = x(valid); yv = y(valid);
            if numel(xv) < 2, s = NaN; return; end
            p = [xv(:), ones(numel(xv),1)] \ yv(:);
            s = p(1);
        end

        function lbl = cohenLabel(~, d)
            if d < 0.2,      lbl = 'negligible';
            elseif d < 0.5,  lbl = 'small';
            elseif d < 0.8,  lbl = 'medium';
            else,             lbl = 'large';
            end
        end

        function snapshotPath = findSnapshotAutomatically(~)
            guiFolder    = fileparts(mfilename('fullpath'));
            candidatePath = fullfile(guiFolder, 'Batch_Analysis_Results_Snapshot.mat');
            if isfile(candidatePath)
                snapshotPath = candidatePath;
            else
                snapshotPath = '';
            end
        end

        function loadSnapshotFromPath(app, snapshotPath)
            app.setStatus('Loading data...');
            try
                S = load(snapshotPath, 'T', 'lastUpdated');
                if ~isfield(S, 'T')
                    error('Variable T not found in snapshot file.');
                end
                app.DC.RawTable      = S.T;
                app.DC.FilteredTable = S.T;
                app.DC.SnapshotPath  = snapshotPath;
                app.DC.LastUpdated   = S.lastUpdated;
                app.postLoadRefresh();
                app.setStatus(sprintf('Loaded: %s  |  %s  |  %d records', ...
                    snapshotPath, ...
                    char(S.lastUpdated, 'yyyy-MM-dd HH:mm'), ...
                    height(S.T)));
            catch ME
                uialert(app.UIFigure, ME.message, 'Load Error', 'Icon', 'error');
                app.setStatus('Load failed.');
            end
        end

    end

    %% ══════════════════════════════════════════════════════════════════════
    %% APP CONSTRUCTOR / DESTRUCTOR
    %% ══════════════════════════════════════════════════════════════════════
    methods (Access = public)

        function app = SoundLocalizationGUI(snapshotPath)
            app.buildUI();
            registerApp(app, app.UIFigure);
            app.UIFigure.Visible = 'on';

            if nargin == 0 || isempty(snapshotPath)
                snapshotPath = app.findSnapshotAutomatically();
            end

            if ~isempty(snapshotPath) && isfile(snapshotPath)
                app.loadSnapshotFromPath(snapshotPath);
            end

            if nargout == 0
                clear app;
            end
        end

        function delete(app)
            if ~isempty(app.ReplayTimer) && isvalid(app.ReplayTimer)
                stop(app.ReplayTimer);
                delete(app.ReplayTimer);
            end
            delete(app.UIFigure);
        end

    end

end

%% ══════════════════════════════════════════════════════════════════════════
%% PACKAGE-LEVEL HELPERS
%% ══════════════════════════════════════════════════════════════════════════

function v = ternary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function v = ternaryStr(cond, a, b)
    if cond, v = a; else, v = b; end
end
classdef SoundLoc_TestSuite < matlab.unittest.TestCase
% =========================================================================
% SoundLoc_TestSuite.m
%
% Automated unit testing suite for the Sound Localization data engine.
% Implements:
%   1. Golden-standard synthetic dataset comparison against known outputs
%   2. Boundary value analysis for every documented edge case
%   3. Data integrity synchronization checker (xlsx <-> .mat snapshot)
%   4. Performance benchmarks aligned to the three-phase build roadmap
%
% Run the full suite:
%   results = runtests('SoundLoc_TestSuite');
%   rt = table(results);
%
% Run a specific category:
%   runtests('SoundLoc_TestSuite', 'Tag', 'golden')
%   runtests('SoundLoc_TestSuite', 'Tag', 'boundary')
%   runtests('SoundLoc_TestSuite', 'Tag', 'integrity')
%   runtests('SoundLoc_TestSuite', 'Tag', 'performance')
%
% Requirements:
%   MATLAB R2022b+, Statistics and Machine Learning Toolbox
% =========================================================================

    properties (Constant)
        ACCURACY_TOL    = 1e-9
        LATENCY_TOL     = 1e-6
        SOUND_DUR       = 1.025
        REACTION_PERIOD = 1.75
        TEMP_DIR        = tempdir
        N_COLS          = 13
    end

    properties (TestParameter)
        LaserSoundTypes    = {3, 4}
        NonLaserSoundTypes = {1, 2}
    end

    %% ====================================================================
    %% SECTION 1: GOLDEN-STANDARD TESTS
    %% ====================================================================

    methods (Test, Tags = {'golden'})

        % G-01: Perfect performance -- 100% accuracy, 0% omissions
        function test_G01_PerfectAccuracy(tc)
            [data, meta] = tc.buildSyntheticSession( ...
                'nLaser',40,'nNonLaser',40, ...
                'rewardRateLaser',1.0,'rewardRateNonLaser',1.0, ...
                'omissionRateLaser',0.0,'omissionRateNonLaser',0.0);
            fpath = tc.writeTempFile(data, 'G01_Perfect');
            result = runLaserAnalysisEngine(fpath);

            tc.verifyEqual(result.AccuracyLaser,    100.0,'AbsTol',tc.ACCURACY_TOL);
            tc.verifyEqual(result.AccuracyNonLaser, 100.0,'AbsTol',tc.ACCURACY_TOL);
            tc.verifyEqual(result.OmissionsLaser,   0);
            tc.verifyEqual(result.OmissionsNonLaser,0);
            tc.verifyEqual(result.LaserTrials,      meta.nLaser);
            tc.verifyEqual(result.NonLaserTrials,   meta.nNonLaser);
            tc.verifyEqual(result.oLaserPercent,    0.0,'AbsTol',tc.ACCURACY_TOL);
            delete(fpath);
        end

        % G-02: Chance performance -- 50% accuracy
        function test_G02_ChanceAccuracy(tc)
            [data, meta] = tc.buildSyntheticSession( ...
                'nLaser',80,'nNonLaser',80, ...
                'rewardRateLaser',0.5,'rewardRateNonLaser',0.5, ...
                'omissionRateLaser',0.0,'omissionRateNonLaser',0.0);
            fpath = tc.writeTempFile(data, 'G02_Chance');
            result = runLaserAnalysisEngine(fpath);

            tc.verifyEqual(result.AccuracyLaser, 50.0,'AbsTol',tc.ACCURACY_TOL, ...
                'G-02: Expected 50%% accuracy at chance');
            tc.verifyEqual(result.LaserReward, meta.nLaser/2);
            delete(fpath);
        end

        % G-03: 25% accuracy with 10% omissions -- fully analytically derived
        function test_G03_SubchanceWithOmissions(tc)
            nL = 120; omissRate = 0.10; rewardRate = 0.25;
            nOmiss  = round(nL * omissRate);
            denom   = nL - nOmiss;
            nReward = floor(rewardRate * denom);
            expectedAcc   = (nReward / denom) * 100;
            expectedOmissP= (nOmiss  / nL)   * 100;

            [data, ~] = tc.buildSyntheticSession( ...
                'nLaser',nL,'nNonLaser',nL, ...
                'rewardRateLaser',rewardRate,'rewardRateNonLaser',rewardRate, ...
                'omissionRateLaser',omissRate,'omissionRateNonLaser',omissRate);
            fpath = tc.writeTempFile(data, 'G03_Subchance');
            result = runLaserAnalysisEngine(fpath);

            tc.verifyEqual(result.AccuracyLaser, expectedAcc,'AbsTol',tc.ACCURACY_TOL);
            tc.verifyEqual(result.OmissionsLaser, nOmiss);
            tc.verifyEqual(result.oLaserPercent, expectedOmissP,'AbsTol',tc.ACCURACY_TOL);
            delete(fpath);
        end

        % G-04: Known latency golden value (0.300s)
        function test_G04_KnownLatency(tc)
            targetLatency = 0.300;
            [data, ~] = tc.buildSyntheticSession( ...
                'nLaser',5,'nNonLaser',5, ...
                'rewardRateLaser',1.0,'rewardRateNonLaser',1.0, ...
                'omissionRateLaser',0.0,'omissionRateNonLaser',0.0, ...
                'fixedLatencyLaser',targetLatency);
            fpath = tc.writeTempFile(data, 'G04_KnownLatency');
            result = runLaserAnalysisEngine(fpath);

            tc.verifyEqual(result.LatencyLaser, targetLatency,'AbsTol',tc.LATENCY_TOL, ...
                sprintf('G-04: Expected latency=%.6f s', targetLatency));
            delete(fpath);
        end

        % G-05: Reward count integrity -- denom formula validation
        function test_G05_RewardCountIntegrity(tc)
            [data, ~] = tc.buildSyntheticSession( ...
                'nLaser',60,'nNonLaser',60, ...
                'rewardRateLaser',0.70,'rewardRateNonLaser',0.65, ...
                'omissionRateLaser',0.05,'omissionRateNonLaser',0.08);
            fpath = tc.writeTempFile(data, 'G05_Integrity');
            result = runLaserAnalysisEngine(fpath);

            denom = result.LaserTrials - result.OmissionsLaser;
            if denom > 0
                recomputedAcc = (result.LaserReward / denom) * 100;
                tc.verifyEqual(recomputedAcc, result.AccuracyLaser,'AbsTol',tc.ACCURACY_TOL);
            end
            tc.verifyLessThanOrEqual(result.OmissionsLaser, result.LaserTrials);
            tc.verifyGreaterThanOrEqual(result.LaserReward, 0);
            delete(fpath);
        end

        % G-06: Both laser sound types (3 and 4) classified correctly [parametric]
        function test_G06_LaserSoundTypeClassification(tc, LaserSoundTypes)
            [data, ~] = tc.buildSyntheticSession( ...
                'nLaser',30,'nNonLaser',30, ...
                'rewardRateLaser',1.0,'rewardRateNonLaser',0.0, ...
                'omissionRateLaser',0.0,'omissionRateNonLaser',0.0, ...
                'laserSoundType',LaserSoundTypes);
            fpath = tc.writeTempFile(data, sprintf('G06_SoundType%d',LaserSoundTypes));
            result = runLaserAnalysisEngine(fpath);

            tc.verifyEqual(result.LaserTrials, 30);
            tc.verifyEqual(result.AccuracyLaser,    100.0,'AbsTol',tc.ACCURACY_TOL);
            tc.verifyEqual(result.AccuracyNonLaser,   0.0,'AbsTol',tc.ACCURACY_TOL);
            delete(fpath);
        end

    end % golden

    %% ====================================================================
    %% SECTION 2: BOUNDARY VALUE ANALYSIS
    %% ====================================================================

    methods (Test, Tags = {'boundary'})

        % B-01: Zero laser trials -- NaN guard (observed in real data: 948L, 950, 994)
        function test_B01_ZeroLaserTrials(tc)
            [data, ~] = tc.buildSyntheticSession( ...
                'nLaser',0,'nNonLaser',60, ...
                'rewardRateLaser',0.0,'rewardRateNonLaser',0.75, ...
                'omissionRateLaser',0.0,'omissionRateNonLaser',0.0);
            fpath = tc.writeTempFile(data, 'B01_ZeroLaser');
            tc.verifyWarningFree(@() runLaserAnalysisEngine(fpath));
            result = runLaserAnalysisEngine(fpath);

            tc.verifyTrue(isnan(result.AccuracyLaser),  'B-01: AccuracyLaser must be NaN');
            tc.verifyTrue(isnan(result.LatencyLaser),   'B-01: LatencyLaser must be NaN');
            tc.verifyEqual(result.LaserTrials,    0);
            tc.verifyEqual(result.OmissionsLaser, 0);
            tc.verifyEqual(result.NonLaserTrials, 60);
            delete(fpath);
        end

        % B-02: Zero non-laser trials
        function test_B02_ZeroNonLaserTrials(tc)
            [data, ~] = tc.buildSyntheticSession( ...
                'nLaser',60,'nNonLaser',0, ...
                'rewardRateLaser',0.8,'rewardRateNonLaser',0.0, ...
                'omissionRateLaser',0.0,'omissionRateNonLaser',0.0);
            fpath = tc.writeTempFile(data, 'B02_ZeroNonLaser');
            result = runLaserAnalysisEngine(fpath);

            tc.verifyTrue(isnan(result.AccuracyNonLaser),'B-02: Must be NaN');
            tc.verifyEqual(result.NonLaserTrials, 0);
            delete(fpath);
        end

        % B-03: 100% omissions -- denom=0, AccuracyLaser must be NaN
        function test_B03_AllOmissions(tc)
            [data, ~] = tc.buildSyntheticSession( ...
                'nLaser',20,'nNonLaser',20, ...
                'rewardRateLaser',0.0,'rewardRateNonLaser',0.0, ...
                'omissionRateLaser',1.0,'omissionRateNonLaser',1.0);
            fpath = tc.writeTempFile(data, 'B03_AllOmissions');
            result = runLaserAnalysisEngine(fpath);

            tc.verifyTrue(isnan(result.AccuracyLaser) || result.AccuracyLaser == 0, ...
                'B-03: AccuracyLaser must be NaN or 0 when all trials omitted');
            tc.verifyEqual(result.oLaserPercent, 100.0,'AbsTol',tc.ACCURACY_TOL);
            delete(fpath);
        end

        % B-04: Only ITI licks -- no sound onset events at all
        function test_B04_OnlyITILicks(tc)
            nRows = 200;
            data  = zeros(nRows, tc.N_COLS);
            data(:,1) = cumsum(0.01 + 0.02*rand(nRows,1));
            data(:,2) = double(rand(nRows,1) > 0.7);
            data(:,3) = double(rand(nRows,1) > 0.7);
            % Column 7 (soundOnset) = 0 -- no trial starts

            fpath = tc.writeTempFile(data, 'B04_ITIOnly');
            result = runLaserAnalysisEngine(fpath);

            tc.verifyEqual(result.LaserTrials,    0,'B-04: No laser trials expected');
            tc.verifyEqual(result.NonLaserTrials, 0,'B-04: No non-laser trials expected');
            tc.verifyTrue(isnan(result.AccuracyLaser));
            tc.verifyTrue(isnan(result.LatencyLaser));
            delete(fpath);
        end

        % B-05: Single trial -- minimum viable session
        function test_B05_SingleTrial(tc)
            [data, ~] = tc.buildSyntheticSession( ...
                'nLaser',1,'nNonLaser',1, ...
                'rewardRateLaser',1.0,'rewardRateNonLaser',1.0, ...
                'omissionRateLaser',0.0,'omissionRateNonLaser',0.0);
            fpath = tc.writeTempFile(data, 'B05_SingleTrial');
            result = runLaserAnalysisEngine(fpath);

            tc.verifyEqual(result.LaserTrials,    1);
            tc.verifyEqual(result.AccuracyLaser,100.0,'AbsTol',tc.ACCURACY_TOL);
            tc.verifyEqual(result.OmissionsLaser, 0);
            delete(fpath);
        end

        % B-06: Lick at exact reaction window boundary (2.775s)
        % Boundary licks count as omissions (strictly >)
        function test_B06_BoundaryReactionWindow(tc)
            threshold = tc.SOUND_DUR + tc.REACTION_PERIOD;
            nRows = 10 * 3;
            data  = zeros(nRows, tc.N_COLS);
            trialN = 0; t = 0; row = 0;
            for trial = 1:10
                trialN = trialN + 1;
                row = row + 1; t = t + 2.0;
                data(row,:) = tc.makeRow(t,0,0,0,0,0,1,trialN,3);
                row = row + 1; t = t + threshold;
                data(row,:) = tc.makeRow(t,0,0,0,0,1,0,trialN,3);
                row = row + 1; t = t + 0.5;
                data(row,:) = tc.makeRow(t,0,0,0,0,0,1,trialN+1,0);
            end

            fpath = tc.writeTempFile(data(1:row,:),'B06_BoundaryWindow');
            result = runLaserAnalysisEngine(fpath);

            tc.verifyEqual(result.OmissionsLaser, 10, ...
                'B-06: Licks at exact boundary must be counted as omissions');
            delete(fpath);
        end

        % B-07: Non-standard filename conventions (no dashes)
        function test_B07_NonStandardFilenames(tc)
            [data, ~] = tc.buildSyntheticSession( ...
                'nLaser',60,'nNonLaser',60, ...
                'rewardRateLaser',0.8,'rewardRateNonLaser',0.8, ...
                'omissionRateLaser',0.0,'omissionRateNonLaser',0.0);

            badNames = {'session_data','recording','data'};
            for k = 1:numel(badNames)
                fpath = tc.writeTempFile(data, badNames{k});
                tc.verifyWarningFree(@() runLaserAnalysisEngine(fpath), ...
                    sprintf('B-07: Non-standard name "%s" must not throw', badNames{k}));
                result = runLaserAnalysisEngine(fpath);
                tc.verifyNotEmpty(result);
                delete(fpath);
            end
        end

        % B-08: Empty / header-only file -- must throw a catchable error
        function test_B08_EmptyFile(tc)
            fpath = fullfile(tc.TEMP_DIR, 'B08_EmptyFile');
            fid   = fopen(fpath,'w');
            fprintf(fid,'0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\n');
            fclose(fid);

            tc.verifyError(@() runLaserAnalysisEngine(fpath), ?MException, ...
                'B-08: Empty file should throw MException');
            delete(fpath);
        end

        % B-09: NaN timestamps -- latency must not be Inf
        function test_B09_NaNTimestamps(tc)
            [data, ~] = tc.buildSyntheticSession( ...
                'nLaser',10,'nNonLaser',10, ...
                'rewardRateLaser',1.0,'rewardRateNonLaser',1.0, ...
                'omissionRateLaser',0.0,'omissionRateNonLaser',0.0);
            data(:,1) = NaN;
            fpath = tc.writeTempFile(data,'B09_NaNTimestamps');
            result = runLaserAnalysisEngine(fpath);

            tc.verifyFalse(isinf(result.LatencyLaser) || isinf(result.LatencyNonLaser), ...
                'B-09: Corrupt timestamps must not produce Inf');
            delete(fpath);
        end

        % B-10: Large session stress test (2000+2000 trials, <2s)
        function test_B10_LargeSessions(tc)
            [data, ~] = tc.buildSyntheticSession( ...
                'nLaser',2000,'nNonLaser',2000, ...
                'rewardRateLaser',0.75,'rewardRateNonLaser',0.73, ...
                'omissionRateLaser',0.05,'omissionRateNonLaser',0.06);
            fpath = tc.writeTempFile(data,'B10_LargeSession');
            t0 = tic;
            result = runLaserAnalysisEngine(fpath);
            elapsed = toc(t0);

            tc.verifyEqual(result.LaserTrials,2000,'B-10: Trial count mismatch');
            tc.verifyLessThan(elapsed, 2.0, ...
                sprintf('B-10: Analysis of 4000 trials took %.3fs (limit 2s)',elapsed));
            delete(fpath);
        end

    end % boundary

    %% ====================================================================
    %% SECTION 3: DATA INTEGRITY -- xlsx <-> .mat synchronization
    %% ====================================================================

    methods (Test, Tags = {'integrity'})

        % I-01: Column schema verification
        function test_I01_SnapshotSchemaMatch(tc)
            expectedCols = {'ID','Date', ...
                'AccuracyLaser','AccuracyNonLaser', ...
                'OmissionsLaser','OmissionsNonLaser', ...
                'LaserReward','NonLaserReward', ...
                'LaserTrials','NonLaserTrials', ...
                'oLaserPercent','oNonLaserPercent', ...
                'LatencyLaser','LatencyNonLaser', ...
                'Angle','Power','Visualize'};
            T = tc.buildMockSnapshotTable(20);
            missingCols = setdiff(expectedCols, T.Properties.VariableNames);
            tc.verifyEmpty(missingCols, ...
                sprintf('I-01: Missing columns: %s', strjoin(missingCols,', ')));
        end

        % I-02: Row count synchronization (xlsx vs .mat)
        function test_I02_RowCountSync(tc)
            T     = tc.buildMockSnapshotTable(35);
            xPath = fullfile(tc.TEMP_DIR,'I02_sync.xlsx');
            mPath = fullfile(tc.TEMP_DIR,'I02_sync.mat');
            writetable(T,xPath,'Sheet','ProcessedResults');
            lastUpdated = datetime('now'); %#ok<NASGU>
            save(mPath,'T','lastUpdated');

            Txls = readtable(xPath,'Sheet','ProcessedResults','VariableNamingRule','preserve');
            S    = load(mPath,'T');

            tc.verifyEqual(height(Txls), height(S.T), ...
                sprintf('I-02: xlsx=%d rows, .mat=%d rows',height(Txls),height(S.T)));
            delete(xPath); delete(mPath);
        end

        % I-03: Numerical precision round-trip (xlsx loses some; .mat is lossless)
        function test_I03_NumericalIntegrityRoundtrip(tc)
            T = tc.buildMockSnapshotTable(10);
            knownAcc = 73.333333333333;
            T.AccuracyLaser(1) = knownAcc;

            xPath = fullfile(tc.TEMP_DIR,'I03_rt.xlsx');
            mPath = fullfile(tc.TEMP_DIR,'I03_rt.mat');
            writetable(T,xPath,'Sheet','ProcessedResults');
            lastUpdated = datetime('now'); %#ok<NASGU>
            save(mPath,'T','lastUpdated');

            Txls = readtable(xPath,'Sheet','ProcessedResults','VariableNamingRule','preserve');
            tc.verifyEqual(Txls.AccuracyLaser(1),knownAcc,'AbsTol',1e-6,'I-03: xlsx precision');

            S = load(mPath,'T');
            tc.verifyEqual(S.T.AccuracyLaser(1),knownAcc,'AbsTol',1e-12,'I-03: .mat lossless');
            delete(xPath); delete(mPath);
        end

        % I-04: Alphanumeric ID preservation (948L, 950L, 9450L must not coerce to NaN)
        function test_I04_IDDateStringPreservation(tc)
            T = tc.buildMockSnapshotTable(5);
            T.ID   = ["948L";"950L";"9450L";"1034";"1029"];
            T.Date = ["2025-07-24";"2025-08-17";"2025-11-01";"2025-12-31";"2026-02-05"];

            xPath = fullfile(tc.TEMP_DIR,'I04_ids.xlsx');
            writetable(T,xPath,'Sheet','ProcessedResults');
            opts = detectImportOptions(xPath,'Sheet','ProcessedResults');
            opts.VariableNamingRule = 'preserve';
            opts = setvartype(opts,{'ID','Date'},'string');
            Tbk  = readtable(xPath,opts);

            for k = 1:height(T)
                tc.verifyEqual(string(Tbk.ID(k)), string(T.ID(k)), ...
                    sprintf('I-04: ID "%s" corrupted to "%s"',T.ID(k),Tbk.ID(k)));
            end
            delete(xPath);
        end

        % I-05: Stale snapshot detection (xlsx modified after snapshot)
        function test_I05_StaleSnapshotDetected(tc)
            T     = tc.buildMockSnapshotTable(15);
            xPath = fullfile(tc.TEMP_DIR,'I05_stale.xlsx');
            mPath = fullfile(tc.TEMP_DIR,'I05_stale.mat');
            writetable(T,xPath,'Sheet','ProcessedResults');
            lastUpdated = datetime('now') - hours(2); %#ok<NASGU>
            save(mPath,'T','lastUpdated');
            pause(0.05);
            T2 = [T; T(1,:)];
            writetable(T2,xPath,'Sheet','ProcessedResults');

            [isSync,msg] = SoundLoc_TestSuite.checkSyncIntegrity(xPath,mPath);
            tc.verifyFalse(isSync, ...
                ['I-05: Stale snapshot should be detected. Msg: ' msg]);
            delete(xPath); delete(mPath);
        end

        % I-06: Corrupt .mat file -- must throw catchable error
        function test_I06_ConcurrentWriteGuard(tc)
            mPath = fullfile(tc.TEMP_DIR,'I06_corrupt.mat');
            fid = fopen(mPath,'w');
            fwrite(fid,uint8([77 65 84 76 65 66 32]),'uint8'); % partial MAT header
            fclose(fid);

            tc.verifyError(@() load(mPath), ?MException, ...
                'I-06: Corrupt .mat must throw MException');
            delete(mPath);
        end

        % I-07: NaN sentinel invariant (NaN accuracy <-> zero valid denom)
        function test_I07_NaNSentinelConsistency(tc)
            T = tc.buildMockSnapshotTable(50);
            nanRows = find(isnan(T.AccuracyLaser));
            for k = nanRows(:)'
                validDenom = T.LaserTrials(k) - T.OmissionsLaser(k);
                tc.verifyLessThanOrEqual(validDenom, 0, ...
                    sprintf('I-07: Row %d has NaN AccuracyLaser but denom=%d',k,validDenom));
            end
        end

    end % integrity

    %% ====================================================================
    %% SECTION 4: PERFORMANCE BENCHMARKS
    %% ====================================================================

    methods (Test, Tags = {'performance'})

        % P-01: Batch throughput -- 50 files in <5s
        function test_P01_BatchThroughput(tc)
            nFiles = 50;
            tmpDir = fullfile(tc.TEMP_DIR,'P01_batch');
            if ~exist(tmpDir,'dir'), mkdir(tmpDir); end

            for k = 1:nFiles
                [data,~] = tc.buildSyntheticSession( ...
                    'nLaser',60,'nNonLaser',60, ...
                    'rewardRateLaser',0.7,'rewardRateNonLaser',0.72, ...
                    'omissionRateLaser',0.05,'omissionRateNonLaser',0.04);
                fpath = fullfile(tmpDir,sprintf('20251201-120000-P01anim%d',k));
                tc.writeTempFileAt(data,fpath);
            end

            t0 = tic;
            results = cell(nFiles,1);
            files = dir(fullfile(tmpDir,'*'));
            files = files(~[files.isdir]);
            for k = 1:numel(files)
                try
                    results{k} = runLaserAnalysisEngine( ...
                        fullfile(files(k).folder,files(k).name));
                catch; results{k} = []; end
            end
            elapsed = toc(t0);
            perFile = elapsed/nFiles*1000;

            valid = sum(~cellfun(@isempty,results));
            tc.verifyGreaterThanOrEqual(valid, round(nFiles*0.95));
            tc.verifyLessThan(perFile, 100, ...
                sprintf('P-01: %.1f ms/file exceeds 100ms budget',perFile));
            rmdir(tmpDir,'s');
        end

        % P-02: .mat snapshot write latency (<500ms)
        function test_P02_SnapshotWriteLatency(tc)
            T    = tc.buildMockSnapshotTable(213);
            mPath= fullfile(tc.TEMP_DIR,'P02_snapshot.mat');
            lastUpdated = datetime('now'); %#ok<NASGU>
            t0   = tic; save(mPath,'T','lastUpdated'); elapsed = toc(t0)*1000;
            tc.verifyLessThan(elapsed, 500, ...
                sprintf('P-02: .mat write took %.1fms',elapsed));
            delete(mPath);
        end

        % P-03: .mat snapshot read latency (<200ms)
        function test_P03_SnapshotReadLatency(tc)
            T    = tc.buildMockSnapshotTable(213);
            mPath= fullfile(tc.TEMP_DIR,'P03_read.mat');
            lastUpdated = datetime('now'); %#ok<NASGU>
            save(mPath,'T','lastUpdated');
            t0 = tic; S = load(mPath,'T','lastUpdated'); elapsed = toc(t0)*1000; %#ok<NASGU>
            tc.verifyLessThan(elapsed, 200, ...
                sprintf('P-03: .mat read took %.1fms',elapsed));
            delete(mPath);
        end

        % P-04: IQR vectorization on 10k rows (<10ms)
        function test_P04_IQRVectorizationSpeed(tc)
            vals = 50 + 20*randn(10000,1);
            t0   = tic;
            q1 = prctile(vals,25); q3 = prctile(vals,75); iqr_ = q3-q1;
            mask = vals < q1-1.5*iqr_ | vals > q3+1.5*iqr_; %#ok<NASGU>
            elapsed = toc(t0)*1000;
            tc.verifyLessThan(elapsed, 10, ...
                sprintf('P-04: IQR took %.2fms',elapsed));
        end

        % P-05: griddata manifold interpolation (<1000ms)
        function test_P05_GriddataPerformance(tc)
            rng(42);
            nPts = 213;
            xv = 10+70*rand(nPts,1); yv = 0.5+4.5*rand(nPts,1); zv = 40+40*rand(nPts,1);
            xi = linspace(min(xv),max(xv),50); yi = linspace(min(yv),max(yv),50);
            [XI,YI] = meshgrid(xi,yi);
            t0 = tic;
            try, ZI = griddata(xv,yv,zv,XI,YI,'natural'); %#ok<NASGU>
            catch, ZI = griddata(xv,yv,zv,XI,YI,'linear'); end %#ok<NASGU>
            elapsed = toc(t0)*1000;
            tc.verifyLessThan(elapsed, 1000, ...
                sprintf('P-05: griddata took %.1fms',elapsed));
        end

        % P-06: Filter + KPI recompute cycle (<100ms)
        function test_P06_FilterRerenderCycle(tc)
            T = tc.buildMockSnapshotTable(213);
            t0 = tic;
            mask = strcmp(string(T.ID),'1029');
            Ts   = T(mask,:);
            kpis = {height(Ts),numel(unique(string(Ts.ID))), ...
                nanmean(Ts.AccuracyLaser),nanmean(Ts.AccuracyNonLaser), ...
                nanmean(Ts.LatencyLaser), nanmean(Ts.oLaserPercent)}; %#ok<NASGU>
            elapsed = toc(t0)*1000;
            tc.verifyLessThan(elapsed, 100, ...
                sprintf('P-06: Filter+KPI took %.2fms',elapsed));
        end

    end % performance

    %% ====================================================================
    %% STATIC: Sync integrity checker (used by SoundLocalizationGUI)
    %% ====================================================================

    methods (Static)

        function [isSync, message] = checkSyncIntegrity(xlsxPath, matPath)
        % checkSyncIntegrity — Pre-render data integrity gate.
        % Call this in SoundLocalizationGUI.postLoadRefresh() before
        % any visualization is rendered.
        %
        % Returns:
        %   isSync  — true if xlsx and .mat agree
        %   message — human-readable explanation

            isSync  = false;
            message = '';

            if ~isfile(xlsxPath)
                message = sprintf('xlsx not found: %s', xlsxPath); return;
            end
            if ~isfile(matPath)
                message = sprintf('.mat not found: %s', matPath); return;
            end

            % Load snapshot
            try
                S = load(matPath,'T','lastUpdated');
            catch ME
                message = sprintf('Cannot read .mat: %s', ME.message); return;
            end
            if ~isfield(S,'T')
                message = 'Snapshot .mat missing variable T.'; return;
            end
            Tmat = S.T;

            % Load xlsx
            try
                opts = detectImportOptions(xlsxPath,'Sheet','ProcessedResults');
                opts.VariableNamingRule = 'preserve';
                opts = setvartype(opts,{'ID','Date'},'string');
                Txls = readtable(xlsxPath,opts);
            catch ME
                message = sprintf('Cannot read xlsx: %s', ME.message); return;
            end

            % Check 1: Row count
            if height(Txls) ~= height(Tmat)
                message = sprintf( ...
                    'Row count mismatch: xlsx=%d, .mat=%d. Re-Sync required.', ...
                    height(Txls), height(Tmat));
                return;
            end

            % Check 2: Column presence
            missingInMat = setdiff(Txls.Properties.VariableNames, ...
                                   Tmat.Properties.VariableNames);
            if ~isempty(missingInMat)
                message = sprintf('Columns in xlsx but not .mat: %s', ...
                    strjoin(missingInMat,', '));
                return;
            end

            % Check 3: Numerical checksums (vectorized nansum comparison)
            numCols = {'AccuracyLaser','AccuracyNonLaser', ...
                       'LaserTrials','NonLaserTrials', ...
                       'LatencyLaser','LatencyNonLaser'};
            for k = 1:numel(numCols)
                col = numCols{k};
                if ~ismember(col,Txls.Properties.VariableNames), continue; end
                if ~ismember(col,Tmat.Properties.VariableNames), continue; end
                csXls = nansum(double(Txls.(col)));
                csMat = nansum(double(Tmat.(col)));
                if abs(csXls - csMat) > 1e-4
                    message = sprintf( ...
                        'Checksum mismatch in "%s": xlsx=%.6f, .mat=%.6f. Re-Sync.', ...
                        col, csXls, csMat);
                    return;
                end
            end

            % Check 4: Timestamp freshness (warning, not hard failure)
            if isfield(S,'lastUpdated') && ~isempty(S.lastUpdated)
                xlsxInfo    = dir(xlsxPath);
                xlsxModTime = datetime(xlsxInfo.datenum,'ConvertFrom','datenum');
                if xlsxModTime > S.lastUpdated + seconds(30)
                    message = sprintf( ...
                        'xlsx modified %s AFTER snapshot (%s). Re-Sync recommended.', ...
                        char(xlsxModTime,'yyyy-MM-dd HH:mm'), ...
                        char(S.lastUpdated,'yyyy-MM-dd HH:mm'));
                    isSync = true;   % warning only -- allow rendering
                    return;
                end
            end

            isSync  = true;
            message = sprintf('OK: %d rows synchronized.', height(Tmat));
        end

    end % static

    %% ====================================================================
    %% PRIVATE: Synthetic dataset generator
    %% ====================================================================

    methods (Access = private)

        function [data, meta] = buildSyntheticSession(~, varargin)
            p = inputParser();
            p.addParameter('nLaser',            60);
            p.addParameter('nNonLaser',         60);
            p.addParameter('rewardRateLaser',    0.7);
            p.addParameter('rewardRateNonLaser', 0.7);
            p.addParameter('omissionRateLaser',  0.05);
            p.addParameter('omissionRateNonLaser',0.05);
            p.addParameter('fixedLatencyLaser',  []);
            p.addParameter('laserSoundType',     3);
            p.parse(varargin{:});
            opt = p.Results;

            nL = opt.nLaser; nNL = opt.nNonLaser;
            nTotal = nL + nNL;

            stypes = [opt.laserSoundType*ones(nL,1); ones(nNL,1)];
            stypes = stypes(randperm(nTotal));
            isLaser    = stypes == opt.laserSoundType;
            isNonLaser = ~isLaser;

            reward   = false(nTotal,1);
            omission = false(nTotal,1);

            lIdxs = find(isLaser);
            nLom  = round(nL * opt.omissionRateLaser);
            nLrew = min(round((nL-nLom)*opt.rewardRateLaser), nL-nLom);
            if nLom > 0, omission(lIdxs(1:nLom)) = true; end
            if nLrew > 0, reward(lIdxs(nLom+1:nLom+nLrew)) = true; end

            nlIdxs = find(isNonLaser);
            nNLom  = round(nNL * opt.omissionRateNonLaser);
            nNLrew = min(round((nNL-nNLom)*opt.rewardRateNonLaser), nNL-nNLom);
            if nNLom  > 0, omission(nlIdxs(1:nNLom)) = true; end
            if nNLrew > 0, reward(nlIdxs(nNLom+1:nNLom+nNLrew)) = true; end

            rows     = {};
            t        = 0.0;
            trialNum = 0;
            SD       = SoundLoc_TestSuite.SOUND_DUR;
            RP       = SoundLoc_TestSuite.REACTION_PERIOD;
            NC       = SoundLoc_TestSuite.N_COLS;

            for k = 1:nTotal
                trialNum = trialNum + 1;
                stype    = stypes(k);
                t        = t + 2.0 + rand()*0.5;
                onset_t  = t;
                row0     = zeros(1,NC);
                row0(1)=t; row0(7)=1; row0(8)=trialNum; row0(9)=stype; row0(10)=1;
                rows{end+1} = row0; %#ok<AGROW>

                if omission(k)
                    t = t + 0.1;
                    trialNum = trialNum + 1;
                    row1 = zeros(1,NC);
                    row1(1)=t; row1(7)=1; row1(8)=trialNum; row1(10)=1;
                    rows{end+1} = row1; %#ok<AGROW>
                elseif reward(k)
                    if ~isempty(opt.fixedLatencyLaser) && isLaser(k)
                        lick_t = onset_t + opt.fixedLatencyLaser;
                    else
                        lick_t = onset_t + 0.1 + rand()*1.5;
                        lick_t = min(lick_t, onset_t + SD + RP - 0.01);
                    end
                    t = lick_t;
                    row1 = zeros(1,NC);
                    row1(1)=t; row1(6)=1; row1(8)=trialNum; row1(9)=stype;
                    rows{end+1} = row1; %#ok<AGROW>
                else
                    t = onset_t + SD + RP - 0.5;
                    row1 = zeros(1,NC);
                    row1(1)=t; row1(8)=trialNum; row1(9)=stype;
                    rows{end+1} = row1; %#ok<AGROW>
                end
            end

            data = vertcat(rows{:});
            meta = struct('nLaser',nL,'nNonLaser',nNL, ...
                'nLaserReward',nLrew,'nNonLaserReward',nNLrew, ...
                'nLaserOmiss',nLom,'nNonLaserOmiss',nNLom);
        end

        function fpath = writeTempFile(tc, data, name)
            name  = strrep(name,' ','_');
            fpath = fullfile(tc.TEMP_DIR, name);
            writematrix(data,fpath,'Delimiter','tab','FileType','text');
            if isfile([fpath '.txt']), movefile([fpath '.txt'],fpath); end
        end

        function writeTempFileAt(~, data, fpath)
            writematrix(data,fpath,'Delimiter','tab','FileType','text');
            if isfile([fpath '.txt']), movefile([fpath '.txt'],fpath); end
        end

        function row = makeRow(~, t,ll,rl,lw,rw,tbl,soundT,trialN,varargin)
            NC  = SoundLoc_TestSuite.N_COLS;
            row = zeros(1,NC);
            vals= [t,ll,rl,lw,rw,tbl,soundT,trialN,soundT];
            row(1:min(numel(vals),NC)) = vals(1:min(numel(vals),NC));
        end

        function T = buildMockSnapshotTable(~, nRows)
            rng(123);
            IDs = {'1029','1030','1031','1034','948L','949','950','994','995'};
            id_col   = string(IDs(randi(numel(IDs),nRows,1)))';
            dates    = datetime('2025-07-01') + days(randi(220,nRows,1)-1);
            date_col = string(datestr(dates,'yyyy-mm-dd'))';

            laserTrials    = 120*ones(nRows,1);
            nonlaserTrials = 120*ones(nRows,1);
            omissL  = round(rand(nRows,1).*laserTrials*0.2);
            omissNL = round(rand(nRows,1).*nonlaserTrials*0.2);
            denomL  = laserTrials - omissL;
            denomNL = nonlaserTrials - omissNL;

            rewardL  = round(denomL .* (0.4+0.5*rand(nRows,1)));
            rewardNL = round(denomNL.* (0.4+0.5*rand(nRows,1)));

            accL  = NaN(nRows,1); accNL = NaN(nRows,1);
            validL  = denomL  > 0; validNL = denomNL > 0;
            accL(validL)   = (rewardL(validL)  ./denomL(validL))  *100;
            accNL(validNL) = (rewardNL(validNL)./denomNL(validNL))*100;

            T = table(id_col,NaN(nRows,1),NaN(nRows,1),date_col, ...
                accL,accNL,omissL,omissNL, ...
                rewardL,rewardNL,laserTrials,nonlaserTrials, ...
                (omissL./laserTrials)*100,(omissNL./nonlaserTrials)*100, ...
                0.2+0.4*rand(nRows,1), 0.2+0.4*rand(nRows,1), ...
                'VariableNames',{'ID','Date', ...
                    'AccuracyLaser','AccuracyNonLaser', ...
                    'OmissionsLaser','OmissionsNonLaser', ...
                    'LaserReward','NonLaserReward', ...
                    'LaserTrials','NonLaserTrials', ...
                    'oLaserPercent','oNonLaserPercent', ...
                    'LatencyLaser','LatencyNonLaser','Angle','Power', 'Visualize'});
        end

    end % private

end % classdef


%% ========================================================================
%% STANDALONE NaN-SAFE ANALYSIS ENGINE
%% Fault-tolerant wrapper used by both test suite and GUI batchProcess()
%% ========================================================================

function result = runLaserAnalysisEngine(filename)
% runLaserAnalysisEngine — NaN-safe, fault-tolerant analysis entry point.
% Every failure mode returns a consistent struct rather than crashing.

    result = struct('AccuracyLaser',NaN,'AccuracyNonLaser',NaN, ...
        'OmissionsLaser',0,'OmissionsNonLaser',0, ...
        'LaserReward',0,'NonLaserReward',0, ...
        'LaserTrials',0,'NonLaserTrials',0, ...
        'oLaserPercent',NaN,'oNonLaserPercent',NaN, ...
        'LatencyLaser',NaN,'LatencyNonLaser',NaN);

    if ~isfile(filename)
        error('runLaserAnalysisEngine:FileNotFound','File not found: %s',filename);
    end

    opts = detectImportOptions(filename);
    opts.VariableNamingRule = 'preserve';
    datab = table2array(readtable(filename, opts));

    if size(datab,1) < 2
        error('runLaserAnalysisEngine:InsufficientData', ...
            'File has < 2 rows: %s', filename);
    end

    sound_dur = 1.025; reaction_period = 1.75;
    timestamps = double(datab(:,1)); soundonset = double(datab(:,7));
    trial_num  = double(datab(:,8)); soundAB    = double(datab(:,9));
    trigger    = double(datab(:,6));

    trial_ind     = find(soundonset == 1);
    tid_laser     = trial_ind(soundAB(trial_ind)==3 | soundAB(trial_ind)==4);
    tid_nonlaser  = trial_ind(soundAB(trial_ind)==1 | soundAB(trial_ind)==2);

    result.LaserTrials    = numel(tid_laser);
    result.NonLaserTrials = numel(tid_nonlaser);

    reward_L = 0; omiss_L = 0; reward_NL = 0; omiss_NL = 0;
    for i = 1:numel(tid_laser)
        ind = tid_laser(i)+1;
        if ind > size(datab,1), continue; end
        if trial_num(ind)==trial_num(ind-1) && trigger(ind)==1
            reward_L = reward_L+1; end
        if trial_num(ind)~=trial_num(ind-1) || ...
                (timestamps(ind)-timestamps(ind-1)) > (sound_dur+reaction_period)
            omiss_L = omiss_L+1; end
    end
    for i = 1:numel(tid_nonlaser)
        ind = tid_nonlaser(i)+1;
        if ind > size(datab,1), continue; end
        if trial_num(ind)==trial_num(ind-1) && trigger(ind)==1
            reward_NL = reward_NL+1; end
        if trial_num(ind)~=trial_num(ind-1) || ...
                (timestamps(ind)-timestamps(ind-1)) > (sound_dur+reaction_period)
            omiss_NL = omiss_NL+1; end
    end

    result.LaserReward=reward_L; result.NonLaserReward=reward_NL;
    result.OmissionsLaser=omiss_L; result.OmissionsNonLaser=omiss_NL;

    dL = result.LaserTrials - omiss_L;
    dNL= result.NonLaserTrials - omiss_NL;
    if dL  > 0, result.AccuracyLaser    = (reward_L  /dL)  *100; end
    if dNL > 0, result.AccuracyNonLaser = (reward_NL /dNL) *100; end
    if result.LaserTrials    > 0
        result.oLaserPercent    = (omiss_L  /result.LaserTrials)    *100; end
    if result.NonLaserTrials > 0
        result.oNonLaserPercent = (omiss_NL /result.NonLaserTrials) *100; end

    first_lick   = find(trigger);
    first_lick   = first_lick(first_lick > 1);
    laser_idx    = first_lick(ismember(first_lick-1, tid_laser));
    nonlaser_idx = first_lick(ismember(first_lick-1, tid_nonlaser));

    if ~isempty(laser_idx)
        lats = timestamps(laser_idx)-timestamps(laser_idx-1);
        lats(isinf(lats)|isnan(lats)) = [];
        if ~isempty(lats), result.LatencyLaser = mean(lats); end
    end
    if ~isempty(nonlaser_idx)
        lats = timestamps(nonlaser_idx)-timestamps(nonlaser_idx-1);
        lats(isinf(lats)|isnan(lats)) = [];
        if ~isempty(lats), result.LatencyNonLaser = mean(lats); end
    end
end
classdef TestProductEnhancements < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'app')));
        end
    end
    methods (Test)
        function opticalDefaultsAndExplicitBounds(testCase)
            options = swing_period_options();
            testCase.verifyEqual(options.ReferencePeriod, 248/1.77, 'AbsTol', 1e-12);
            testCase.verifyEqual(options.PeriodBounds, 248/1.77*[0.75, 1.25], 'AbsTol', 1e-12);
            custom = swing_period_options(248, 1.77, [100, 160]);
            testCase.verifyEqual(custom.PeriodBounds, [100, 160]);
            testCase.verifyError(@() swing_period_options(248, 1.77, [160, 100]), 'swing_period_options:bounds');
        end
        function explicitPeriodRangeConstrainsLikelihoodSearch(testCase)
            result = optimize_swing_period(@(period, ~) -(period-140)^2, linspace(800, 1300, 51)', 248/1.77, [], [120, 150]);
            testCase.verifyEqual(result.Period, 140, 'AbsTol', 0.1);
            testCase.verifyTrue(all(result.Trace.Period >= 120 & result.Trace.Period <= 150));
        end
        function flexibleKernelsRemainPositiveSemidefinite(testCase)
            for count = [1, 2, 6]
                index = (1:25)'; inputs = sin(index*(1:count)/7); inputs(:, end) = index/3;
                kernel = make_swing_periodic_kernel(140, 10, [100, 180], count);
                gram = kernel(inputs, inputs, zeros(count+3, 1));
                testCase.verifyEqual(gram, gram', 'AbsTol', 1e-12);
                testCase.verifyGreaterThanOrEqual(min(eig((gram+gram')/2)), -1e-10);
                testCase.verifyEqual(swing_kernel_info(kernel).Period, 140);
            end
        end
        function visibleLabelsPreserveEveryMetricValueAndReason(testCase)
            original = evaluate_predictions((1:20)', (1:20)' + sin((1:20)'), 4);
            visible = display_metric_names(original);
            testCase.verifyEqual(visible.Value, original.Value);
            testCase.verifyEqual(visible.Note, original.Note);
            constant = evaluate_predictions(zeros(20,1),ones(20,1),4);
            renamed = display_metric_names(constant);
            testCase.verifyTrue(isequaln(renamed.Value,constant.Value));
            testCase.verifyEqual(renamed.Note,constant.Note);
            testCase.verifyEqual(visible.Metric(7:8), ["KLダイバージェンス"; "相互情報量"]);
            wide = array2table([1, 2], 'VariableNames', {'KL_nats', 'Mutual_information_bits'});
            testCase.verifyEqual(display_metric_names(wide).Properties.VariableNames, {'KLダイバージェンス', '相互情報量'});
        end
        function splineInterpolatesCubicAndFindsStationaryExtrema(testCase)
            x = linspace(-2, 2, 21)'; y = x.^3 - 3*x;
            fit = fit_swing_spline(x, y); [points, segments] = swing_curve_extrema(fit, [-2, 2]);
            testCase.verifyEqual(fit.Prediction, y, 'AbsTol', 1e-10);
            testCase.verifyEqual(points.Thickness, [-1; 1], 'AbsTol', 1e-8);
            testCase.verifyEqual(points.Type, ["極大"; "極小"]); testCase.verifyEmpty(segments);
            testCase.verifyTrue(isnan(fit.Period));
        end
        function splineDuplicatesUseMeanAndRetainOriginalResiduals(testCase)
            x = [-2;-1;0;1;2;0]; y = [0;1;0;-1;0;2]; fit = fit_swing_spline(x,y);
            testCase.verifyEqual(swing_curve_values(fit,0), 1, 'AbsTol', 1e-12);
            testCase.verifyEqual(numel(fit.Prediction), numel(x));
            testCase.verifyGreaterThan(fit.RMSE, 0);
        end
        function splineSegmentSlopesFollowActualNeighboringExtrema(testCase)
            x = linspace(0, 8*pi, 129)'; fit = fit_swing_spline(x, sin(x)+0.03*x.^2);
            [points, segments] = swing_curve_extrema(fit, [min(x), max(x)]);
            testCase.verifyGreaterThan(height(points), 4); testCase.verifyGreaterThan(height(segments), 2);
            testCase.verifyEqual(segments.Slope, (segments.EndSHAP-segments.StartSHAP)./(segments.EndThickness-segments.StartThickness), 'AbsTol', 1e-12);
            testCase.verifyGreaterThan(range(segments.Slope), 0.1);
            monotone = fit_swing_spline((1:10)', (1:10)'); [none, ~] = swing_curve_extrema(monotone, [1,10]); testCase.verifyEmpty(none);
        end
        function standardBuildOmitsProCodeAndProBuildIncludesIt(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            standard = fullfile(fixture.Folder,'standard'); pro = fullfile(fixture.Folder,'pro');
            a = prepare_edition_build(root,'standard',standard); b = prepare_edition_build(root,'pro',pro);
            testCase.verifyEmpty(a.ProFiles); testCase.verifyNumElements(b.ProFiles,7);
            testCase.verifyFalse(isfile(fullfile(standard,'app','SwingCurveView.m')));
            testCase.verifyFalse(isfile(fullfile(standard,'core','fit_swing_spline.m')));
            testCase.verifyFalse(contains(fileread(fullfile(standard,'app','plot_shap_figures.m')),'SwingCurveView'));
            testCase.verifyTrue(contains(fileread(fullfile(pro,'core','app_edition.m')),'''pro'''));
            testCase.verifyTrue(contains(fileread(fullfile(standard,'core','app_edition.m')),'''standard'''));
        end
    end
end

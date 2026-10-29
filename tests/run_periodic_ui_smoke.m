function run_periodic_ui_smoke(image_folder)
% 合成目的関数の表示試験。GPR学習・周辺尤度計算は行わない。
if nargin < 1, image_folder = ''; end
[app, cleanup] = create_display_preview(); %#ok<ASGLU>
app.Window.Position = [40, 40, 1320, 780];
state = app.Panels{2};
assert(any(strcmp(state.Kernel.Items, 'swingperiodic')));
assert(~any(strcmp(app.Panels{1}.Kernel.Items, 'swingperiodic')));
assert(~any(strcmp(app.Panels{3}.Kernel.Items, 'swingperiodic')));
state.Kernel.Value = 'swingperiodic'; state.Kernel.ValueChangedFcn(state.Kernel, []);
assert(any(contains(string(state.ModelInfo.Value), '周辺尤度')));
names = {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH', 'y'};
state.Mapping.Data = [num2cell((1:5)'), names', [names(1:4), {'CD'}]'];
state.Source.Text = '合成データ／GPR未学習';
state.Headline.Text = '表示見本：GPR学習・周辺尤度の計算は未実行';
details = optimize_swing_period(@(period, ~) -((400/period - 5)/0.4)^2, linspace(850, 1250, 101)', 80);
details.FitMethod = '表示試験'; details.Criterion = '合成目的関数（周辺尤度ではありません）';
app.displayPeriodicTraining(2, details);
main = findobj(app.Window, 'Type', 'uitabgroup', 'TabLocation', 'left'); main.SelectedTab = state.Layout.Parent;
state.Views.SelectedTab = state.Views.Children(strcmp({state.Views.Children.Title}, '周期の最適化'));
assert(height(state.Views.SelectedTab.Children.Children.Data) == details.Evaluations);
if ~isempty(image_folder)
    drawnow; pause(0.5); exportapp(app.Window, fullfile(image_folder, '27-periodic-kernel.png'));
end
state.Views.SelectedTab = state.ChartTabs.Parent.Parent;
state.ChartTabs.SelectedTab = state.ChartTabs.Children(strcmp({state.ChartTabs.Children.Title}, '周期探索（周辺尤度）'));
chart_file = [tempname, '.png']; chart_cleanup = onCleanup(@() delete(chart_file));
drawnow; exportgraphics(app.Panels{2}.Figures{1}, chart_file, 'Resolution', 100); assert(isfile(chart_file));
if ~isempty(image_folder), exportapp(app.Window, fullfile(image_folder, '28-periodic-search.png')); end
app.SettingsUI.Kernel.Value = 'matern32'; app.SettingsUI.SwingKernel.Value = 'swingperiodic'; app.saveSettings();
assert(strcmp(app.Panels{2}.Kernel.Value, 'swingperiodic'));
assert(strcmp(app.Panels{1}.Kernel.Value, 'matern32')); assert(strcmp(app.Panels{3}.Kernel.Value, 'matern32'));
assert(~any(strcmp({state.Views.Children.Title}, '周期の最適化'))); assert(isempty(state.ChartTabs.Children));
assert(~any(contains(string(state.ModelInfo.Value), '80')));
if ~isempty(image_folder)
    app.SettingsUI.SaveFolder.Value = 'C:\Analysis\Results（表示例）';
    app.SettingsUI.Message.Text = '設定保存先: prefdir / StandaloneAnalysisApp / settings.json（表示例）';
    main.SelectedTab = app.SettingsUI.Kernel.Parent.Parent.Parent;
    drawnow; pause(0.5); exportapp(app.Window, fullfile(image_folder, '08-settings.png'));
    main.SelectedTab = main.Children(strcmp({main.Children.Title}, '9 Help'));
    scroll(main.SelectedTab.Children(1), 'bottom'); drawnow; pause(0.5);
    exportapp(app.Window, fullfile(image_folder, '09-help.png'));
end
assert(numel(findall(groot, 'Type', 'figure')) == 1);
fprintf('Periodic UI: Swing-only selection, profile table/chart, PNG, settings, stale-result removal: PASS\n');
end

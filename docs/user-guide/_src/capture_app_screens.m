function capture_app_screens()
% 手順書用の画面画像を、実際のアプリを同梱サンプルで操作して撮影する。
% 学習は実際の fitrgp を使う。R2025b 以外では SHAP だけ代替計算へ差し替える（tests/approximate_shap_for_check.m）。
% 設定とログは一時フォルダへ保存し、利用者の設定を変更しない。
source_folder = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(fileparts(source_folder)));
images = fullfile(fileparts(source_folder), 'images');
addpath(fullfile(root, 'core'), fullfile(root, 'app'), fullfile(root, 'tests'));
PAUSE_SECONDS = 1.2;
EXAMPLE_FOLDER = 'C:\work\analysis';
EXAMPLE_SETTINGS_TEXT = '設定ファイル: C:\Users\(ユーザー名)\AppData\...\StandaloneAnalysisApp\settings.json';
work = tempname; mkdir(work); cleanup_work = onCleanup(@() rmdir(work, 's'));
sample = fullfile(root, 'samples', 'ProcessInsight_Samples.xlsx');
window = uifigure('Position', [40, 40, AnalysisController.WINDOW_SIZE], 'Visible', 'on');
cleanup_window = onCleanup(@() delete(window));
app = AnalysisController(window, 'pro', work);
app.AlertFcn = @(text, title_text, icon) fprintf('%s [%s] %s\n', title_text, icon, text);
if ~app.IsTargetRelease
    services = app.Services; services.Shap = @approximate_shap_for_check; services.Denoise = @approximate_denoise_for_check;
    app.Services = services;
end

app.selectPage('home'); snap('50-home');

% --- APC：4ステップ ---
app.selectPage('apc'); apc = app.page('apc'); apc.openSample(); snap('51-data-step');
apc.selectTargets({'CD_X', 'CD_Y'}); apc.Steps.SelectedTab = apc.StepTabs.Variables; apc.confirm(); snap('52-variables-apc');
apc.Kernels.Value = {'squaredexponential', 'matern52'}; apc.Kernels.ValueChangedFcn([], []);
apc.Steps.SelectedTab = apc.StepTabs.Conditions; snap('55-conditions');
apc.runModeling(); apc.selectRow(1); snap('57-results');
chart_tabs = apc.Result.ChartTabs.Children; apc.Result.ChartTabs.SelectedTab = chart_tabs(strcmp({chart_tabs.Title}, 'SHAP 分布')); snap('58-results-shap');
model_path = fullfile(work, 'Train_Model_CD_X.mat'); apc.saveSelectedTo(model_path); snap('59-results-verification');

% --- Swing Curve ---
app.selectPage('swing'); swing = app.page('swing'); swing.openSample(); swing.selectTargets({'CD_X'});
swing.setSwingVariables(swing.MODE_WITH, 'RESIST_TH', {'SIN_TH', 'SIN_RN', 'NSG_TH'});
swing.Steps.SelectedTab = swing.StepTabs.Variables; swing.confirm(); snap('53-variables-swing');
swing.Kernels.Value = {'swingperiodic'}; swing.Kernels.ValueChangedFcn([], []);
swing.Steps.SelectedTab = swing.StepTabs.Conditions; snap('56-conditions-swing');
swing.Source.open(sample, 'Swing_NoBase', 1); swing.selectTargets({'CD_X'});
swing.setSwingVariables(swing.MODE_WITHOUT, 'RESIST_TH'); swing.confirm(); swing.runModeling();
chart_tabs = swing.Result.ChartTabs.Children; swing.Result.ChartTabs.SelectedTab = chart_tabs(startsWith({chart_tabs.Title}, '周期探索')); snap('60-period-search');
swing.ExpandButton.Value = true; swing.ExpandButton.ValueChangedFcn([], []);
swing.Result.ChartTabs.SelectedTab = chart_tabs(contains({chart_tabs.Title}, 'RESIST_TH')); snap('70-expanded-pro-fit');
swing.ExpandButton.Value = false; swing.ExpandButton.ValueChangedFcn([], []);

% --- 汎用回帰 ---
app.selectPage('generic'); generic = app.page('generic'); generic.openSample();
generic.selectPredictors({'X1', 'X2', 'X3'}); generic.selectTargets({'Y1'});
generic.Steps.SelectedTab = generic.StepTabs.Variables; generic.confirm(); snap('54-variables-generic');
generic.Regressors.linear.Value = true; generic.Regressors.pls.Value = true; generic.Regressors.pls.ValueChangedFcn([], []);
generic.Steps.SelectedTab = generic.StepTabs.Conditions; snap('71-conditions-generic');
generic.runModeling(); chart_tabs = generic.Result.ChartTabs.Children;
generic.Result.ChartTabs.SelectedTab = chart_tabs(startsWith({chart_tabs.Title}, '条件の比較')); snap('72-results-generic');

% --- 炉内補間 ---
app.selectPage('furnace'); furnace = app.page('furnace'); furnace.openSample();
furnace.Steps.SelectedTab = furnace.StepTabs.Columns; furnace.confirm(); snap('63-furnace-columns');
furnace.Steps.SelectedTab = furnace.StepTabs.Conditions; snap('73-furnace-conditions');
furnace.run(); snap('64-furnace-results');

% --- 推定・SHAP ---
app.selectPage('predict'); predict_page = app.page('predict');
predict_page.openModel(model_path); predict_page.Source.open(sample, 'Predict_SHAP', 1);
predict_page.Actual.Value = 'CD_X'; predict_page.confirm(); predict_page.run(); snap('61-predict');
app.selectPage('shap'); shap_page = app.page('shap'); [~, ids] = app.Models.list(); shap_page.selectModel(ids(1));
shap_page.Source.open(sample, 'Predict_SHAP', 1); shap_page.confirm(); shap_page.run(); snap('62-shap-page');

% --- 実験計画・ワードクラウド・設定・Help ---
app.selectPage('doe'); design = app.page('doe'); design.run(); design.Result.showCharts(); snap('65-doe');
app.selectPage('words'); words = app.page('words'); words.loadText(fullfile(root, 'samples', 'sample_wordcloud.txt')); words.run(); snap('66-wordcloud');
% 設定画面の画像には、撮影した端末のフォルダ名を写さない（表示だけを例の値へ置き換える）。
app.selectPage('settings'); settings_page = app.page('settings');
actual_folder = settings_page.Fields.SaveFolder.Value; actual_path = settings_page.PathInfo.Text;
settings_page.Fields.SaveFolder.Value = EXAMPLE_FOLDER; settings_page.PathInfo.Text = EXAMPLE_SETTINGS_TEXT;
snap('67-settings');
settings_page.Fields.SaveFolder.Value = actual_folder; settings_page.PathInfo.Text = actual_path;
app.selectPage('help'); snap('68-help');
settings_page.Fields.Theme.Value = 'ダーク'; settings_page.save();
app.selectPage('apc'); snap('69-dark-theme');

    function snap(name)
        drawnow; pause(PAUSE_SECONDS);
        exportapp(window, fullfile(images, [name '.png']));
        fprintf('saved %s\n', name);
    end
end

classdef AnalysisController < handle
    % アプリ全体の入れ物。左のメニュー、設定、起動中のモデル一覧、ダイアログをまとめ、
    % 各機能の画面は機能別のクラス（ModelingPage など）へ任せる。
    properties (SetAccess = private)
        Window
        Edition
        Settings
        SettingsPath
        LogFolder
        ProjectRoot
        Models
        Navigation
        Constants
        IsTargetRelease
    end
    properties
        % 学習・推定・SHAPの実処理。テストでは代替の関数へ差し替える。
        Services
        % ファイル選択と通知。テストではダイアログを開かない関数へ差し替える。
        OpenFileFcn = []
        SaveFileFcn = []
        AlertFcn = []
    end
    properties (Access = private)
        PageObjects
        PageBuilders
        LastFolder = ''
        SettingsWarning = ''
    end
    properties (Constant)
        WINDOW_SIZE = [1360, 860]
        APP_NAME = 'Process Insight Tool'
        HOME_KEY = 'home'
    end
    methods
        function app = AnalysisController(window, edition, storage_folder)
            % storage_folder を指定すると、設定とログをそのフォルダへ保存する（動作確認用）。
            app.ProjectRoot = fileparts(fileparts(mfilename('fullpath')));
            % 配布版ではすべての関数を同梱済みのため、パスを変更しない。
            if ~isdeployed, addpath(fullfile(app.ProjectRoot, 'core')); end
            require_r2025b();
            if nargin < 2 || isempty(edition), edition = app_edition(); end
            if nargin < 3, storage_folder = fullfile(prefdir, 'StandaloneAnalysisApp'); end
            if ~any(strcmp(edition, {'standard', 'pro'})) || (isdeployed && ~strcmp(edition, app_edition()))
                error('AnalysisApp:edition', 'この実行ファイルの版は変更できません。');
            end
            app.Edition = edition; app.Constants = model_constants();
            app.IsTargetRelease = strcmp(version('-release'), app.Constants.REQUIRED_RELEASE);
            app.SettingsPath = fullfile(storage_folder, 'settings.json');
            app.LogFolder = fullfile(storage_folder, 'logs');
            try
                app.Settings = app_settings('load', app.SettingsPath);
            catch err
                app.Settings = app_settings('defaults'); app.SettingsWarning = err.message;
            end
            app.Models = ModelStore();
            app.Services = struct('Trainer', @train_modeling_candidate, ...
                'Predictor', @(model, inputs) predict(model, format_model_input(model, inputs)), ...
                'Shap', @calc_shap_dependence, 'Denoise', @denoise_for_swing_curve, 'LoadModel', @load_analysis_model);
            app.Window = window; window.Name = app.windowTitle();
            window.Position(3:4) = app.WINDOW_SIZE; window.Resize = 'on';
            app.PageObjects = containers.Map('KeyType', 'char', 'ValueType', 'any');
            app.PageBuilders = containers.Map('KeyType', 'char', 'ValueType', 'any');
            app.Navigation = AnalysisNavigation(window);
            app.addPage(app.HOME_KEY, 'ホーム（はじめに）', @(parent) HomePage(app, parent));
            % メニューの番号は版で違う（Pro 版だけの画面を通常版では出さず、番号を詰める）。名前と番号は menuTitles で1か所にまとめる。
            titles = AnalysisController.menuTitles(edition); pro = strcmp(edition, 'pro');
            app.Navigation.addHeading('モデルを作る');
            app.addPage('apc', titles.apc, @(parent) ModelingPage(app, parent, 'apc'));
            app.addPage('swing', titles.swing, @(parent) ModelingPage(app, parent, 'swing'));
            app.addPage('generic', titles.generic, @(parent) ModelingPage(app, parent, 'generic'));
            app.addPage('furnace', titles.furnace, @(parent) FurnacePage(app, parent));
            app.Navigation.addHeading('モデルを使う・調べる');
            app.addPage('predict', titles.predict, @(parent) ModelUsePage(app, parent));
            if pro
                % データ（Excel / CSV）を取り込んで解析する画面。Sobol感度解析は保存モデルでも使える。
                app.Navigation.addHeading('データを解析する（Pro版）');
                app.addPage('sobol', titles.sobol, @(parent) SobolPage(app, parent));
                app.addPage('causal', titles.causal, @(parent) CausalPage(app, parent));
                app.addPage('bayes', titles.bayes, @(parent) BayesPage(app, parent));
                app.addPage('copula', titles.copula, @(parent) CopulaPage(app, parent));
            end
            app.Navigation.addHeading('計画・その他');
            app.addPage('doe', titles.doe, @(parent) DesignPage(app, parent));
            if pro, app.addPage('words', titles.words, @(parent) WordCloudPage(app, parent)); end
            app.Navigation.addHeading('アプリ');
            app.addPage('settings', titles.settings, @(parent) SettingsPage(app, parent));
            app.addPage('help', titles.help, @(parent) HelpPage(app, parent));
            app.Navigation.SelectionChangedFcn = @(key) app.pageSelected(key);
            app.selectPage(app.HOME_KEY);
            if ~isempty(app.SettingsWarning)
                app.page(app.HOME_KEY).message(['設定ファイルを読めないため初期値を使用しています: ' app.SettingsWarning]);
            end
        end
        function selectPage(app, key)
            app.ensurePage(key); app.Navigation.select(key);
        end
        function object = page(app, key)
            % 画面は初めて開くときに作成する（起動を速くするため）。
            app.ensurePage(key); object = app.PageObjects(key);
        end
        function applySettings(app, proposed)
            app.Settings = app_settings('save', app.SettingsPath, proposed);
            keys = app.PageObjects.keys();
            for index = 1:numel(keys)
                object = app.PageObjects(keys{index}); object.onSettingsChanged();
            end
            app.applyTheme();
        end
        function applyTheme(app)
            apply_app_theme(app.Window, app.Settings.Theme, app.Settings.FontSize);
            app.Navigation.applyTheme(app.Settings.Theme);
        end
        function path = chooseOpenFile(app, filter, title_text)
            if ~isempty(app.OpenFileFcn), path = app.OpenFileFcn(filter, title_text); return; end
            [name, folder] = uigetfile(filter, title_text, app.startFolder());
            app.bringToFront(); path = '';
            if isequal(name, 0), return; end
            path = fullfile(folder, name); app.LastFolder = folder;
        end
        function path = chooseSaveFile(app, filter, title_text, default_name)
            if ~isempty(app.SaveFileFcn), path = app.SaveFileFcn(filter, title_text, default_name); return; end
            [name, folder] = uiputfile(filter, title_text, fullfile(app.startFolder(), default_name));
            app.bringToFront(); path = '';
            if isequal(name, 0), return; end
            path = fullfile(folder, name); app.LastFolder = folder;
        end
        function alert(app, text, title_text, icon)
            if nargin < 4, icon = 'error'; end
            if ~isempty(app.AlertFcn), app.AlertFcn(text, title_text, icon); return; end
            uialert(app.Window, text, title_text, 'Icon', icon);
        end
        function dialog = startProgress(app, title_text, message, cancelable)
            % 処理中は画面全体の操作を止める（モーダル表示）。
            if nargin < 4, cancelable = false; end
            dialog = uiprogressdlg(app.Window, 'Title', title_text, 'Message', message, ...
                'Indeterminate', 'on', 'Cancelable', matlab.lang.OnOffSwitchState(cancelable));
            drawnow;
        end
        function logTraining(app, owner, entry)
            try
                write_training_log(app.LogFolder, entry);
            catch err
                owner.message(['ログを保存できませんでした: ' err.message]);
            end
        end
        function path = resourcePath(app, varargin)
            % 同梱ファイル（samples、docs）の場所。ソース実行・ZIPで配った exe・インストーラーで入れた exe で
            % 置き場所が異なるため、exe のフォルダ、起動時のフォルダ、展開先（ctfroot）の順に探す。
            relative = fullfile(varargin{:}); roots = {app.ProjectRoot};
            if isdeployed, roots = [roots, {deployed_app_folder(), pwd, ctfroot, fileparts(app.ProjectRoot)}]; end
            roots = roots(~cellfun(@isempty, roots));
            path = fullfile(roots{1}, relative);
            for index = 1:numel(roots)
                candidate = fullfile(roots{index}, relative);
                if isfile(candidate), path = candidate; return; end
            end
            if ~isdeployed, return; end
            % exe に含めたファイルは、展開先の下の階層に置かれる場合がある。名前とフォルダ名で探す。
            [~, name, extension] = fileparts(relative); [parent, ~] = fileparts(relative);
            [~, parent_name] = fileparts(parent);
            found = dir(fullfile(ctfroot, '**', [name extension]));
            for index = 1:numel(found)
                [~, folder_name] = fileparts(found(index).folder);
                if strcmp(folder_name, parent_name), path = fullfile(found(index).folder, found(index).name); return; end
            end
        end
        function text = releaseNotice(app)
            text = '';
            if ~app.IsTargetRelease
                text = sprintf('検証用の起動です（MATLAB R%s）。ここで保存したモデルは制御に使用しないでください。製品はR%sで使用します。', ...
                    version('-release'), app.Constants.REQUIRED_RELEASE);
            end
        end
    end
    methods (Static)
        function closeProgress(dialog)
            if ~isempty(dialog) && isvalid(dialog), close(dialog); end
        end
        function titles = menuTitles(edition)
            % 左のメニューの名前（番号つき）。Pro 版だけの画面（Sobol感度解析・因果探索・階層ベイズ・コピュラ乱数生成・ワードクラウド）は通常版に出さない。
            keys = {'apc', 'swing', 'generic', 'furnace', 'predict', 'sobol', 'causal', 'bayes', 'copula', 'doe', 'words', 'settings', 'help'};
            names = {'APC 学習', 'Swing Curve学習', '汎用回帰学習', '炉内補間', '保存モデルで推定・SHAP', 'Sobol感度解析', ...
                '因果探索', '階層ベイズ', 'コピュラ乱数生成', '実験計画作成', 'ワードクラウド', '設定', 'Help'};
            pro_only = {'sobol', 'causal', 'bayes', 'copula', 'words'};
            titles = struct(); number = 0;
            for index = 1:numel(keys)
                if ~strcmp(edition, 'pro') && ismember(keys{index}, pro_only), continue; end
                number = number + 1; titles.(keys{index}) = sprintf('%d %s', number, names{index});
            end
        end
        function text = settingsTitle(edition)
            titles = AnalysisController.menuTitles(edition); text = titles.settings;
        end
        function text = helpTitle(edition)
            titles = AnalysisController.menuTitles(edition); text = titles.help;
        end
    end
    methods (Access = private)
        function addPage(app, key, title_text, builder)
            app.Navigation.addPage(key, title_text); app.PageBuilders(key) = builder;
        end
        function ensurePage(app, key)
            if isKey(app.PageObjects, key), return; end
            if ~isKey(app.PageBuilders, key), error('AnalysisApp:page', '画面が見つかりません: %s', key); end
            builder = app.PageBuilders(key);
            app.PageObjects(key) = builder(app.Navigation.page(key));
            app.applyTheme();
        end
        function pageSelected(app, key)
            app.ensurePage(key); object = app.PageObjects(key); object.onShown();
        end
        function title_text = windowTitle(app)
            title_text = app.APP_NAME;
            if strcmp(app.Edition, 'pro'), title_text = [title_text ' Pro']; end
            if ~app.IsTargetRelease
                title_text = sprintf('%s【検証用 R%s：保存モデルを制御に使用しない】', title_text, version('-release'));
            end
        end
        function folder = startFolder(app)
            folder = app.LastFolder;
            if isempty(folder) || ~isfolder(folder), folder = app.Settings.SaveFolder; end
        end
        function bringToFront(app)
            % ファイル選択後にアプリが他のウィンドウの後ろへ隠れるのを防ぐ。
            if isvalid(app.Window), figure(app.Window); end
        end
    end
end

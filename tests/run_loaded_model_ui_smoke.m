function run_loaded_model_ui_smoke()
% ファイル選択とモデル読込だけを合成値へ置換し、2画面への受渡しを確認する。
[app, cleanup, folder] = create_display_preview(); %#ok<ASGLU>
writeStub(fullfile(folder, 'uigetfile.m'), ...
    "function [name, folder] = uigetfile(varargin)" + newline + ...
    "name = 'synthetic.mat'; folder = tempdir;" + newline + "end" + newline);
writeStub(fullfile(folder, 'load_train_model.m'), ...
    "function model = load_train_model(varargin)" + newline + ...
    "model = struct('X',table((1:8)','VariableNames',{'RESIST_TH'}),'PredictorNames',{{'RESIST_TH'}},'ResponseName','y','KernelFunction','squaredexponential');" + newline + ...
    "end" + newline);
addpath(folder, '-begin'); clear uigetfile load_train_model; rehash;
functions_cleanup = onCleanup(@clearStubs); %#ok<NASGU>
assert(strcmp(which('load_train_model'), fullfile(folder, 'load_train_model.m')));
app.loadModel(4);
assert(numel(app.ModelRegistry) == 1);
assert(~isempty(app.Panels{4}.Model));
assert(~isfield(app.Panels{4}, 'ShapModel'));
assert(strcmp(app.Panels{4}.ModelPath, fullfile(tempdir, 'synthetic.mat')));
assert(~contains(app.Panels{4}.Messages.Value{end}, 'ShapModel'));
app.loadModel(5);
assert(numel(app.ModelRegistry) == 2);
assert(app.Panels{5}.ShapModel.Value == 2);
assert(strcmp(app.Panels{5}.SelectedModelKind, 'loaded'));
assert(isequal(app.Panels{5}.Model, app.ModelRegistry(2).Model));
assert(~app.Panels{5}.Confirmed);
assert(isempty(dir(fullfile(folder, '*.mat'))));
fprintf('Loaded model UI: prediction and SHAP routing with synthetic loader, no RegressionGP/MAT I/O: PASS\n');
end

function writeStub(path, source)
file = fopen(path, 'w'); cleanup = onCleanup(@() fclose(file));
fprintf(file, '%s', source);
end

function clearStubs()
clear uigetfile load_train_model;
end

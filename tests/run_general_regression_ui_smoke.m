function run_general_regression_ui_smoke(image_folder)
% GPRと実SHAPだけを代替し、重回帰/PLS・MAT保存/読込は実処理で確認する。
if nargin<1, image_folder=''; end
[app,cleanup,folder]=create_display_preview('pro'); %#ok<ASGLU>
app.Window.Position=[40,40,1600,860];
t=(1:48)'; matrix=[sin(t),cos(t/4),800+5*t,sin(t/3),900+7*t];
responses=[2+3*matrix(:,1)-4*matrix(:,2),5-2*matrix(:,1)+matrix(:,2)];
source=struct('FileName','synthetic_aliases.csv','Headers',{{'BaseA','BaseB','Resist_nm','BaseAlternate','ThicknessAlternate','Response','Response2'}}, ...
    'Cells',{num2cell([matrix,responses])},'RowNumbers',t+1);
swing=app.Panels{2}; swing.Data=source; app.Panels{2}=swing; app.initializeTrainingColumns(2); app.updateMapping(2);
swing.ResistColumn.Value='Resist_nm'; swing.ResistColumn.ValueChangedFcn(swing.ResistColumn,[]);
swing.Mode.Value='下地あり'; swing.Mode.ValueChangedFcn(swing.Mode,[]);
assert(strcmp(swing.Underlayers.Enable,'on') && isequal(swing.Views.SelectedTab,swing.ModelingTab));
swing.Underlayers.Value={'BaseA','BaseB'}; swing.Underlayers.ValueChangedFcn(swing.Underlayers,[]);
swing.Targets.Value={'Response','Response2'}; swing.Targets.ValueChangedFcn(swing.Targets,[]);
assert(swing.Mapping.ColumnEditable(3) && size(swing.Mapping.Data,1)==3);
swing.Mapping.Data{1,3}='BaseAlternate'; swing.Mapping.CellEditCallback(swing.Mapping,[]);
swing.Mapping.Data{3,3}='ThicknessAlternate'; swing.Mapping.CellEditCallback(swing.Mapping,[]);
assert(ismember('BaseAlternate',swing.Underlayers.Value)); assert(strcmp(swing.ResistColumn.Value,'ThicknessAlternate'));
app.confirmMapping(2); assert(app.Panels{2}.Confirmed,swing.Messages.Value{end});
app.SettingsUI.FitMethod.Value='sr'; app.saveSettings();
assert(isequal(swing.Mapping.Data(:,3),{'BaseAlternate';'BaseB';'ThicknessAlternate'}));
for index=1:3
    state=app.Panels{index}; assert(~isfield(state,'FitMethod') && ~isprop(state.Study,'FitMethods'));
    assert(contains(state.FitInfo.Text,'sr') && contains(state.Study.FitInfo.Text,'sr'));
end
app.openFurnace(); options=app.Furnace.evaluationOptions(); assert(strcmp(options.FitMethod,'sr'));
app.MainTabs.SelectedTab=swing.Layout.Parent; swing.Views.SelectedTab=swing.ModelingTab; drawnow;
if ~isempty(image_folder), exportapp(app.Window,fullfile(image_folder,'41-swing-column-mapping.png')); end
generic=app.Panels{3}; generic.Data=source; app.Panels{3}=generic;
generic.InputCount.Value=2; app.genericInputsChanged(3); app.initializeTrainingColumns(3); app.updateMapping(3);
generic.Targets.Value={'Response','Response2'}; generic.Targets.ValueChangedFcn(generic.Targets,[]);
services=struct('Trainer',@train,'Predictor',@(model,x)predict(model,x),'Shap',@shap);
for method={'linear','pls'}
    generic.Mode.Value=method{1}; generic.Mode.ValueChangedFcn(generic.Mode,[]);
    assert(strcmp(generic.Kernel.Enable,'off')); app.confirmMapping(3); assert(app.Panels{3}.Confirmed);
    app.runModeling(3,false,services);
end
assert(numel(app.ModelRegistry)==4);
generic.Study.Regressors.Value={'gpr','linear','pls'}; generic.Study.Kernels.Value={'squaredexponential','matern52'};
generic.Mode.Value='gpr'; generic.Study.Regressors.ValueChangedFcn(generic.Study.Regressors,[]);
assert(strcmp(generic.PLSComponents.Enable,'on') && strcmp(generic.Kernel.Enable,'on'));
generic.Mode.Value='pls'; generic.Mode.ValueChangedFcn(generic.Mode,[]);
generic.Study.Folds.Value=3; app.confirmMapping(3); assert(app.Panels{3}.Confirmed); app.runModeling(3,true,services);
assert(numel(app.ModelRegistry)==12 && height(generic.Study.Summary.Data)==12);
assert(all(cellfun(@(record)strcmp(record.Status,'成功'),app.ModelingRecords)));
assert(sum(cellfun(@(record)strcmp(record.Condition.Regressor,'gpr'),app.ModelingRecords))==4);
generic.Study.Selection.Value=1;
writeStub(fullfile(folder,'uiputfile.m'),[
    "function [name,folder]=uiputfile(varargin)"
    "folder=fileparts(mfilename('fullpath')); name='selected_regression.mat';"
    "end"]);
writeStub(fullfile(folder,'uigetfile.m'),[
    "function [name,folder]=uigetfile(varargin)"
    "folder=fileparts(mfilename('fullpath')); name='selected_regression.mat';"
    "end"]);
addpath(folder,'-begin'); clear uiputfile uigetfile; rehash;
stub_cleanup=onCleanup(@clearStubs);
app.saveSelectedModel(3); saved=fullfile(folder,'selected_regression.mat'); assert(isfile(saved));
loaded=load_analysis_model(saved); assert(strcmp(loaded.Method,'linear'));
app.loadModel(4); predict_state=app.Panels{4}; assert(isa(predict_state.Model,'ProcessRegressionModel'));
predict_state.Data=struct('FileName','synthetic_prediction.csv','Headers',{{'入力1','入力2','Response'}}, ...
    'Cells',{num2cell([matrix(:,1:2),responses(:,1)])},'RowNumbers',t+1);
predict_state.Actual.Items={'(実測値なし)','Response'}; predict_state.Actual.Value='Response'; app.Panels{4}=predict_state;
app.updateMapping(4); app.confirmMapping(4); assert(app.Panels{4}.Confirmed); app.run(4);
assert(max(abs(predict_state.Results.Data.y_pred-responses(:,1)))<1e-10);
app.MainTabs.SelectedTab=generic.Layout.Parent; generic.Views.SelectedTab=generic.Study.Tab; drawnow;
if ~isempty(image_folder), exportapp(app.Window,fullfile(image_folder,'42-general-regression.png')); end
assert(numel(findall(groot,'Type','figure'))==1);
fprintf('General regression UI: Swing aliases and edits, settings-only Fit method, real linear/PLS comparison and MAT roundtrip, prediction: PASS\n');
end
function [model,warnings,details]=train(x,y,c,~)
method=c.Regressor;
if strcmp(method,'gpr'), assert(strcmp(c.FitMethod,'sr')); method='linear'; end
model=ProcessRegressionModel(x,y,{'入力1','入力2'},method,c.Components); warnings=[]; details=[];
end
function [object,values]=shap(model,x)
object=[]; values=(x-mean(model.X,1)).*model.Coefficients';
end
function writeStub(path,lines)
file=fopen(path,'w'); cleanup=onCleanup(@()fclose(file)); fprintf(file,'%s\n',lines);
end
function clearStubs(), clear uigetfile uiputfile; end

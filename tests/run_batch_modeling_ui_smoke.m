function run_batch_modeling_ui_smoke(image_folder)
% 合成学習器とSHAP値だけで、保存前の一括評価・履歴・選択保存を確認する。
if nargin<1, image_folder=''; end
[app,cleanup,folder]=create_display_preview('pro'); %#ok<ASGLU>
app.Window.Position=[40,40,1600,780]; drawnow;
marker=fullfile(folder,'save-dialog-called.txt');
file=fopen(fullfile(folder,'uiputfile.m'),'w');
fprintf(file,'function [name,folder]=uiputfile(varargin)\nf=fopen(''%s'',''w''); fclose(f); name=0; folder=0;\nend\n',strrep(marker,'''','''''')); fclose(file);
addpath(folder,'-begin'); clear uiputfile; function_cleanup=onCleanup(@clearDialogStub);
t=(1:60)'; x=[sin(t/3),cos(t/5),sin(t/7),800+7*t]; y=[2+x*[1;2;3;0.01],5+x*[2;-1;4;0.02]];
source=struct('FileName','合成データ・GPR未学習.xlsx','Headers',{{'SIN_TH','SIN_RN','NSG_TH','RESIST_TH','CD','CD2','Batch'}}, ...
    'Cells',{[num2cell([x,y]),cellstr("B"+string(mod(t,2)))]},'RowNumbers',t+1);
state=app.Panels{1}; state.Data=source; app.Panels{1}=state; app.initializeTrainingColumns(1); app.updateMapping(1);
state.Targets.Value={'CD','CD2'}; app.confirmMapping(1); assert(app.Panels{1}.Confirmed);
period=app.Panels{2}; period.CustomPeriod.Value=true; period.PeriodLower.Value=180; period.PeriodUpper.Value=100;
services=service(state.Mapping.Data(:,2)'); app.runModeling(1,false,services);
assert(numel(app.ModelingRecords)==2 && numel(app.ModelRegistry)==2);
assert(all(cellfun(@(r)strcmp(r.ShapStatus,'成功'),app.ModelingRecords)));
assert(~isfile(marker),'学習中に保存ダイアログが開きました。');
state.Study.Kernels.Value={'squaredexponential','matern32'}; state.Study.Folds.Value=3;
app.runModeling(1,true,services); assert(numel(app.ModelingRecords)==6); assert(height(state.Study.Summary.Data)==6);
assert(strcmp(app.ModelingRecords{3}.Scope,'3分割交差検証'));
app.invalidate(1); assert(height(state.Study.Summary.Data)==6);
state.Study.Selection.Value=1; app.displaySelectedModel(1);
assert(isequal(state.Results.Data.Actual,y(:,1))); assert(~isfile(marker));
assert(any(startsWith(string({state.ChartTabs.Children.Title}),'SHAP')));
period.CustomPeriod.Value=false;
app.saveSelectedModel(1); assert(isfile(marker)); assert(isempty(dir(fullfile(folder,'*.mat'))));
app.MainTabs.SelectedTab=state.Layout.Parent; state.Views.SelectedTab=state.Study.Tab; drawnow;
if ~isempty(image_folder), exportapp(app.Window,fullfile(image_folder,'38-modeling-first.png')); end
swing=app.Panels{2}; swing.Data=source; app.Panels{2}=swing; app.initializeTrainingColumns(2); app.updateMapping(2);
swing.Targets.Value={'CD','CD2'}; assert(size(swing.Mapping.Data,1)==1); app.confirmMapping(2);
app.runModeling(2,false,service(swing.Mapping.Data(:,2)')); assert(numel(app.ModelingRecords)==8);
swing.Mode.Value='下地あり'; swing.Underlayers.Value={'SIN_TH','SIN_RN'}; app.updateMapping(2);
assert(size(swing.Mapping.Data,1)==3 && strcmp(swing.Mapping.Data{end,2},'RESIST_TH')); app.confirmMapping(2);
app.runModeling(2,false,service(swing.Mapping.Data(:,2)')); assert(numel(app.ModelingRecords)==10);
app.MainTabs.SelectedTab=swing.Layout.Parent; swing.Views.SelectedTab=swing.Targets.Parent.Parent; drawnow;
if ~isempty(image_folder), exportapp(app.Window,fullfile(image_folder,'39-swing-modes-targets.png')); end
assert(~isfield(app.Panels{6},'Seed')); assert(isequal(app.Panels{6}.Levels.Items,{'2','3','4','5'}));
assert(app.SettingsUI.Runs.Value==25);
app.SettingsUI.RBFWidth.Value=12; app.SettingsUI.RBFRidge.Value=1e-4; app.saveSettings(); app.openFurnace();
assert(~isprop(app.Furnace,'RBFWidth') && ~isprop(app.Furnace,'RBFRidge'));
options=app.Furnace.evaluationOptions(); assert(options.RBFWidth==12 && options.RBFRidge==1e-4);
assert(numel(app.ModelRegistry)==10 && height(swing.Study.Summary.Data)==4);
assert(numel(findall(groot,'Type','figure'))==1);
fprintf('Batch UI: multiple targets, train/SHAP before save, condition history, selected save, Swing modes, settings-only seed/RBF, single window: PASS\n');
end
function s=service(names)
s=struct('Trainer',@(x,y,c,~)train(x,y,c,names),'Predictor',@(m,x)[ones(size(x,1),1),x]*m.Coefficients,'Shap',@shap);
end
function [model,warnings,details]=train(x,y,c,names)
model=struct('X',x,'PredictorNames',{names},'ResponseName','y','KernelFunction',c.Kernel,'Coefficients',[ones(size(x,1),1),x]\y);
warnings=[]; details=[];
end
function [object,values]=shap(model,x)
object=[]; values=x.*model.Coefficients(2:end)'; values(:,end)=values(:,end)+sin(2*pi*x(:,end)/140);
end
function clearDialogStub(), clear uiputfile; end

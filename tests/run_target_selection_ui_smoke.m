function run_target_selection_ui_smoke(image_folder)
% ダイアログの応答だけを置換し、実ファイル読込み後の目的変数選択を確認する。
if nargin<1, image_folder=''; end
[app,preview_cleanup,folder]=create_display_preview(); %#ok<ASGLU>
root=fileparts(fileparts(mfilename('fullpath')));
workbook=fullfile(root,'samples','ProcessInsight_Samples.xlsx');
writeStub(fullfile(folder,'uigetfile.m'),[
    "function [name,folder]=uigetfile(varargin)"
    "input=getappdata(groot,'PITTargetSelectionInput');"
    "[folder,name,extension]=fileparts(input.Path); name=[name extension];"
    "end"]);
writeStub(fullfile(folder,'listdlg.m'),[
    "function [index,accepted]=listdlg(varargin)"
    "input=getappdata(groot,'PITTargetSelectionInput'); index=input.Sheet; accepted=true;"
    "end"]);
writeStub(fullfile(folder,'inputdlg.m'),[
    "function answer=inputdlg(varargin)"
    "answer={'1'};"
    "end"]);
addpath(folder,'-begin'); clear uigetfile listdlg inputdlg; rehash;
stub_cleanup=onCleanup(@clearStubs);
app.Panels{3}.InputCount.Value=3;
sheets=[2,4,5]; targets={{'CD_X','CD_Y'},{'CD_X','CD_Y'},{'Y1','Y2'}};
for index=1:3
    state=app.Panels{index}; assert(strcmp(state.Targets.Enable,'off'));
    setappdata(groot,'PITTargetSelectionInput',struct('Path',workbook,'Sheet',sheets(index)));
    state.Load.ButtonPushedFcn(state.Load,[]);
    state=app.Panels{index}; assert(~isempty(state.Data),state.Messages.Value{end});
    assert(strcmp(state.Targets.Enable,'on'));
    assert(isequal(state.Targets.Parent.Parent,state.Controls));
    assert(state.Targets.Parent.Layout.Row==4);
    assert(all(ismember(targets{index},state.Targets.Items)));
    assert(isempty(state.Targets.Value),'不明な目的変数を最終列から自動選択しています。');
    chooseTargets(state.Targets,targets{index});
    app.confirmMapping(index); assert(app.Panels{index}.Confirmed,state.Messages.Value{end});
    assert(all(cellfun(@(target)contains(state.TargetSummary.Text,target),targets{index})));
end
fprintf('TARGET_TRAINING_READ_PASS\n');
setappdata(groot,'PITTargetSelectionInput',struct('Path',workbook,'Sheet',3));
swing=app.Panels{2}; swing.Load.ButtonPushedFcn(swing.Load,[]);
swing.Mode.Value='下地あり'; swing.Mode.ValueChangedFcn(swing.Mode,[]);
chooseTargets(swing.Targets,{'CD_X','CD_Y'}); app.confirmMapping(2);
assert(app.Panels{2}.Confirmed && size(swing.Mapping.Data,1)==4);
for index=4:5
    state=app.Panels{index}; state.Model=struct('PredictorNames',{{'SIN_TH','SIN_RN','NSG_TH','RESIST_TH'}});
    app.Panels{index}=state;
    setappdata(groot,'PITTargetSelectionInput',struct('Path',workbook,'Sheet',6));
    state.Load.ButtonPushedFcn(state.Load,[]);
    assert(all(ismember({'CD_X','CD_Y'},state.Actual.Items)) && strcmp(state.Actual.Enable,'on'));
    for name={'CD_X','CD_Y'}
        state.Actual.Value=name{1}; state.Actual.ValueChangedFcn(state.Actual,[]);
        app.confirmMapping(index); assert(app.Panels{index}.Confirmed,state.Messages.Value{end});
        assert(strcmp(state.Actual.Value,name{1}));
    end
end
fprintf('TARGET_PREDICTION_SHAP_READ_PASS\n');
app.openFurnace(); furnace=app.Furnace;
setappdata(groot,'PITTargetSelectionInput',struct('Path',workbook,'Sheet',7));
load_button=findall(furnace.Controls,'Type','uibutton','Text','Excel / CSV を開く');
load_button.ButtonPushedFcn(load_button,[]);
assert(~isempty(furnace.Data) && strcmp(furnace.Targets.Enable,'on'));
chooseTargets(furnace.Targets,{'屈折率'}); assert(isequal(furnace.Targets.Value,{'屈折率'}));
chooseTargets(furnace.Targets,{'膜厚_nm','屈折率'}); furnace.confirm(); assert(furnace.Confirmed);
fprintf('TARGET_FURNACE_READ_PASS\n');
source=read_input_data(workbook,'APC',1); source.Headers(5:6)={'MetricA','MetricB'};
csv=fullfile(folder,'changed_targets.csv'); writecell([source.Headers;source.Cells],csv);
setappdata(groot,'PITTargetSelectionInput',struct('Path',csv,'Sheet',1));
state=app.Panels{1}; state.Load.ButtonPushedFcn(state.Load,[]);
assert(~any(ismember({'CD_X','CD_Y'},state.Targets.Items)) && isempty(state.Targets.Value));
chooseTargets(state.Targets,{'MetricA','MetricB'}); app.confirmMapping(1); assert(app.Panels{1}.Confirmed);
controls={app.Panels{1}.Targets,app.Panels{2}.Targets,app.Panels{3}.Targets,app.Panels{4}.Actual,app.Panels{5}.Actual,furnace.Targets};
lock_cleanup=app.lockControls([]); %#ok<NASGU>
assert(all(cellfun(@(control)strcmp(control.Enable,'off'),controls)));
clear lock_cleanup;
assert(all(cellfun(@(control)strcmp(control.Enable,'on'),controls)));
assert(isequal(state.Targets.Value,{'MetricA','MetricB'}));
app.MainTabs.SelectedTab=state.Layout.Parent;
for width=[900,1366]
    app.Window.Position(3:4)=[width,860]; app.resizePanels(); drawnow;
    assert(isequal(state.Targets.Parent.RowHeight,{24,'1x'}));
    assert(state.Controls.RowHeight{4}==136);
    assert(strcmp(state.Controls.Scrollable,'on'));
    if width<1100, assert(state.Controls.Layout.Row==1 && state.Right.Layout.Row==2);
    else, assert(state.Controls.Layout.Column==1 && state.Right.Layout.Column==2); end
end
if ~isempty(image_folder)
    if ~isfolder(image_folder), mkdir(image_folder); end
    exportapp(app.Window,fullfile(image_folder,'target-selection.png'));
end
assert(numel(findall(groot,'Type','figure'))==1);
fprintf('Target selection UI: file-load callbacks, 3 training pages, Swing modes, prediction/SHAP, furnace, reload, lock restoration, resize: PASS\n');
end
function chooseTargets(control,values)
control.Value=values; control.ValueChangedFcn(control,[]);
assert(isequal(cellstr(string(control.Value)),values));
end
function writeStub(path,lines)
file=fopen(path,'w'); cleanup=onCleanup(@()fclose(file));
fprintf(file,'%s\n',lines);
end
function clearStubs()
clear uigetfile listdlg inputdlg;
if isappdata(groot,'PITTargetSelectionInput'), rmappdata(groot,'PITTargetSelectionInput'); end
end

function run_product_ui_smoke(image_folder)
% 合成SHAP値と表示専用コピーによるUI試験。GPR学習・MAT保存・実SHAPは行わない。
if nargin < 1, image_folder = ''; end
if ~isempty(image_folder) && ~isfolder(image_folder), mkdir(image_folder); end
[app, cleanup] = create_display_preview('standard'); %#ok<ASGLU>
app.Window.Visible = 'on'; app.Window.Position = [40, 40, 1600, 1000]; drawnow;
fprintf('PRODUCT_CREATED\n');
for edition = {'standard', 'pro'}
    % 製品の版は書換不可。表示専用コピーの公開プロパティで両条件を補助確認する。
    app.Edition = edition{1}; app.Window.Name = ['Process Insight Tool ' edition{1} ' / R2022b表示専用・GP未学習'];
    for panel = [1,2,5], app.clearOutput(panel); end
    assert(all(cellfun(@(button) strcmp(button.HorizontalAlignment,'left'),app.MainTabs.Buttons)));
    swing = app.Panels{2}; assert(swing.InputCount.Value == 1);
    swing.ShapOpen.ButtonPushedFcn(swing.ShapOpen,[]); assert(strcmp(swing.Views.SelectedTab.Title,'SHAP実行'));
    source = struct('FileName','synthetic.csv','Headers',{{'TH','CD','Batch'}}, ...
        'Cells',{cell(41,3)}, 'RowNumbers',(2:42)'); %#ok<NASGU>
    source.Cells = [num2cell([linspace(800,1250,41)', sin((1:41)')]), cellstr(repmat("A",41,1))];
    source.Cells(2:2:end,3) = {'B'}; swing.Data = source; app.Panels{2} = swing; app.updateMapping(2);
    assert(size(swing.Mapping.Data,1) == 2); assert(strcmp(swing.Mapping.Data{1,2},'RESIST_TH'));
    swing.Mapping.Data(:,3) = {'TH';'CD'}; app.confirmMapping(2); assert(app.Panels{2}.Confirmed);
    options = app.periodOptions(2); assert(abs(options.ReferencePeriod-248/1.77) < 1e-10);
    swing.CustomPeriod.Value = true; swing.PeriodLower.Value = 100; swing.PeriodUpper.Value = 170; app.swingOptionsChanged(2);
    assert(isequal(app.periodOptions(2).PeriodBounds,[100,170])); assert(~app.Panels{2}.Confirmed);
    swing.CustomPeriod.Value = false; app.swingOptionsChanged(2);
    app.displayEvaluation(2,cell2mat(source.Cells(:,1)),(1:41)',(1:41)'+sin((1:41)'), '合成データの表示試験');
    swing = app.Panels{2}; points_tab = swing.ChartTabs.Children(strcmp({swing.ChartTabs.Children.Title},'実測値と予測値'));
    color_view = points_tab.UserData; color_view.update('Batch');
    assert(strcmp(color_view.Choices{2}.Value,'Batch'));
    colors = findobj(color_view.Axes{1},'Type','scatter'); assert(numel(unique(colors.CData)) == 2);
    color_view.update('TH'); colors = findobj(color_view.Axes{1},'Type','scatter'); assert(size(colors.CData,1) == 41 || numel(colors.CData) == 41);
    assert(isequal(swing.Metrics.Data.Metric(7:8),["KLダイバージェンス";"相互情報量"]));
    app.MainTabs.SelectedTab = swing.Layout.Parent; swing.Views.SelectedTab = swing.ChartTabs.Parent.Parent;
    swing.ChartTabs.SelectedTab = points_tab; drawnow;
    if ~isempty(image_folder) && strcmp(edition{1},'standard'), exportapp(app.Window,fullfile(image_folder,'35-scatter-color.png')); end
    folder = fileparts(which(class(app)));
    stub = fullfile(folder,'calc_shap_dependence.m'); file = fopen(stub,'w');
    fprintf(file, 'function [object, values] = calc_shap_dependence(model, inputs)\nglobal PIT_SHAP_MODEL_ID; PIT_SHAP_MODEL_ID = model.Identity; object=[]; values=sin(2*pi*inputs/140)+0.001*inputs;\nend\n'); fclose(file); addpath(folder,'-begin'); clear calc_shap_dependence; rehash;
    assert(strcmp(which('calc_shap_dependence'),stub));
    model = struct('X',linspace(800,1250,41)','PredictorNames',{{'RESIST_TH'}},'ResponseName','y','Identity',17);
    app.registerModel(model,'合成モデル・未保存','swing');
    model.Identity = 23; app.registerModel(model,'合成MAT読込み見本','loaded');
    target = app.Panels{1}; target.ShapModel.Value = 1; app.runSelectedShap(1);
    assert(contains(target.Messages.Value{end},'MAT保存なしでSHAPを計算しました'), strjoin(string(target.Messages.Value),' | '));
    dependency = target.ChartTabs.Children(strcmp({target.ChartTabs.Children.Title},'SHAP 依存: RESIST_TH'));
    assert(isempty(dependency.UserData));
    target = app.Panels{2}; target.ShapModel.Value = 1; app.runSelectedShap(2);
    assert(contains(target.Messages.Value{end},'MAT保存なしでSHAPを計算しました'), strjoin(string(target.Messages.Value),' | '));
    dependency = target.ChartTabs.Children(strcmp({target.ChartTabs.Children.Title},'SHAP 依存: RESIST_TH'));
    global PIT_SHAP_MODEL_ID; assert(PIT_SHAP_MODEL_ID == 17);
    if strcmp(edition{1},'standard')
        assert(isempty(dependency.UserData));
        assert(~any(strcmp({target.ChartTabs.Children.Title},'SHAP Swing Curve近似: 残差分布')));
    else
        view = dependency.UserData; assert(isa(view,'SwingCurveView')); assert(~isempty(view.Fit),view.Summary.Text);
        assert(view.Axes.XAxis.Exponent == 0);
        view.Controls.Method.Value = 'スプライン補間'; view.refit(); assert(strcmp(view.Fit.Method,'spline'),view.Summary.Text);
        assert(isnan(view.Fit.Period)); assert(~view.Diagnostics.Tested);
        view.Controls.RangeMin.Value = 801; view.Controls.RangeMax.Value = 1249; view.refit();
        assert(~isempty(view.Fit),view.Summary.Text); assert(view.Controls.RangeMin.Value == min(view.Fit.DataRange));
        app.MainTabs.SelectedTab = target.Layout.Parent; target.Views.SelectedTab = target.ChartTabs.Parent.Parent;
        target.ChartTabs.SelectedTab = dependency; drawnow;
        if ~isempty(image_folder), exportapp(app.Window,fullfile(image_folder,'36-pro-spline.png')); end
    end
    shap = app.Panels{5}; shap.Data = source; app.Panels{5} = shap;
    shap.ShapModel.Value = 2; app.selectShapModel(5); shap.Mapping.Data(:,3) = {'TH'}; app.confirmMapping(5); app.runSelectedShap(5);
    assert(PIT_SHAP_MODEL_ID == 23);
    assert(isequal(shap.Results.Data.SourceRow,source.RowNumbers));
    app.MainTabs.SelectedTab = shap.Layout.Parent;
    shap.Views.SelectedTab = shap.ShapRun.Parent.Parent; drawnow;
    if ~isempty(image_folder) && strcmp(edition{1},'standard'), exportapp(app.Window,fullfile(image_folder,'37-model-shap.png')); end
    assert(isempty(dir(fullfile(folder,'*.mat'))));
    clear calc_shap_dependence; clear global PIT_SHAP_MODEL_ID;
    fprintf('Product UI %s: navigation, one input, optical range, color columns, model selection, save-free SHAP routing, APC exclusion, edition gate, spline: PASS\n',edition{1});
end
end

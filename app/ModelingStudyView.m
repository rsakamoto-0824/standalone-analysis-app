classdef ModelingStudyView < handle
    properties (SetAccess = private)
        Tab
        Kernels
        FitMethods
        Folds
        Seed
        Start
        Selection
        Show
        Save
        Summary
        Metrics
        Tabs
    end
    methods
        function view = ModelingStudyView(parent, kernels, default_kernel, default_fit, run_callback, show_callback, save_callback)
            view.Tab = uitab(parent,'Title','条件比較・モデル保存');
            grid = uigridlayout(view.Tab,[4,1]); grid.RowHeight={154,36,52,'1x'};
            controls=uigridlayout(grid,[4,4]); controls.Padding=[0,0,0,0]; controls.ColumnWidth={'1.4x','1x',90,100}; controls.RowHeight={24,30,30,38};
            uilabel(controls,'Text','カーネル（複数選択）'); uilabel(controls,'Text','fit_method（複数選択）');
            label=uilabel(controls,'Text','分割数'); label.Layout.Row=2; label.Layout.Column=3;
            view.Folds=uieditfield(controls,'numeric','Value',5,'Limits',[2,10],'RoundFractionalValues','on'); view.Folds.Layout.Row=2; view.Folds.Layout.Column=4;
            view.Kernels=uilistbox(controls,'Items',kernels,'Value',{default_kernel},'Multiselect','on'); view.Kernels.Layout.Row=[2,4]; view.Kernels.Layout.Column=1;
            view.FitMethods=uilistbox(controls,'Items',{'exact','sd','sr','fic'},'Value',{default_fit},'Multiselect','on'); view.FitMethods.Layout.Row=[2,4]; view.FitMethods.Layout.Column=2;
            label=uilabel(controls,'Text','比較seed'); label.Layout.Row=3; label.Layout.Column=3;
            view.Seed=uieditfield(controls,'numeric','Value',0,'Limits',[0,2^32-1],'RoundFractionalValues','on'); view.Seed.Layout.Row=3; view.Seed.Layout.Column=4;
            view.Start=uibutton(controls,'Text','条件を一括評価','ButtonPushedFcn',@(~,~)run_callback()); view.Start.Layout.Row=4; view.Start.Layout.Column=[3,4];
            row=uigridlayout(grid,[1,4]); row.Padding=[0,0,0,0]; row.ColumnWidth={50,'1x',130,140};
            uilabel(row,'Text','モデル'); view.Selection=uidropdown(row,'Items',{'評価待ち'},'ItemsData',0,'Enable','off','ValueChangedFcn',@(~,~)show_callback());
            view.Show=uibutton(row,'Text','評価・SHAPを表示','Enable','off','ButtonPushedFcn',@(~,~)show_callback());
            view.Save=uibutton(row,'Text','選択モデルをMAT保存','Enable','off','ButtonPushedFcn',@(~,~)save_callback());
            uilabel(grid,'Text','学習とSHAPを先に実行し、条件を変えた結果も一覧へ残します。目的変数・単位・評価範囲ごとに比較し、最後に選択モデルを保存します。一括条件が2組以上なら共通分割で交差検証します。','WordWrap','on');
            view.Tabs=uitabgroup(grid);
            tab=uitab(view.Tabs,'Title','比較一覧'); table_grid=uigridlayout(tab,[1,1]); view.Summary=uitable(table_grid,'Data',table());
            tab=uitab(view.Tabs,'Title','全評価指標'); table_grid=uigridlayout(tab,[1,1]); view.Metrics=uitable(table_grid,'Data',table());
        end
        function refresh(view,records,kind)
            rows=cell(0,14); ids=[]; labels={}; all_metrics=table();
            for index=1:numel(records)
                r=records{index}; if ~strcmp(r.Kind,kind), continue; end
                r2=NaN; rmse=NaN; if ~isempty(r.Metrics), r2=r.Metrics.Value(1); rmse=r.Metrics.Value(2); end
                [~,file,extension]=fileparts(r.Source.FileName);
                rows(end+1,:)={r.Id,r.Run,r.Target,r.Condition.Kernel,r.Condition.FitMethod,r2,rmse,r.Scope,r.ShapStatus,r.Status,r.Mode,strjoin(r.InputNames,', '),[file extension],r.Note}; %#ok<AGROW>
                if ~isempty(r.Metrics)
                    for scope=1:2
                        if scope==2 && strcmp(r.Scope,'学習データ'), continue; end
                        values=r.Metrics; label=r.Scope;
                        if scope==2, values=r.TrainingMetrics; label='学習データ'; end
                        values=addvars(values,repmat(r.Id,height(values),1),repmat(string(r.Target),height(values),1),repmat(string(label),height(values),1), ...
                            'Before',1,'NewVariableNames',{'ModelId','Target','Scope'});
                        all_metrics=[all_metrics;values]; %#ok<AGROW>
                    end
                end
                if r.Id>0, ids(end+1)=r.Id; labels{end+1}=sprintf('%d: %s / %s / %s / %s',r.Id,r.Target,r.Condition.Kernel,r.Condition.FitMethod,r.Mode); end %#ok<AGROW>
            end
            view.Summary.Data=cell2table(rows,'VariableNames',{'ModelId','Run','Target','Kernel','FitMethod','R2','RMSE','Scope','SHAP','Status','Mode','Inputs','InputFile','Note'});
            view.Summary.ColumnWidth={58,40,60,145,72,75,85,110,65,60,110,180,150,'auto'};
            view.Metrics.Data=display_metric_names(all_metrics);
            if isempty(ids), return; end
            previous=view.Selection.Value; if ~ismember(previous,ids), previous=ids(end); end
            set(view.Selection,'Items',labels,'ItemsData',ids,'Value',previous,'Enable','on'); view.Show.Enable='on'; view.Save.Enable='on';
        end
        function id=selectedIdentifier(view)
            id=view.Selection.Value;
            if id==0, error('modeling:noModel','保存する学習済みモデルを選択してください。'); end
        end
        function data=currentTable(view)
            if isequal(view.Tabs.SelectedTab,view.Summary.Parent.Parent), data=view.Summary.Data;
            else, data=view.Metrics.Data; end
        end
        function setBusy(view,busy)
            enabled=matlab.lang.OnOffSwitchState(~busy);
            view.Start.Enable=enabled; view.Kernels.Enable=enabled; view.FitMethods.Enable=enabled; view.Folds.Enable=enabled; view.Seed.Enable=enabled;
            if view.Selection.Value>0, view.Selection.Enable=enabled; view.Show.Enable=enabled; view.Save.Enable=enabled; end
        end
    end
end

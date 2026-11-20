function require_pro_feature(feature_name)
% Pro 版だけの機能を、配布した通常版の exe では動かさない。
% ソースから実行する開発・確認では、画面の版に従う（画面側で選択肢を出さない）。
if isdeployed && ~strcmp(app_edition(), 'pro')
    error('AnalysisApp:proOnly', '%s は Pro 版だけで使えます。', feature_name);
end
end

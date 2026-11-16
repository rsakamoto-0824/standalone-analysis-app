function require_r2025b()
% TODO(要確認 Q-03) 制御側と学習・配布側のリリースは R2025b に固定する。
constants = model_constants();
if strcmp(version('-release'), constants.REQUIRED_RELEASE), return; end
% 開発用の例外。配布版では使えず、MATLAB上で環境変数を明示した場合だけ
% 別リリースで動作確認できる。このとき保存したモデルは制御に使用しない。
if ~isdeployed && strcmp(getenv(constants.DEVELOPMENT_RELEASE_VARIABLE), 'allow'), return; end
error('AnalysisApp:wrongRelease', ...
    'MATLAB / MATLAB Runtime R2025b が必要です。現在: R%s', version('-release'));
end

function require_r2025b()
% TODO(要確認 Q-03) 制御側と学習・配布側のリリースは R2025b に固定する。
constants = model_constants();
if ~strcmp(version('-release'), constants.REQUIRED_RELEASE)
    error('AnalysisApp:wrongRelease', ...
        'MATLAB / MATLAB Runtime R2025b が必要です。現在: R%s', version('-release'));
end
end

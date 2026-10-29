function kernel = make_swing_periodic_kernel(period, resist_scale, search_bounds)
% 周期はthetaに含めず、固定した値をカーネル式の内部に保持する。
validateattributes(period, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(resist_scale, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
validateattributes(search_bounds, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite', 'positive'});
roundoff = 10 * eps(max(search_bounds));
if search_bounds(1) >= search_bounds(2) || period < search_bounds(1) - roundoff || period > search_bounds(2) + roundoff
    error('swing_kernel:bounds', '周期は探索範囲内の値を指定してください。');
end
spec = struct('Name', 'swingperiodic', 'Version', 1, 'Period', double(period), ...
    'ResistScale', double(resist_scale), 'SearchBounds', double(search_bounds(:)'));
% @式をこのファイル内で作ると、別PCで読込時に作成元mファイルの警告が残る。
% 固定した式へ検証済み数値だけを埋め込み、作成元のパスを持たない匿名関数にする。
MAX_LOG_PARAMETER = 30;
background = "exp(-0.5*(" + ...
    "((left(:,1)-right(:,1)')/parameters(1)).^2+" + ...
    "((left(:,2)-right(:,2)')/parameters(2)).^2+" + ...
    "((left(:,3)-right(:,3)')/parameters(3)).^2))";
periodic = "exp(-2*(sin(pi*(left(:,4)-right(:,4)')/" + mat2str(period/resist_scale, 17) + ")/parameters(4)).^2)";
covariance = "parameters(5)^2*background+parameters(6)^2*background.*" + periodic + ...
    "+parameters(7)^2*(left(:,4)*right(:,4)')";
parameters = "exp(max(-" + MAX_LOG_PARAMETER + ",min(" + MAX_LOG_PARAMETER + ",theta(:))))";
numeric_function = "@(left,right,theta)feval(@(parameters)feval(@(background)" + covariance + "," + background + ")," + parameters + ")";
information_function = "@(~,~,~)struct('Name','swingperiodic','Version',1,'Period'," + mat2str(spec.Period, 17) + ...
    ",'ResistScale'," + mat2str(spec.ResistScale, 17) + ",'SearchBounds'," + mat2str(spec.SearchBounds, 17) + ")";
invalid_function = "@(~,~,~)error('swing_kernel:parameters','カーネルの学習パラメータは7要素です。周期は別に保持します。')";
% 文字列は周期の情報照会、数値7要素はfitrgp/predictからの共分散計算。
expression = "@(left,right,theta)feval(@(branches)feval(branches{1+isnumeric(theta)+" + ...
    "(isnumeric(theta)&&numel(theta)~=7)},left,right,theta),{" + ...
    information_function + "," + numeric_function + "," + invalid_function + "})";
kernel = str2func(char(expression));
end

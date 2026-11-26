classdef GradientBoostedTrees
    % 勾配ブースティング木。木の育て方で3つの方式を切り替える。
    %   xgboost  ：段ごとに全ての葉を分ける（深さ優先ではなく段ごとの成長）。L2正則化 λ と分岐の最小改善 γ を使う
    %   lightgbm ：改善の最も大きい葉から順に分ける（葉ごとの成長）。葉の数の上限で大きさを決める
    %   catboost ：同じ段では全ての枝が同じ条件で分かれる対称木（oblivious tree）
    % いずれも各説明変数を区間に分けたヒストグラムで分岐を探す。
    % 各ライブラリ（XGBoost・LightGBM・CatBoost）そのものではなく、木の育て方と正則化の考え方を MATLAB で実装したもの。
    % LightGBM の GOSS・EFB は含まない。
    %
    % options（省略可）：
    %   Categorical  説明変数ごとの論理値。質的変数（値は水準の番号 1, 2, …）の列
    %   LevelCounts  説明変数ごとの水準の数（質的変数の列だけ使う）
    %   Loss         'squared'（二乗誤差。平均を予測）または 'quantile'（ピンボール損失。分位点を予測）
    %   Quantile     分位点回帰の分位点 τ（0〜1）
    %   Order        CatBoost の並べ替えに使う、行ごとの値（小さい順に並べる）。空なら乱数の順
    % 質的変数は、xgboost・lightgbm では水準を勾配の比 G/(H+λ) の順に並べ、2つの組に分ける分岐を探す（LightGBM と同じ考え方）。
    % catboost では、並べた順で前の行だけを使う目的変数の平均（Ordered Target Statistics）に置き換える。
    % catboost の順序付きブースティング（OrderedBoosting = 1）では、各行の勾配を、並べた順で前の行だけで学習した
    % モデルの予測から求める（行数の2のべき乗ごとの補助モデルを持つ、CatBoost と同じ近似）。
    properties (SetAccess = private)
        Style
        Parameters
        Intercept
        Edges
        Trees = {}
        TrainingRMSE
        Loss = 'squared'
        Quantile = NaN
        Categorical = []
        % CatBoost の質的変数の置き換えに使う、学習データの水準ごとの目的変数の和と行数。
        CategoryStats = []
    end
    properties (Constant)
        STYLES = {'xgboost', 'lightgbm', 'catboost'}
        MIN_GAIN = 1e-12
        % Ordered Target Statistics の事前分布の重み（CatBoost の既定と同じ1）。
        PRIOR_WEIGHT = 1
    end
    methods
        function model = GradientBoostedTrees(x, y, style, parameters, options)
            if nargin == 0, return; end
            if nargin < 4, parameters = struct(); end
            if nargin < 5, options = struct(); end
            if ~ismember(style, model.STYLES), error('boosting:style', 'xgboost・lightgbm・catboost のどれかを指定してください。'); end
            validate_numeric_data(x, '説明変数', mfilename); validate_numeric_data(y, '目的変数', mfilename);
            x = double(x); y = double(y(:)); rows = size(x, 1); predictors = size(x, 2);
            options = GradientBoostedTrees.fullOptions(options, x);
            p = hyperparameter_values(style, parameters);
            model.Style = style; model.Parameters = p; model.Loss = options.Loss; model.Quantile = options.Quantile;
            model.Categorical = options.Categorical;
            order = (1:rows)';
            if strcmp(style, 'catboost')
                order = GradientBoostedTrees.rowOrder(options.Order, rows, p.Seed);
                if any(options.Categorical)
                    [x, model.CategoryStats] = GradientBoostedTrees.orderedTargetStats(x, y, options.Categorical, options.LevelCounts, order);
                end
            end
            model.Edges = boosting_bins('edges', x, p.MaxBins);
            if ~strcmp(style, 'catboost')
                % 質的変数は水準ごとに別の区間にする（区間の番号 = 水準の番号）。
                for column = find(options.Categorical), model.Edges{column} = (1:options.LevelCounts(column) - 1) + 0.5; end
            end
            bins = boosting_bins('index', x, model.Edges); counts = cellfun(@numel, model.Edges) + 1;
            % 行・列の抽出は、この学習専用の乱数で行う（他の処理の乱数を変えないため）。
            stream = RandStream('twister', 'Seed', p.Seed);
            model.Intercept = model.startValue(y);
            [row_fraction, column_fraction] = model.samplingFractions();
            model.Trees = cell(p.NumRounds, 1); model.TrainingRMSE = zeros(p.NumRounds, 1);
            if strcmp(style, 'catboost') && p.OrderedBoosting == 1
                model = model.fitOrdered(bins, counts, y, order, stream, row_fraction); return;
            end
            prediction = repmat(model.Intercept, rows, 1);
            for round = 1:p.NumRounds
                [gradient, hessian] = model.lossGradient(prediction, y);
                used_rows = (1:rows)'; used_columns = 1:predictors;
                if row_fraction < 1, used_rows = sort(randperm(stream, rows, max(2, round_count(row_fraction * rows))))'; end
                if column_fraction < 1, used_columns = sort(randperm(stream, predictors, max(1, round_count(column_fraction * predictors)))); end
                tree = model.growOne(bins, counts, gradient, hessian, used_rows, used_columns);
                if strcmp(model.Loss, 'quantile')
                    tree = GradientBoostedTrees.renewLeaves(tree, bins(used_rows, :), y(used_rows) - prediction(used_rows), model.Quantile);
                end
                tree.Value = p.LearningRate * tree.Value;
                model.Trees{round} = tree;
                prediction = prediction + GradientBoostedTrees.treeValues(tree, bins);
                model.TrainingRMSE(round) = sqrt(mean((y - prediction).^2));
            end
        end
        function values = predict(model, x)
            validate_numeric_data(x, '推定対象データ', mfilename);
            if size(x, 2) ~= numel(model.Edges), error('boosting:columnCount', 'モデルと同じ説明変数数を指定してください。'); end
            x = double(x);
            if ~isempty(model.CategoryStats), x = GradientBoostedTrees.applyTargetStats(x, model.CategoryStats); end
            bins = boosting_bins('index', x, model.Edges);
            values = repmat(model.Intercept, size(x, 1), 1);
            for index = 1:numel(model.Trees), values = values + GradientBoostedTrees.treeValues(model.Trees{index}, bins); end
        end
    end
    methods (Access = private)
        function [row_fraction, column_fraction] = samplingFractions(model)
            p = model.Parameters;
            switch model.Style
                case 'xgboost', row_fraction = p.Subsample; column_fraction = p.ColsampleByTree;
                case 'lightgbm', row_fraction = p.BaggingFraction; column_fraction = p.FeatureFraction;
                otherwise, row_fraction = p.Subsample; column_fraction = 1;
            end
        end
        function value = startValue(model, y)
            % 最初の予測：二乗誤差では平均、ピンボール損失では分位点。
            if strcmp(model.Loss, 'quantile'), value = quantile(y, model.Quantile); else, value = mean(y); end
        end
        function [gradient, hessian] = lossGradient(model, prediction, y)
            % 予測についての損失の1階微分（勾配）と2階微分（ヘッセ行列の対角）。
            % ピンボール損失の2階微分は0なので、LightGBM と同じく1と置き、葉の値は後で残差の分位点に置き換える。
            if strcmp(model.Loss, 'quantile')
                gradient = double(prediction >= y) - model.Quantile;
            else
                gradient = prediction - y;
            end
            hessian = ones(numel(y), 1);
        end
        function tree = growOne(model, bins, counts, gradient, hessian, rows, columns)
            p = model.Parameters;
            switch model.Style
                case 'xgboost'
                    options = struct('Mode', 'depthwise', 'MaxDepth', p.MaxDepth, 'MaxLeaves', Inf, 'Lambda', p.Lambda, ...
                        'Gamma', p.Gamma, 'MinChildWeight', p.MinChildWeight, 'Categorical', model.Categorical);
                    tree = GradientBoostedTrees.growTree(bins, counts, gradient, hessian, rows, columns, options);
                case 'lightgbm'
                    options = struct('Mode', 'leafwise', 'MaxDepth', Inf, 'MaxLeaves', p.NumLeaves, 'Lambda', p.Lambda, ...
                        'Gamma', 0, 'MinChildWeight', p.MinDataInLeaf, 'Categorical', model.Categorical);
                    tree = GradientBoostedTrees.growTree(bins, counts, gradient, hessian, rows, columns, options);
                otherwise
                    tree = GradientBoostedTrees.growSymmetricTree(bins, counts, gradient, hessian, rows, columns, p.Depth, p.L2LeafReg);
            end
        end
        function model = fitOrdered(model, bins, counts, y, order, stream, row_fraction)
            % CatBoost の順序付きブースティング。並べた順の先頭 1, 2, 4, 8, … 行だけで学習した補助モデルを同時に育てる。
            % 位置 r の行の勾配は、先頭 r−1 行以内で最も大きい補助モデルの予測から求める（その行自身を使わない）。
            % 木の形はこの勾配で選び、葉の値は補助モデルごとに、その補助モデルが使える行だけから求める。
            % 最後の補助モデル（全行）の葉の値が、保存するモデルの木になる。
            p = model.Parameters; rows = numel(y);
            position = zeros(rows, 1); position(order) = (1:rows)';
            sizes = unique([2.^(0:floor(log2(max(rows - 1, 1)))), rows]); support = numel(sizes);
            members = position <= sizes;  % 行 × 補助モデル
            predictions = zeros(rows, support);
            for k = 1:support, predictions(:, k) = model.startValue(y(members(:, k))); end
            % 位置 r（2以上）の行は、大きさ r−1 以下で最大の補助モデルを使う。先頭の行は勾配を0にする。
            helper = ones(rows, 1);
            for k = 1:support, helper(sizes(k) <= position - 1) = k; end
            first = position == 1;
            for round = 1:p.NumRounds
                ordered = predictions(sub2ind(size(predictions), (1:rows)', helper));
                [gradient, hessian] = model.lossGradient(ordered, y); gradient(first) = 0;
                used_rows = (1:rows)';
                if row_fraction < 1, used_rows = sort(randperm(stream, rows, max(2, round_count(row_fraction * rows))))'; end
                tree = GradientBoostedTrees.growSymmetricTree(bins, counts, gradient, hessian, used_rows, 1:size(bins, 2), p.Depth, p.L2LeafReg);
                leaves = GradientBoostedTrees.symmetricLeaves(tree, bins); leaf_count = numel(tree.Value);
                used = false(rows, 1); used(used_rows) = true;
                for k = 1:support
                    part = members(:, k) & used;
                    if ~any(part), continue; end
                    if strcmp(model.Loss, 'quantile')
                        values = GradientBoostedTrees.groupValues(leaves(part), y(part) - predictions(part, k), leaf_count, model.Quantile);
                    else
                        [own_gradient, own_hessian] = model.lossGradient(predictions(part, k), y(part));
                        G = accumarray(leaves(part), own_gradient, [leaf_count, 1]); H = accumarray(leaves(part), own_hessian, [leaf_count, 1]);
                        values = -G ./ (H + max(p.L2LeafReg, eps));
                    end
                    predictions(:, k) = predictions(:, k) + p.LearningRate * values(leaves);
                    if k == support, tree.Value = p.LearningRate * values; end
                end
                model.Trees{round} = tree;
                model.TrainingRMSE(round) = sqrt(mean((y - predictions(:, end)).^2));
            end
        end
    end
    methods (Static)
        function tree = growTree(bins, counts, gradient, hessian, rows, columns, options)
            % 区間番号 bins の上で、勾配 gradient・ヘッセ行列の対角 hessian から回帰木を1本作る。
            % options.Mode：'depthwise'（段ごと）または 'leafwise'（改善の大きい葉から）。
            % options.Categorical（省略可）：質的変数の列。水準の組で分ける（Sets に左へ進む水準を持つ）。
            % 葉の値は −G/(H+λ)、分岐の改善は ½[G_L²/(H_L+λ) + G_R²/(H_R+λ) − G²/(H+λ)] − γ。
            if ~isfield(options, 'Categorical') || isempty(options.Categorical), options.Categorical = false(1, size(bins, 2)); end
            feature = 0; threshold = 0; left = 0; right = 0; depth = 0; node_rows = {rows(:)}; sets = {[]};
            value = GradientBoostedTrees.leafValue(gradient(rows), hessian(rows), options.Lambda);
            [gain, best_feature, best_threshold, best_set] = GradientBoostedTrees.bestSplit(bins, counts, gradient, hessian, rows, columns, options);
            gains = gain; split_feature = best_feature; split_threshold = best_threshold; split_set = {best_set}; leaves = 1;
            open = 1;
            while ~isempty(open)
                if strcmp(options.Mode, 'leafwise')
                    if leaves >= options.MaxLeaves, break; end
                    [~, pick] = max(gains(open)); node = open(pick); open(pick) = []; %#ok<AGROW> 木の大きさは分岐が終わるまで分からない
                else
                    node = open(1); open(1) = [];
                end
                if gains(node) <= GradientBoostedTrees.MIN_GAIN || depth(node) >= options.MaxDepth, continue; end
                members = node_rows{node}; chosen = bins(members, split_feature(node));
                if isempty(split_set{node}), go_left = chosen <= split_threshold(node);
                else, go_left = GradientBoostedTrees.inSet(split_set{node}, chosen); end
                children = numel(feature) + [1, 2]; parts = {members(go_left), members(~go_left)};
                feature(node) = split_feature(node); threshold(node) = split_threshold(node); sets{node} = split_set{node}; %#ok<AGROW> 木の大きさは分岐が終わるまで分からない
                left(node) = children(1); right(node) = children(2); leaves = leaves + 1; %#ok<AGROW> 木の大きさは分岐が終わるまで分からない
                for side = 1:2
                    child = children(side); part = parts{side};
                    feature(child) = 0; threshold(child) = 0; left(child) = 0; right(child) = 0; sets{child} = [];
                    depth(child) = depth(node) + 1; node_rows{child} = part; %#ok<AGROW> 木の大きさは分岐が終わるまで分からない
                    value(child) = GradientBoostedTrees.leafValue(gradient(part), hessian(part), options.Lambda);
                    gains(child) = -Inf; split_feature(child) = 0; split_threshold(child) = 0; split_set{child} = [];
                    if depth(child) < options.MaxDepth
                        [gains(child), split_feature(child), split_threshold(child), split_set{child}] = ...
                            GradientBoostedTrees.bestSplit(bins, counts, gradient, hessian, part, columns, options);
                    end
                    open(end + 1) = child; %#ok<AGROW>
                end
            end
            tree = struct('Feature', feature(:), 'Threshold', threshold(:), 'Left', left(:), 'Right', right(:), 'Value', value(:));
            if any(~cellfun(@isempty, sets)), tree.Sets = sets(:); end
        end
        function values = predictTree(tree, bins)
            values = tree.Value(GradientBoostedTrees.leafNodes(tree, bins));
        end
        function node = leafNodes(tree, bins)
            % 各行が行き着く葉の番号（木の節の番号）。
            node = ones(size(bins, 1), 1);
            has_sets = isfield(tree, 'Sets');
            while true
                internal = find(tree.Left(node) > 0);
                if isempty(internal), break; end
                current = node(internal);
                chosen = bins(sub2ind(size(bins), internal, tree.Feature(current)));
                go_left = chosen <= tree.Threshold(current);
                if has_sets
                    for split = unique(current(~cellfun(@isempty, tree.Sets(current))))'
                        here = current == split;
                        go_left(here) = GradientBoostedTrees.inSet(tree.Sets{split}, chosen(here));
                    end
                end
                node(internal(go_left)) = tree.Left(current(go_left));
                node(internal(~go_left)) = tree.Right(current(~go_left));
            end
        end
        function values = treeValues(tree, bins)
            if isfield(tree, 'Levels')
                values = GradientBoostedTrees.predictSymmetricTree(tree, bins);
            else
                values = GradientBoostedTrees.predictTree(tree, bins);
            end
        end
        function tree = growSymmetricTree(bins, counts, gradient, hessian, rows, columns, max_depth, lambda)
            % 対称木：段ごとに1つの（説明変数, 区切り）を選び、その段の全ての葉を同じ条件で分ける。
            % 条件は、全ての葉の改善の合計が最大になるものを選ぶ。
            leaf = ones(numel(rows), 1); levels = zeros(0, 2);
            g = gradient(rows); h = hessian(rows);
            for level = 1:max_depth
                leaf_count = 2^(level - 1); best = GradientBoostedTrees.MIN_GAIN; choice = [];
                for feature = columns
                    if counts(feature) < 2, continue; end
                    b = bins(rows, feature);
                    G = accumarray([leaf, b], g, [leaf_count, counts(feature)]);
                    H = accumarray([leaf, b], h, [leaf_count, counts(feature)]);
                    GL = cumsum(G(:, 1:end - 1), 2); HL = cumsum(H(:, 1:end - 1), 2);
                    total_g = sum(G, 2); total_h = sum(H, 2); GR = total_g - GL; HR = total_h - HL;
                    score = sum(GL.^2 ./ (HL + lambda) + GR.^2 ./ (HR + lambda), 1, 'omitnan') - sum(total_g.^2 ./ (total_h + lambda), 'omitnan');
                    [top, threshold] = max(score);
                    if top > best, best = top; choice = [feature, threshold]; end
                end
                if isempty(choice), break; end
                levels(level, :) = choice;
                leaf = leaf + (bins(rows, choice(1)) > choice(2)) * 2^(level - 1);
            end
            leaf_count = 2^size(levels, 1);
            G = accumarray(leaf, g, [leaf_count, 1]); H = accumarray(leaf, h, [leaf_count, 1]);
            tree = struct('Levels', levels, 'Value', -G ./ (H + max(lambda, eps)));
        end
        function values = predictSymmetricTree(tree, bins)
            values = tree.Value(GradientBoostedTrees.symmetricLeaves(tree, bins));
        end
        function leaf = symmetricLeaves(tree, bins)
            leaf = ones(size(bins, 1), 1);
            for level = 1:size(tree.Levels, 1)
                leaf = leaf + (bins(:, tree.Levels(level, 1)) > tree.Levels(level, 2)) * 2^(level - 1);
            end
        end
        function tree = renewLeaves(tree, bins, residual, tau)
            % ピンボール損失では、葉の値を「葉に入った行の残差の分位点」に置き換える（LightGBM・scikit-learn と同じ）。
            if isfield(tree, 'Levels')
                leaves = GradientBoostedTrees.symmetricLeaves(tree, bins);
            else
                leaves = GradientBoostedTrees.leafNodes(tree, bins);
            end
            [values, sizes] = GradientBoostedTrees.groupValues(leaves, residual, numel(tree.Value), tau);
            tree.Value(sizes > 0) = values(sizes > 0);
        end
        function [values, sizes] = groupValues(groups, residual, count, tau)
            % グループごとの残差の代表値：tau が NaN なら平均、それ以外は分位点。行のないグループは0。
            sizes = accumarray(groups(:), 1, [count, 1]);
            if isnan(tau)
                values = accumarray(groups(:), residual(:), [count, 1]) ./ max(sizes, 1);
            else
                values = accumarray(groups(:), residual(:), [count, 1], @(part) quantile(part, tau));
            end
        end
        function options = fullOptions(options, x)
            % 省略した項目を既定値で埋め、値を確かめる。
            predictors = size(x, 2);
            defaults = struct('Categorical', false(1, predictors), 'LevelCounts', zeros(1, predictors), ...
                'Loss', 'squared', 'Quantile', NaN, 'Order', []);
            for name = fieldnames(defaults)'
                if ~isfield(options, name{1}) || isempty(options.(name{1})), options.(name{1}) = defaults.(name{1}); end
            end
            options.Categorical = logical(options.Categorical(:)');
            if numel(options.Categorical) ~= predictors, error('boosting:categorical', '質的変数の指定が説明変数の数と一致しません。'); end
            options.LevelCounts = double(options.LevelCounts(:)');
            for column = find(options.Categorical)
                codes = x(:, column);
                if options.LevelCounts(column) < 1, options.LevelCounts(column) = max(codes); end
                if any(codes ~= round(codes) | codes < 1 | codes > options.LevelCounts(column))
                    error('boosting:categoricalCodes', '質的変数の列 %d の値は水準の番号（1〜%d）にしてください。', column, options.LevelCounts(column));
                end
            end
            if ~ismember(options.Loss, {'squared', 'quantile'}), error('boosting:loss', '損失関数は squared または quantile を指定してください。'); end
            if strcmp(options.Loss, 'quantile') && ~(isscalar(options.Quantile) && options.Quantile > 0 && options.Quantile < 1)
                error('boosting:quantile', '分位点 τ は0より大きく1より小さい値にしてください。');
            end
            if ~strcmp(options.Loss, 'quantile'), options.Quantile = NaN; end
            if ~isempty(options.Order) && (numel(options.Order) ~= size(x, 1) || any(~isfinite(options.Order(:))))
                error('boosting:order', '並べ替えの列は、学習に使う行と同じ数の、空欄のない値にしてください。');
            end
        end
        function order = rowOrder(values, rows, seed)
            % 並べる順（order(k) は k 番目の行）。値がなければ乱数の順。同じ値どうしは乱数の順にする。
            stream = RandStream('twister', 'Seed', seed);
            shuffled = randperm(stream, rows)';
            if isempty(values), order = shuffled; return; end
            [~, sorted] = sort(double(values(shuffled)));  % sort は安定（同じ値は乱数の順のまま）
            order = shuffled(sorted);
        end
        function [x, stats] = orderedTargetStats(x, y, categorical, level_counts, order)
            % Ordered Target Statistics：並べた順で前の行だけから、水準ごとの目的変数の平均を求めて置き換える。
            % 値 = (前の行の同じ水準の目的変数の和 + a × 事前値) / (前の行の同じ水準の行数 + a)、事前値は目的変数の平均。
            % 予測では、学習データの全行の和と行数を使う。
            prior = mean(y); weight = GradientBoostedTrees.PRIOR_WEIGHT; columns = find(categorical);
            stats = struct('Columns', columns, 'Sums', {cell(1, numel(columns))}, 'Counts', {cell(1, numel(columns))}, ...
                'Prior', prior, 'Weight', weight);
            for index = 1:numel(columns)
                column = columns(index); codes = x(:, column);
                sums = zeros(level_counts(column), 1); counts = zeros(level_counts(column), 1); encoded = zeros(numel(y), 1);
                for row = order(:)'
                    level = codes(row);
                    encoded(row) = (sums(level) + weight * prior) / (counts(level) + weight);
                    sums(level) = sums(level) + y(row); counts(level) = counts(level) + 1;
                end
                x(:, column) = encoded; stats.Sums{index} = sums; stats.Counts{index} = counts;
            end
        end
        function x = applyTargetStats(x, stats)
            for index = 1:numel(stats.Columns)
                column = stats.Columns(index); codes = x(:, column); sums = stats.Sums{index}; counts = stats.Counts{index};
                encoded = repmat(stats.Prior, numel(codes), 1);
                known = codes >= 1 & codes <= numel(sums) & codes == round(codes);
                encoded(known) = (sums(codes(known)) + stats.Weight * stats.Prior) ./ (counts(codes(known)) + stats.Weight);
                x(:, column) = encoded;
            end
        end
    end
    methods (Static, Access = private)
        function value = leafValue(gradient, hessian, lambda)
            value = -sum(gradient) / (sum(hessian) + max(lambda, eps));
        end
        function inside = inSet(set, chosen)
            % 区間番号 chosen が、左へ進む水準の組 set に入るか（学習時になかった番号は右へ進む）。
            inside = false(size(chosen));
            known = chosen >= 1 & chosen <= numel(set);
            inside(known) = set(chosen(known));
        end
        function [gain, feature, threshold, set] = bestSplit(bins, counts, gradient, hessian, rows, columns, options)
            gain = -Inf; feature = 0; threshold = 0; set = [];
            g = gradient(rows); h = hessian(rows); total_g = sum(g); total_h = sum(h);
            parent = total_g^2 / (total_h + options.Lambda + eps);
            for candidate = columns
                if counts(candidate) < 2, continue; end
                b = bins(rows, candidate);
                G = accumarray(b, g, [counts(candidate), 1]); H = accumarray(b, h, [counts(candidate), 1]);
                order = (1:counts(candidate))';
                if options.Categorical(candidate)
                    % 質的変数：行のある水準を G/(H+λ) の順に並べ、その順で前後2つの組に分ける。
                    present = find(H > 0);
                    if numel(present) < 2, continue; end
                    [~, sorted] = sort(G(present) ./ (H(present) + options.Lambda + eps)); order = present(sorted);
                end
                GL = cumsum(G(order(1:end - 1))); HL = cumsum(H(order(1:end - 1))); GR = total_g - GL; HR = total_h - HL;
                gains = 0.5 * (GL.^2 ./ (HL + options.Lambda + eps) + GR.^2 ./ (HR + options.Lambda + eps) - parent) - options.Gamma;
                gains(HL < options.MinChildWeight | HR < options.MinChildWeight) = -Inf;
                [top, position] = max(gains);
                if top > gain
                    gain = top; feature = candidate; threshold = position; set = [];
                    if options.Categorical(candidate)
                        set = false(counts(candidate), 1); set(order(1:position)) = true; threshold = 0;
                    end
                end
            end
        end
    end
end

function count = round_count(value)
count = round(value);
end

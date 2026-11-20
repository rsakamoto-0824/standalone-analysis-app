classdef GradientBoostedTrees
    % 勾配ブースティング木（二乗誤差）。木の育て方で3つの方式を切り替える。
    %   xgboost  ：段ごとに全ての葉を分ける（深さ優先ではなく段ごとの成長）。L2正則化 λ と分岐の最小改善 γ を使う
    %   lightgbm ：改善の最も大きい葉から順に分ける（葉ごとの成長）。葉の数の上限で大きさを決める
    %   catboost ：同じ段では全ての枝が同じ条件で分かれる対称木（oblivious tree）
    % いずれも各説明変数を区間に分けたヒストグラムで分岐を探す。
    % 各ライブラリ（XGBoost・LightGBM・CatBoost）そのものではなく、木の育て方と正則化の考え方を MATLAB で実装したもの。
    % CatBoost の順序付きブースティングと質的変数の変換、LightGBM の GOSS・EFB は含まない。
    properties (SetAccess = private)
        Style
        Parameters
        Intercept
        Edges
        Trees = {}
        TrainingRMSE
    end
    properties (Constant)
        STYLES = {'xgboost', 'lightgbm', 'catboost'}
        MIN_GAIN = 1e-12
    end
    methods
        function model = GradientBoostedTrees(x, y, style, parameters)
            if nargin == 0, return; end
            if nargin < 4, parameters = struct(); end
            if ~ismember(style, model.STYLES), error('boosting:style', 'xgboost・lightgbm・catboost のどれかを指定してください。'); end
            validate_numeric_data(x, '説明変数', mfilename); validate_numeric_data(y, '目的変数', mfilename);
            x = double(x); y = double(y(:)); rows = size(x, 1); predictors = size(x, 2);
            p = hyperparameter_values(style, parameters);
            model.Style = style; model.Parameters = p;
            model.Edges = boosting_bins('edges', x, p.MaxBins);
            bins = boosting_bins('index', x, model.Edges); counts = cellfun(@numel, model.Edges) + 1;
            % 行・列の抽出は、この学習専用の乱数で行う（他の処理の乱数を変えないため）。
            stream = RandStream('twister', 'Seed', p.Seed);
            model.Intercept = mean(y); prediction = repmat(model.Intercept, rows, 1);
            [row_fraction, column_fraction] = model.samplingFractions();
            model.Trees = cell(p.NumRounds, 1); model.TrainingRMSE = zeros(p.NumRounds, 1);
            hessian = ones(rows, 1);
            for round = 1:p.NumRounds
                gradient = prediction - y;
                used_rows = (1:rows)'; used_columns = 1:predictors;
                if row_fraction < 1, used_rows = sort(randperm(stream, rows, max(2, round_count(row_fraction * rows))))'; end
                if column_fraction < 1, used_columns = sort(randperm(stream, predictors, max(1, round_count(column_fraction * predictors)))); end
                tree = model.growOne(bins, counts, gradient, hessian, used_rows, used_columns);
                tree.Value = p.LearningRate * tree.Value;
                model.Trees{round} = tree;
                prediction = prediction + model.predictOne(tree, bins);
                model.TrainingRMSE(round) = sqrt(mean((y - prediction).^2));
            end
        end
        function values = predict(model, x)
            validate_numeric_data(x, '推定対象データ', mfilename);
            if size(x, 2) ~= numel(model.Edges), error('boosting:columnCount', 'モデルと同じ説明変数数を指定してください。'); end
            bins = boosting_bins('index', double(x), model.Edges);
            values = repmat(model.Intercept, size(x, 1), 1);
            for index = 1:numel(model.Trees), values = values + model.predictOne(model.Trees{index}, bins); end
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
        function tree = growOne(model, bins, counts, gradient, hessian, rows, columns)
            p = model.Parameters;
            switch model.Style
                case 'xgboost'
                    options = struct('Mode', 'depthwise', 'MaxDepth', p.MaxDepth, 'MaxLeaves', Inf, 'Lambda', p.Lambda, ...
                        'Gamma', p.Gamma, 'MinChildWeight', p.MinChildWeight);
                    tree = GradientBoostedTrees.growTree(bins, counts, gradient, hessian, rows, columns, options);
                case 'lightgbm'
                    options = struct('Mode', 'leafwise', 'MaxDepth', Inf, 'MaxLeaves', p.NumLeaves, 'Lambda', p.Lambda, ...
                        'Gamma', 0, 'MinChildWeight', p.MinDataInLeaf);
                    tree = GradientBoostedTrees.growTree(bins, counts, gradient, hessian, rows, columns, options);
                otherwise
                    tree = GradientBoostedTrees.growSymmetricTree(bins, counts, gradient, hessian, rows, columns, p.Depth, p.L2LeafReg);
            end
        end
        function values = predictOne(~, tree, bins)
            if isfield(tree, 'Levels')
                values = GradientBoostedTrees.predictSymmetricTree(tree, bins);
            else
                values = GradientBoostedTrees.predictTree(tree, bins);
            end
        end
    end
    methods (Static)
        function tree = growTree(bins, counts, gradient, hessian, rows, columns, options)
            % 区間番号 bins の上で、勾配 gradient・ヘッセ行列の対角 hessian から回帰木を1本作る。
            % options.Mode：'depthwise'（段ごと）または 'leafwise'（改善の大きい葉から）。
            % 葉の値は −G/(H+λ)、分岐の改善は ½[G_L²/(H_L+λ) + G_R²/(H_R+λ) − G²/(H+λ)] − γ。
            feature = 0; threshold = 0; left = 0; right = 0; depth = 0; node_rows = {rows(:)};
            value = GradientBoostedTrees.leafValue(gradient(rows), hessian(rows), options.Lambda);
            [gain, best_feature, best_threshold] = GradientBoostedTrees.bestSplit(bins, counts, gradient, hessian, rows, columns, options);
            gains = gain; split_feature = best_feature; split_threshold = best_threshold; leaves = 1;
            open = 1;
            while ~isempty(open)
                if strcmp(options.Mode, 'leafwise')
                    if leaves >= options.MaxLeaves, break; end
                    [~, pick] = max(gains(open)); node = open(pick); open(pick) = []; %#ok<AGROW> 木の大きさは分岐が終わるまで分からない
                else
                    node = open(1); open(1) = [];
                end
                if gains(node) <= GradientBoostedTrees.MIN_GAIN || depth(node) >= options.MaxDepth, continue; end
                members = node_rows{node}; go_left = bins(members, split_feature(node)) <= split_threshold(node);
                children = numel(feature) + [1, 2]; parts = {members(go_left), members(~go_left)};
                feature(node) = split_feature(node); threshold(node) = split_threshold(node); %#ok<AGROW> 木の大きさは分岐が終わるまで分からない
                left(node) = children(1); right(node) = children(2); leaves = leaves + 1; %#ok<AGROW> 木の大きさは分岐が終わるまで分からない
                for side = 1:2
                    child = children(side); part = parts{side};
                    feature(child) = 0; threshold(child) = 0; left(child) = 0; right(child) = 0;
                    depth(child) = depth(node) + 1; node_rows{child} = part; %#ok<AGROW> 木の大きさは分岐が終わるまで分からない
                    value(child) = GradientBoostedTrees.leafValue(gradient(part), hessian(part), options.Lambda);
                    gains(child) = -Inf; split_feature(child) = 0; split_threshold(child) = 0;
                    if depth(child) < options.MaxDepth
                        [gains(child), split_feature(child), split_threshold(child)] = ...
                            GradientBoostedTrees.bestSplit(bins, counts, gradient, hessian, part, columns, options);
                    end
                    open(end + 1) = child; %#ok<AGROW>
                end
            end
            tree = struct('Feature', feature(:), 'Threshold', threshold(:), 'Left', left(:), 'Right', right(:), 'Value', value(:));
        end
        function values = predictTree(tree, bins)
            node = ones(size(bins, 1), 1);
            while true
                internal = find(tree.Left(node) > 0);
                if isempty(internal), break; end
                current = node(internal);
                chosen = bins(sub2ind(size(bins), internal, tree.Feature(current)));
                go_left = chosen <= tree.Threshold(current);
                node(internal(go_left)) = tree.Left(current(go_left));
                node(internal(~go_left)) = tree.Right(current(~go_left));
            end
            values = tree.Value(node);
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
            leaf = ones(size(bins, 1), 1);
            for level = 1:size(tree.Levels, 1)
                leaf = leaf + (bins(:, tree.Levels(level, 1)) > tree.Levels(level, 2)) * 2^(level - 1);
            end
            values = tree.Value(leaf);
        end
    end
    methods (Static, Access = private)
        function value = leafValue(gradient, hessian, lambda)
            value = -sum(gradient) / (sum(hessian) + max(lambda, eps));
        end
        function [gain, feature, threshold] = bestSplit(bins, counts, gradient, hessian, rows, columns, options)
            gain = -Inf; feature = 0; threshold = 0;
            g = gradient(rows); h = hessian(rows); total_g = sum(g); total_h = sum(h);
            parent = total_g^2 / (total_h + options.Lambda + eps);
            for candidate = columns
                if counts(candidate) < 2, continue; end
                b = bins(rows, candidate);
                G = accumarray(b, g, [counts(candidate), 1]); H = accumarray(b, h, [counts(candidate), 1]);
                GL = cumsum(G(1:end - 1)); HL = cumsum(H(1:end - 1)); GR = total_g - GL; HR = total_h - HL;
                gains = 0.5 * (GL.^2 ./ (HL + options.Lambda + eps) + GR.^2 ./ (HR + options.Lambda + eps) - parent) - options.Gamma;
                gains(HL < options.MinChildWeight | HR < options.MinChildWeight) = -Inf;
                [top, position] = max(gains);
                if top > gain, gain = top; feature = candidate; threshold = position; end
            end
        end
    end
end

function count = round_count(value)
count = round(value);
end

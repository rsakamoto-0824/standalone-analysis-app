classdef ExplainableBoostingModel
    % EBM（Explainable Boosting Machine、GA2M）。予測 = 切片 + Σ f_j(x_j) + Σ f_jk(x_j, x_k)。
    % 説明変数を1つずつ順番に、小さな木で残差を少しずつ学習する（周回ブースティング）。
    % その後、残差の説明に効く2変数の組を選び、組ごとの効果も同じように学習する。
    % 各変数・各組の効果は区間ごとの値の表として持つため、形をそのまま図にできる。
    % InterpretML の EBM そのものではなく、同じ考え方（周回ブースティング・交互作用の選択）を MATLAB で実装したもの。
    % options（省略可）は GradientBoostedTrees と同じ Categorical・LevelCounts・Loss・Quantile。
    % 質的変数は水準ごとに別の区間とし、1回の更新では水準ごとの残差の平均（分位点回帰では分位点）を少しずつ足す。
    % 分位点回帰（ピンボール損失）では、木の形を損失の勾配で選び、葉の値を残差の分位点にする。
    properties (SetAccess = private)
        Parameters
        Intercept
        Edges
        MainTerms = {}
        Ranges
        Pairs = zeros(0, 2)
        PairEdges = {}
        PairTerms = {}
        TrainingRMSE
        Loss = 'squared'
        Quantile = NaN
        Categorical = []
    end
    methods
        function model = ExplainableBoostingModel(x, y, parameters, options)
            if nargin == 0, return; end
            if nargin < 3, parameters = struct(); end
            if nargin < 4, options = struct(); end
            validate_numeric_data(x, '説明変数', mfilename); validate_numeric_data(y, '目的変数', mfilename);
            x = double(x); y = double(y(:)); rows = size(x, 1); predictors = size(x, 2);
            options = GradientBoostedTrees.fullOptions(options, x);
            p = hyperparameter_values('ebm', parameters); model.Parameters = p;
            model.Loss = options.Loss; model.Quantile = options.Quantile; model.Categorical = options.Categorical;
            model.Ranges = [min(x, [], 1); max(x, [], 1)];
            model.Edges = model.categoryEdges(boosting_bins('edges', x, p.MaxBins), options.LevelCounts);
            bins = boosting_bins('index', x, model.Edges); counts = cellfun(@numel, model.Edges) + 1;
            if strcmp(model.Loss, 'quantile'), model.Intercept = quantile(y, model.Quantile); else, model.Intercept = mean(y); end
            residual = y - model.Intercept; ones_rows = ones(rows, 1);
            terms = arrayfun(@(count) zeros(count, 1), counts, 'UniformOutput', false);
            tree_options = struct('Mode', 'leafwise', 'MaxDepth', Inf, 'MaxLeaves', p.MaxLeaves, 'Lambda', 0, ...
                'Gamma', 0, 'MinChildWeight', p.MinSamplesLeaf);
            all_rows = (1:rows)';
            for round = 1:p.OuterRounds
                for feature = 1:predictors
                    if counts(feature) < 2, continue; end
                    if model.Categorical(feature)
                        update = p.LearningRate * model.groupUpdate(bins(:, feature), residual, counts(feature), p.MinSamplesLeaf);
                    else
                        tree = GradientBoostedTrees.growTree(bins, counts, model.lossGradient(residual), ones_rows, all_rows, feature, tree_options);
                        if strcmp(model.Loss, 'quantile'), tree = GradientBoostedTrees.renewLeaves(tree, bins, residual, model.Quantile); end
                        grid = ones(counts(feature), predictors); grid(:, feature) = (1:counts(feature))';
                        update = p.LearningRate * GradientBoostedTrees.predictTree(tree, grid);
                    end
                    terms{feature} = terms{feature} + update; residual = residual - update(bins(:, feature));
                end
            end
            % 各変数の効果は、学習データでの平均が0になるようにそろえ、差を切片へ移す（形を比べやすくするため）。
            for feature = 1:predictors
                shift = mean(terms{feature}(bins(:, feature)));
                terms{feature} = terms{feature} - shift; model.Intercept = model.Intercept + shift;
            end
            model.MainTerms = terms;
            if p.Interactions > 0 && predictors >= 2
                model = model.fitPairs(x, residual, p);
            end
            model.TrainingRMSE = sqrt(mean((y - model.predict(x)).^2));
        end
        function values = predict(model, x)
            validate_numeric_data(x, '推定対象データ', mfilename);
            if size(x, 2) ~= numel(model.Edges), error('ebm:columnCount', 'モデルと同じ説明変数数を指定してください。'); end
            x = double(x); bins = boosting_bins('index', x, model.Edges);
            values = repmat(model.Intercept, size(x, 1), 1);
            for feature = 1:numel(model.MainTerms), values = values + model.MainTerms{feature}(bins(:, feature)); end
            if isempty(model.Pairs), return; end
            pair_bins = boosting_bins('index', x, model.PairEdges);
            for pair = 1:size(model.Pairs, 1)
                term = model.PairTerms{pair}; first = model.Pairs(pair, 1); second = model.Pairs(pair, 2);
                values = values + term(sub2ind(size(term), pair_bins(:, first), pair_bins(:, second)));
            end
        end
        function [positions, values] = shape(model, feature)
            % 1変数の効果を階段状の線（stairs）で描くための点：両端と区間の境目、各点から右の区間の値。
            % 質的変数は、水準の番号（1, 2, …）と水準ごとの効果を返す（棒グラフで描く）。
            if model.isCategorical(feature)
                positions = 1:numel(model.MainTerms{feature}); values = model.MainTerms{feature}(:)'; return;
            end
            edges = model.Edges{feature}; range = model.Ranges(:, feature)';
            positions = unique([range(1), edges(edges > range(1) & edges < range(2)), range(2)]);
            values = model.MainTerms{feature}(1 + sum(positions(:) > edges, 2))';
        end
        function categorical = isCategorical(model, feature)
            categorical = ~isempty(model.Categorical) && model.Categorical(feature);
        end
    end
    methods (Access = private)
        function gradient = lossGradient(model, residual)
            % 予測についての損失の勾配（residual = 実測 − 予測）。二乗誤差では −残差、ピンボール損失では 1(残差≤0) − τ。
            if strcmp(model.Loss, 'quantile'), gradient = double(residual <= 0) - model.Quantile; else, gradient = -residual; end
        end
        function update = groupUpdate(model, groups, residual, count, minimum)
            % 区間（質的変数では水準）ごとの残差の平均（分位点回帰では分位点）。行数が minimum 未満の区間は更新しない。
            [update, sizes] = GradientBoostedTrees.groupValues(groups, residual, count, model.Quantile);
            update(sizes < minimum) = 0;
        end
        function edges = categoryEdges(model, edges, level_counts)
            % 質的変数は水準ごとに別の区間にする（区間の番号 = 水準の番号）。
            for column = find(model.Categorical), edges{column} = (1:level_counts(column) - 1) + 0.5; end
        end
        function model = fitPairs(model, x, residual, p)
            rows = size(x, 1); predictors = size(x, 2);
            model.PairEdges = model.categoryEdges(boosting_bins('edges', x, p.InteractionBins), max(x, [], 1));
            bins = boosting_bins('index', x, model.PairEdges); counts = cellfun(@numel, model.PairEdges) + 1;
            % 組の選び方：2変数の区間の組み合わせごとに残差の平均を取り、残差の二乗和がどれだけ減るかで並べる。
            candidates = nchoosek(1:predictors, 2); scores = zeros(size(candidates, 1), 1);
            total = sum(residual)^2 / rows;
            for index = 1:size(candidates, 1)
                first = candidates(index, 1); second = candidates(index, 2);
                if counts(first) < 2 || counts(second) < 2, scores(index) = -Inf; continue; end
                cell_index = sub2ind([counts(first), counts(second)], bins(:, first), bins(:, second));
                sums = accumarray(cell_index, residual, [counts(first) * counts(second), 1]);
                sizes = accumarray(cell_index, 1, [counts(first) * counts(second), 1]); used = sizes > 0;
                scores(index) = sum(sums(used).^2 ./ sizes(used)) - total;
            end
            [scores, order] = sort(scores, 'descend');
            chosen = order(1:min(p.Interactions, numel(order))); chosen = chosen(isfinite(scores(1:numel(chosen))) & scores(1:numel(chosen)) > 0);
            model.Pairs = candidates(chosen, :); terms = cell(size(model.Pairs, 1), 1);
            for pair = 1:numel(terms), terms{pair} = zeros(counts(model.Pairs(pair, 1)), counts(model.Pairs(pair, 2))); end
            options = struct('Mode', 'depthwise', 'MaxDepth', 2, 'MaxLeaves', Inf, 'Lambda', 0, 'Gamma', 0, 'MinChildWeight', p.MinSamplesLeaf);
            ones_rows = ones(rows, 1); all_rows = (1:rows)';
            for round = 1:p.OuterRounds
                for pair = 1:numel(terms)
                    first = model.Pairs(pair, 1); second = model.Pairs(pair, 2);
                    cell_index = sub2ind([counts(first), counts(second)], bins(:, first), bins(:, second));
                    if model.isCategorical(first) || model.isCategorical(second)
                        % 質的変数を含む組は、2変数の区間の組み合わせごとに直接更新する（水準の並びに意味がないため）。
                        update = p.LearningRate * model.groupUpdate(cell_index, residual, counts(first) * counts(second), p.MinSamplesLeaf);
                        update = reshape(update, counts(first), counts(second));
                    else
                        tree = GradientBoostedTrees.growTree(bins, counts, model.lossGradient(residual), ones_rows, all_rows, [first, second], options);
                        if strcmp(model.Loss, 'quantile'), tree = GradientBoostedTrees.renewLeaves(tree, bins, residual, model.Quantile); end
                        [a, b] = ndgrid(1:counts(first), 1:counts(second));
                        grid = ones(numel(a), predictors); grid(:, first) = a(:); grid(:, second) = b(:);
                        update = reshape(p.LearningRate * GradientBoostedTrees.predictTree(tree, grid), counts(first), counts(second));
                    end
                    terms{pair} = terms{pair} + update;
                    residual = residual - update(cell_index);
                end
            end
            for pair = 1:numel(terms)
                term = terms{pair}; first = model.Pairs(pair, 1); second = model.Pairs(pair, 2);
                shift = mean(term(sub2ind(size(term), bins(:, first), bins(:, second))));
                terms{pair} = term - shift; model.Intercept = model.Intercept + shift;
            end
            model.PairTerms = terms;
        end
    end
end

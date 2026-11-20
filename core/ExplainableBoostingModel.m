classdef ExplainableBoostingModel
    % EBM（Explainable Boosting Machine、GA2M）。予測 = 切片 + Σ f_j(x_j) + Σ f_jk(x_j, x_k)。
    % 説明変数を1つずつ順番に、小さな木で残差を少しずつ学習する（周回ブースティング）。
    % その後、残差の説明に効く2変数の組を選び、組ごとの効果も同じように学習する。
    % 各変数・各組の効果は区間ごとの値の表として持つため、形をそのまま図にできる。
    % InterpretML の EBM そのものではなく、同じ考え方（周回ブースティング・交互作用の選択）を MATLAB で実装したもの。
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
    end
    methods
        function model = ExplainableBoostingModel(x, y, parameters)
            if nargin == 0, return; end
            if nargin < 3, parameters = struct(); end
            validate_numeric_data(x, '説明変数', mfilename); validate_numeric_data(y, '目的変数', mfilename);
            x = double(x); y = double(y(:)); rows = size(x, 1); predictors = size(x, 2);
            p = hyperparameter_values('ebm', parameters); model.Parameters = p;
            model.Ranges = [min(x, [], 1); max(x, [], 1)];
            model.Edges = boosting_bins('edges', x, p.MaxBins);
            bins = boosting_bins('index', x, model.Edges); counts = cellfun(@numel, model.Edges) + 1;
            model.Intercept = mean(y); residual = y - model.Intercept; ones_rows = ones(rows, 1);
            terms = arrayfun(@(count) zeros(count, 1), counts, 'UniformOutput', false);
            options = struct('Mode', 'leafwise', 'MaxDepth', Inf, 'MaxLeaves', p.MaxLeaves, 'Lambda', 0, ...
                'Gamma', 0, 'MinChildWeight', p.MinSamplesLeaf);
            all_rows = (1:rows)';
            for round = 1:p.OuterRounds
                for feature = 1:predictors
                    if counts(feature) < 2, continue; end
                    tree = GradientBoostedTrees.growTree(bins, counts, -residual, ones_rows, all_rows, feature, options);
                    grid = ones(counts(feature), predictors); grid(:, feature) = (1:counts(feature))';
                    update = p.LearningRate * GradientBoostedTrees.predictTree(tree, grid);
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
            edges = model.Edges{feature}; range = model.Ranges(:, feature)';
            positions = unique([range(1), edges(edges > range(1) & edges < range(2)), range(2)]);
            values = model.MainTerms{feature}(1 + sum(positions(:) > edges, 2))';
        end
    end
    methods (Access = private)
        function model = fitPairs(model, x, residual, p)
            rows = size(x, 1); predictors = size(x, 2);
            model.PairEdges = boosting_bins('edges', x, p.InteractionBins);
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
                    tree = GradientBoostedTrees.growTree(bins, counts, -residual, ones_rows, all_rows, [first, second], options);
                    [a, b] = ndgrid(1:counts(first), 1:counts(second));
                    grid = ones(numel(a), predictors); grid(:, first) = a(:); grid(:, second) = b(:);
                    update = reshape(p.LearningRate * GradientBoostedTrees.predictTree(tree, grid), counts(first), counts(second));
                    terms{pair} = terms{pair} + update;
                    residual = residual - update(sub2ind(size(update), bins(:, first), bins(:, second)));
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

function [matrix, names, powers] = doe_model_matrix(design, model)
count = size(design, 2);
powers = [zeros(1, count); eye(count)];
names = ["Intercept", "F" + string(1:count)];
if any(strcmp(model, {'interaction', 'quadratic'}))
    for first = 1:count
        for second = first + 1:count
            term = zeros(1, count); term([first, second]) = 1;
            powers(end + 1, :) = term; %#ok<AGROW>
            names(end + 1) = "F" + first + "*F" + second; %#ok<AGROW>
        end
    end
end
if strcmp(model, 'quadratic')
    powers = [powers; 2 * eye(count)];
    names = [names, "F" + string(1:count) + "^2"];
elseif ~any(strcmp(model, {'linear', 'interaction'}))
    error('doe:model', 'モデルは linear / interaction / quadratic から選択してください。');
end
matrix = ones(size(design, 1), size(powers, 1));
for term = 1:size(powers, 1)
    matrix(:, term) = prod(design.^powers(term, :), 2);
end
end

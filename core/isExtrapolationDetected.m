function [isExtrapolation, outside_rows] = isExtrapolationDetected(Xtrain, Xtest)
minTrain = min(Xtrain, [], 1);
maxTrain = max(Xtrain, [], 1);
isBelow = Xtest < minTrain;
isAbove = Xtest > maxTrain;
isExtrapolation = any(isBelow(:) | isAbove(:));
outside_rows = any(isBelow | isAbove, 2);
end

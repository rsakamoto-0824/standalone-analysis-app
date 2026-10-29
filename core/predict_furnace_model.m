function [prediction, deviation, interval] = predict_furnace_model(model, slots)
validate_numeric_data(slots, '予測するBoatSlot', mfilename);
if ~isvector(slots), error('furnace:queryShape', '予測位置はベクトルにしてください。'); end
slots = double(slots(:)); deviation = NaN(size(slots)); interval = NaN(numel(slots), 2);
switch model.Method
    case 'spline'
        prediction = ppval(model.Fit, slots); prediction = prediction(:);
    case 'rbf'
        fit = model.Fit; z = (slots - fit.Center) / fit.Scale;
        basis = [exp(-0.5 * ((z - fit.Slots') / fit.Width).^2), ones(size(z)), z];
        prediction = fit.ResponseCenter + fit.ResponseScale * (basis * fit.Coefficients);
    otherwise
        require_r2025b();
        [prediction, deviation, interval] = predict(model.Fit, slots);
end
if isfield(model, 'ResponseScale')
    prediction = model.ResponseCenter + model.ResponseScale * prediction;
    deviation = model.ResponseScale * deviation; interval = model.ResponseCenter + model.ResponseScale * interval;
end
validate_numeric_data(prediction, '予測値', mfilename);
end

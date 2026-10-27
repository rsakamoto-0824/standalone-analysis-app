function constants = model_constants()
constants.PREDICTOR_NAMES = {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH'};
constants.KERNELS = {'squaredexponential', 'matern32', 'matern52', ...
    'exponential', 'rationalquadratic', 'ardmatern52', 'ardsquaredexponential'};
constants.FIT_METHODS = {'exact', 'sd', 'sr', 'fic'};
constants.DEFAULT_KERNEL = constants.KERNELS{1};
constants.DEFAULT_FIT_METHOD = constants.FIT_METHODS{1};
constants.MIN_TRAIN_ROWS = 25;
constants.CAUTION_TRAIN_ROWS = 150;
constants.MAX_SHAP_POINTS = 1000;
constants.REQUIRED_RELEASE = '2025b';
constants.MIN_BINS = 10;
constants.ENTROPY_EPSILON = 1e-12;
constants.MODEL_TYPES = {'apc', 'swing', 'in_plane', 'generic'};
constants.INVALID_MODEL_MESSAGE = 'このモデルを制御に使用しないでください';
end

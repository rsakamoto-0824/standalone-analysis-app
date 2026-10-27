function project_root = setup_paths()
project_root = fileparts(mfilename('fullpath'));
addpath(fullfile(project_root, 'core'), fullfile(project_root, 'app'));
end

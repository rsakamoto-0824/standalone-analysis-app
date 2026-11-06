function run_kernel_comparison_ui_smoke(image_folder)
% 現行の保存前モデリング・複数条件比較の表示補助試験。
if nargin<1, image_folder=''; end
run_batch_modeling_ui_smoke(image_folder);
end

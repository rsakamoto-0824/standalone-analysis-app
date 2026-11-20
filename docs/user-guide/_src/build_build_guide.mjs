// 通常版（配布版）と Pro 版のビルド手順書（build-guide.html）を作る。対象は Windows で exe とインストーラーを作る担当者。
// 配布先のクライアント PC には MATLAB がない前提。MATLAB Runtime を同梱したインストーラーで配る。
// 実行: node docs/user-guide/_src/build_build_guide.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { table, code, note, step, check, renderPage } from './guide_parts.mjs';

const guideRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const pagePath = path.join(guideRoot, 'build-guide.html');
const UPDATED = '2026-11-20';
const BACKSLASH = String.fromCharCode(92);
const winPath = (...parts) => parts.join(BACKSLASH);
const WORK = winPath('C:', 'work', 'StandaloneAnalysisApp');
const REPOSITORY = 'https://github.com/rsakamoto-0824/standalone-analysis-app';
// prepare_edition_build.m の除外の一覧と同じ（通常版の exe に含めない Pro 版だけのファイル）。
const PRO_FILES = ['app/SwingCurveView.m', 'core/fit_swing_curve.m', 'core/fit_swing_spline.m', 'core/swing_curve_values.m',
  'core/swing_curve_extrema.m', 'core/swing_spline_extrema.m', 'core/swing_residual_diagnostics.m',
  'core/GradientBoostedTrees.m', 'core/ExplainableBoostingModel.m', 'core/boosting_bins.m', 'core/search_hyperparameters.m',
  'app/HyperparameterEditor.m', 'core/category_flow_layout.m', 'app/plot_category_flows.m', 'core/calc_anova_summary.m',
  'core/calc_pca_summary.m', 'core/calc_cluster_summary.m', 'app/WordCloudPage.m', 'core/create_wordCloud.m',
  'app/SobolPage.m', 'core/calc_sobol_indices.m', 'app/CausalPage.m', 'core/causal_discovery.m', 'app/BayesPage.m',
  'core/hierarchical_bayes.m', 'core/mixed_gpr_kernel.m'];
const EDITIONS = [
  { key: 'standard', label: '通常版（配布版）', exe: 'ProcessInsightTool', app: 'Process Insight Tool' },
  { key: 'pro', label: 'Pro版', exe: 'ProcessInsightToolPro', app: 'Process Insight Tool Pro' }];
const ui = (text) => `<span class="ui-name">${text}</span>`;
const outputTree = (edition) => `<pre class="mini-path">${winPath(WORK, 'build', 'windows', edition.key)}${BACKSLASH}
  installer${BACKSLASH}
    ${edition.exe}_Installer.exe   ← 配布するもの（MATLAB Runtime を同梱）
  application${BACKSLASH}
    ${edition.exe}.exe             exe 本体（インストーラーの中身と同じ）
    readme.txt など                MATLAB Compiler が作る付随ファイル
    samples${BACKSLASH}                       合成サンプル
    docs${BACKSLASH}user-guide${BACKSLASH}               ${edition.key === 'pro' ? '利用手順書（user-manual.html）・ビルド利用手順書ほか' : '利用手順書（user-manual.html）と、その画像だけ'}
  edition-manifest.json            版・含めたファイル・バージョンの一覧</pre>`;
const sections = [];
const add = (id, title, kicker, body) => sections.push({ id, title, kicker, body });

add('overview', '目的と対象', 'START HERE', `
<p>この手順書は、<strong>Process Insight Tool の Windows 用インストーラーを作る担当者</strong>向けです。<strong>通常版（配布版）</strong>と<strong>Pro版</strong>の2種類を作ります。アプリの使い方は<a href="user-manual.html">配布版の利用手順書</a>を参照してください。</p>
${note('配布先の PC には MATLAB がない前提です', 'ビルドでは、アプリと <strong>MATLAB Runtime（アプリを動かすための無償の部品）を1つにまとめたインストーラー</strong>を作ります。利用者はそのインストーラーを実行するだけで使え、MATLAB 本体も、インストール時のインターネット接続も要りません。MATLAB と MATLAB Compiler が必要なのは、ビルドする PC だけです。')}
${table(['版', 'インストーラー', 'アプリの題名', '内容'], [
  ['通常版（配布版）', '<code>ProcessInsightTool_Installer.exe</code>', 'Process Insight Tool', '学習・比較・保存（汎用回帰は GPR・重回帰・PLS・ランダムフォレスト・バギング木、Permutation Importance・VIP）、データの単変量の傾向のグラフ、推定と SHAP（どのモデルでも分布図・依存図）、炉内補間、実験計画（評価指標つき）。'],
  ['Pro版', '<code>ProcessInsightToolPro_Installer.exe</code>', 'Process Insight Tool Pro', '通常版の機能に加えて、Swing Curve学習の周期カーネル（swingperiodic）と周期の探索範囲、レジスト膜厚の SHAP へのカーブ近似、極値・山間／谷間の傾き、近似残差の診断、データのグラフ8種類（ヒストグラム・相関・ANOVA・Parallel Coordinates・Parallel Sets・Sankey・PCA・クラスタリング）、汎用回帰の EBM・XGBoost・LightGBM・CatBoost とハイパーパラメータの探索、GPR の加法カーネルと質的変数、Sobol感度解析、因果探索、階層ベイズ、拡張実験計画、ワードクラウド。']])}
<p>版はビルドのときに決まります。起動後の設定や引数で通常版を Pro 版へ切り替えることはできません。通常版には Pro 版だけの機能の画面と、そのためのファイルを含めません。</p>
${note('この手順書の範囲', 'ビルドは Windows 64bit の MATLAB R2025b でしか実行できないため、MATLAB の画面の画像は載せていません。操作はコマンドウィンドウへの入力で行います。2026-11-19 時点で、Windows での実際のビルドとインストールは未実施です。最初のビルドでは各章の「確認」を一つずつ確かめ、結果を <code>verification.md</code> に記録してください。', 'warning')}
`);

add('prerequisites', '作業前の確認', 'PREPARATION', `
${table(['準備するもの', 'ビルドする PC（担当者）', '配布先の PC（利用者）'], [
  ['OS', 'Windows 11（64bit）', 'Windows 11（64bit）'],
  ['MATLAB', '<strong>R2025b</strong>（制御側と同じリリース。ほかのリリースではアプリとビルドが止まります）', '<strong>不要</strong>'],
  ['追加の製品', 'Statistics and Machine Learning Toolbox、MATLAB Compiler', '不要（MATLAB Runtime はインストーラーに含まれます）'],
  ['MATLAB Runtime のインストーラー', 'ビルドに使う MATLAB と<strong>同じ更新版</strong>のもの（2章で入手）', '不要'],
  ['権限', 'MATLAB を使える一般の権限', 'インストールのとき、管理者の権限が必要な場合があります'],
  ['空き容量', 'インストーラー1つで数GBになることがあるため、十分な余裕を持つ', 'MATLAB Runtime とアプリの分（数GB）']])}
<ul><li>会社の PC では、Codex・Claude Code などのエージェントAIや GitHub Copilot を使う必要はありません。MATLAB と Windows の標準の操作だけで進められます。</li><li>測定データなど社内の情報を、外部のサービスへアップロードしないでください。ビルドと確認には、同梱の合成サンプルを使います。</li><li>MATLAB Runtime の入手と、作ったインストーラーの配布は、会社で承認された手順に従ってください。</li></ul>
`);

add('workflow', '全体の流れ', 'OVERVIEW', `
<div class="compact-flow"><span><b>1</b>ソースを置く</span><i>→</i><span><b>2</b>環境と Runtime を用意</span><i>→</i><span><b>3</b>通し確認とテスト</span><i>→</i><span><b>4</b>通常版をビルド</span><i>→</i><span><b>5</b>Pro版をビルド</span><i>→</i><span><b>6</b>MATLAB のない PC で確認</span><i>→</i><span><b>7</b>配る</span></div>
<p>3章のテストに失敗すると、ビルドは自動で止まります。通常版と Pro 版は別々のフォルダに作られるため、順番はどちらが先でもかまいません。</p>
`);

add('source', 'ソースを置く', 'STEP 1', `
${step('1-1', 'プロジェクトのフォルダを用意する', `<ol><li>GitHub の <a href="${REPOSITORY}">${REPOSITORY}</a> を開き、${ui('Code')} → ${ui('Download ZIP')} でダウンロードします。会社の PC から GitHub を開けない場合は、承認された方法でフォルダ一式を持ち込みます。</li><li>ZIP を展開し、フォルダを <code>${WORK}</code> に置きます。</li></ol><p>フォルダの場所には、<strong>日本語や空白を含まない短いパス</strong>を使うことをおすすめします（ビルドの道具が長いパスや日本語のパスで失敗することがあるため）。</p>`,
  `<code>${winPath(WORK, 'build_windows.m')}</code> と <code>app</code>・<code>core</code> フォルダがあること。`)}
<pre class="mini-path">${WORK}${BACKSLASH}
  app${BACKSLASH}                 画面のソース（起動口は launch_analysis_app.m）
  core${BACKSLASH}                学習・保存・検証などの計算
  tests${BACKSLASH}               単体テストと全機能の通し確認
  samples${BACKSLASH}             合成サンプル（インストーラーに入れます）
  docs${BACKSLASH}user-guide${BACKSLASH}     手順書（インストーラーに入れます）
  build_windows.m      ビルドの入口
  run_tests.m          全テスト</pre>
`);

add('environment', '環境と MATLAB Runtime を用意する', 'STEP 2', `
${step('2-1', 'MATLAB R2025b でフォルダを開き、製品を確認する', `<p>MATLAB R2025b を起動し、コマンドウィンドウに次を入力します。</p>${code('MATLAB コマンドウィンドウ', `cd('${WORK}')
setup_paths;
version('-release')
computer('arch')
license('test', 'Compiler')
license('test', 'Statistics_Toolbox')`)}`,
  'リリースが <code>2025b</code>、アーキテクチャが <code>win64</code>、2つの <code>license</code> がどちらも <code>1</code> であること。')}
${step('2-2', 'MATLAB Runtime のインストーラーを用意する（最初に1回）', `<p>インストーラーに MATLAB Runtime を入れるため、ビルドする PC に、使っている MATLAB と<strong>同じ更新版</strong>の MATLAB Runtime インストーラーが必要です。</p>${table(['ビルドする PC', '方法'], [
  ['インターネットに接続できる', `コマンドウィンドウで次を実行します。数分かかります。${code('MATLAB コマンドウィンドウ', 'compiler.runtime.download')}`],
  ['インターネットに接続できない', `<ol><li>上のコマンドを実行すると、接続できないというエラーと一緒に、入手先の URL が表示されます。</li><li>インターネットに接続できる PC でその URL からダウンロードし、承認された方法でビルドする PC へ持ち込みます。</li><li>MATLAB の ${ui('設定')} → ${ui('MATLAB Compiler')} で、持ち込んだ MATLAB Runtime インストーラーの場所を指定します。</li></ol>`]])}`,
  'エラーなく終わること（接続できない場合は、設定で場所を指定したこと）。')}
${note('R2025b 以外では止まります', '製品のアプリと学習処理は、制御側との互換のため R2025b 以外では起動しません（「MATLAB / MATLAB Runtime R2025b が必要です」と表示）。この確認を外さないでください。', 'warning')}
`);

add('tests', '全機能の通し確認とテスト', 'STEP 3', `
${step('3-1', '全機能の通し確認を実行する', `${code('MATLAB コマンドウィンドウ', `addpath('tests');
results = run_app_flow_check;`)}<p>アプリを実際に起動し、同梱サンプルで、学習・比較・保存、炉内補間、推定、SHAP解析、実験計画、ワードクラウド、設定、結果の出力、通常版の画面（Pro 版だけの選択肢・説明が出ないこと）、文字の大きさの変更、入力の誤りの自動確認を、画面のボタンと同じ入口から順に確かめます。R2025b では SHAP も実際に計算します。数分かかります。設定とログは一時フォルダへ保存するため、ふだんの設定は変わりません。</p>`,
  '最後に「確認 16 件中 16 件成功」と表示されること。失敗した項目は、表の Note の内容を記録します。')}
${step('3-2', '全テストを実行する', `${code('MATLAB コマンドウィンドウ', `results = run_tests;
fprintf('Passed=%d, Failed=%d, Incomplete=%d\\n', ...
    sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));`)}<p>学習・保存の正本コードが変わっていないことを照合してから、単体テストを実行します。</p>`,
  '<code>Failed=0</code>、<code>Incomplete=0</code> であること（R2025b ではすべてのテストを実行します）。')}
`);

const buildSection = (edition, number) => step(`${number}-1`, 'ビルドを実行する', `${code('MATLAB コマンドウィンドウ', `${edition.key === 'pro' ? 'pro' : 'standard'} = build_windows('${edition.key}');`)}<p>次の順に自動で進みます。ビルドには十数分以上かかることがあります。途中のメッセージはコマンドウィンドウに表示されます。</p><ol><li>R2025b・Windows 64bit・必要な製品を確認します。</li><li>3章の全テストを実行します（失敗するとここで止まります）。</li><li>一時フォルダへソースを写し、${edition.key === 'pro' ? 'Pro 版だけの機能も含めて' : '<strong>Pro 版だけの7ファイルを除いて</strong>'}、版を「${edition.key === 'pro' ? 'Pro版' : '通常版'}」に固定します。</li><li>MATLAB Compiler で <code>${edition.exe}.exe</code> を作ります（<code>application</code> フォルダ）。サンプルと利用手順書も中に入れます${edition.key === 'pro' ? '' : '（通常版は利用者向けの <code>user-manual.html</code> と、その画像・スタイルだけを入れ、Pro 版の機能を説明する手順書は入れません）'}。</li><li><strong>MATLAB Runtime を同梱したインストーラー</strong> <code>${edition.exe}_Installer.exe</code> を作ります（<code>installer</code> フォルダ）。サンプルと手順書もアプリと一緒にインストールされます。</li><li>版の確認用ファイル <code>edition-manifest.json</code> を書きます。</li></ol>`,
  `<code>${winPath(WORK, 'build', 'windows', edition.key, 'installer', `${edition.exe}_Installer.exe`)}</code> ができていること。`);

add('build-standard', '通常版（配布版）をビルドする', 'STEP 4', `
${buildSection(EDITIONS[0], 4)}
${outputTree(EDITIONS[0])}
${note('インストーラーの作成で止まった場合', 'exe はできていて、MATLAB Runtime のインストーラーが見つからないことが多い原因です。2-2 を済ませてから、もう一度 <code>build_windows</code> を実行してください。インストーラーを作らず exe だけを作るときは <code>build_windows(\'standard\', false)</code> とします（この場合、配布先には MATLAB Runtime を別に入れる必要があります）。')}
`);

add('build-pro', 'Pro版をビルドする', 'STEP 5', `
${buildSection(EDITIONS[1], 5)}
${table(['Pro版だけに含めるファイル（通常版には含めない）'], PRO_FILES.map((file) => [`<code>${file}</code>`]))}
<p>このほか、次の画面と説明は Pro 版でだけ表示されます。</p><ul><li>Swing Curve学習の周期カーネル（swingperiodic）と周期の探索範囲</li><li>実験計画作成の拡張 D最適・拡張 I最適（既存の計画に点を追加）と「② 既存の計画」の欄</li><li>学習画面の①のデータのグラフ8種類（ヒストグラム・相関・ANOVA・Parallel Coordinates・Parallel Sets・Sankey・PCA・クラスタリング）</li><li>汎用回帰の EBM・XGBoost・LightGBM・CatBoost、ハイパーパラメータの欄と探索、GPR の加法カーネル（additive）と「質的変数として扱う列」</li><li>メニューの「6 Sobol感度解析」「7 因果探索」「8 階層ベイズ」「10 ワードクラウド」（通常版のメニューにはなく、番号が詰まります）</li><li>「12 Help」の Pro 版だけの用語・操作・関数のリンクと、ビルド・利用手順書（procedure-guide.html）を開くボタン</li></ul><p>Pro 版のインストーラーには、すべての手順書を入れます。</p>
`);

add('verify', '版の確認と、MATLAB のない PC での確認', 'STEP 6', `
${step('6-1', '版の確認用ファイルを見る', `<p>各フォルダの <code>edition-manifest.json</code> をメモ帳で開きます。</p>${table(['版', '確認すること'], [
  ['通常版', '<code>"Edition": "standard"</code>、<code>"ProFiles"</code> が空（<code>[]</code>）、<code>"Installer": true</code> であること。'],
  ['Pro版', '<code>"Edition": "pro"</code>、<code>"ProFiles"</code> に上の7ファイル、<code>"Installer": true</code> であること。']])}`)}
${step('6-2', 'MATLAB の入っていない PC でインストールして確かめる', `<p>利用者と同じ条件で確かめるため、<strong>MATLAB も MATLAB Runtime も入っていない Windows PC</strong>（検証用の PC や仮想環境）を使います。インターネットに接続しない状態で行うと、利用者の環境に近くなります。</p><ol><li>インストーラーをダブルクリックし、案内に従ってインストールします（MATLAB Runtime も一緒に入ります）。</li><li>スタートメニューのショートカット（見つからない場合はインストール先の exe）から起動します。初回は時間がかかることがあります。</li><li>画面の題名とホームの見出しが、通常版は「Process Insight Tool（通常版）」、Pro版は「Process Insight Tool Pro（Pro版）」であることを確かめます。</li><li>「1 APC 学習」の ${ui('サンプルデータを開く')} でサンプルが開くこと、「10 Help」の ${ui('利用者向け手順書を開く')} で手順書が開くことを確かめます。</li><li>版の違い：「2 Swing Curve学習」の ③ で、<strong>Pro版だけ</strong>カーネルに swingperiodic があり、周期の探索範囲の欄が表示されることを確かめます。モデルを作った後の ④ の ${ui('SHAP 依存: RESIST_TH')} で、Pro版だけ膜厚のカーブ近似の設定が表示されます。「7 実験計画作成」の方式に、Pro版だけ「拡張 D最適」「拡張 I最適」があることも確かめます。「10 Help」は、通常版では swingperiodic・拡張実験計画などの用語がなく、手順書のボタンが1つだけであることを確かめます。</li><li>サンプルでモデルを学習し、MAT を保存して、保存後検証がすべて成功することを確かめます。</li><li>ウィンドウ右上の × で閉じると、アプリが終了することを確かめます。</li></ol>`,
  'MATLAB のない PC で、インストールから学習・保存まで動くこと。')}
`);

add('distribute', '利用者へ配る', 'STEP 7', `
${table(['配る相手', '渡すもの'], [
  ['一般の利用者', '<code>ProcessInsightTool_Installer.exe</code>（通常版）と、<a href="user-manual.html">利用手順書</a>（インストール後は、インストール先の <code>docs' + BACKSLASH + 'user-guide' + BACKSLASH + 'user-manual.html</code> からも開けます）'],
  ['Pro版の利用者', '<code>ProcessInsightToolPro_Installer.exe</code>（Pro版）と、同じ利用手順書（Pro 版だけの機能は<a href="procedure-guide.html#shap">ビルド・利用手順書の10章</a>）']])}
<ul><li>利用者の PC では、インストーラーを実行するだけで、アプリと MATLAB Runtime が入ります。MATLAB 本体とインターネット接続は要りません。</li><li>インストールに管理者の権限が必要な場合は、情報システムの窓口と手順を決めておきます。</li><li>アプリを更新するときは、新しいインストーラーを配ります。同じ MATLAB の更新版でビルドした場合、MATLAB Runtime は入れ直しになりません。</li></ul>
${note('インストーラーを使わない配り方（任意）', '<code>application</code> フォルダを ZIP にまとめて配る方法もあります。この場合は、配布先に MATLAB Runtime R2025b（ビルドに使った MATLAB と同じ更新版、またはそれ以降）を別にインストールする必要があります。通常はインストーラーで配ってください。')}
${note('「Windows によって PC が保護されました」と表示された場合', '署名のないインストーラーで表示されることがあります。実行してよいかは、会社の情報システムのルールに従ってください。', 'warning')}
`);

add('checklist', '完了確認', 'BEFORE HANDOVER', `
<p>チェック欄はこのページを見ている間の確認用です。正式な結果は <code>verification.md</code> に記録してください。</p>
<div class="checklist-grid"><article><h3>ビルドする PC</h3>${[
  'MATLAB R2025b・win64・必要な2製品を確認した。',
  '同じ更新版の MATLAB Runtime インストーラーを用意した。',
  'run_app_flow_check が「16 件中 16 件成功」だった。',
  'run_tests で Failed=0、Incomplete=0 だった。',
  '通常版と Pro 版のインストーラーができた。',
  'edition-manifest.json の Edition・ProFiles・Installer が版どおりだった。'].map(check).join('')}</article>
<article><h3>MATLAB のない PC</h3>${[
  'インストーラーだけで、アプリと MATLAB Runtime が入った。',
  '起動し、題名とホームの見出しが版どおりだった。',
  'サンプルデータが開き、Help から利用手順書が開いた。',
  '通常版に swingperiodic と周期の探索範囲が出ず、Pro版には出た。',
  'サンプルでモデルを学習・保存し、保存後検証がすべて成功した。',
  '進捗バー、横並びの散布図、予測・SHAPの1ファイル出力（CSV を Excel で開いて文字化けしない）を確認した。',
  'ウィンドウ右上の × で閉じるとアプリが終了した。'].map(check).join('')}</article></div><button type="button" class="reset-checks">この章のチェックをリセット</button>
`);

add('troubleshooting', '困ったとき', 'TROUBLESHOOTING', `
<div class="faq-list">${[
  ['「MATLAB / MATLAB Runtime R2025b が必要です」と表示される', 'ビルドする PC の MATLAB が R2025b ではありません。<code>version(\'-release\')</code> で確認します。インストーラーで入れたアプリでこの表示が出る場合は、R2025b 以外でビルドしたインストーラーを使っていないか確認します。'],
  ['build_windows:installer で止まる', 'exe はできていて、MATLAB Runtime のインストーラーが用意できていないことが多い原因です。2-2 の手順で用意してから、もう一度実行します。エラーの詳細も記録してください。'],
  ['build_windows:wrongPlatform で止まる', 'Windows 64bit の MATLAB で実行してください。'],
  ['build_windows:missingToolbox で止まる', 'MATLAB Compiler または Statistics and Machine Learning Toolbox が入っていないか、ライセンスが使えません。<code>ver</code> で製品を確認し、ライセンスの担当者に相談します。'],
  ['テストの失敗でビルドが止まる', 'コマンドウィンドウに表示された失敗したテストの名前と内容を記録します。テストを外してビルドを続けないでください。'],
  ['ビルドの途中でパスやファイルのエラーが出る', 'フォルダの場所を、日本語や空白を含まない短いパス（例：<code>C:\\work\\StandaloneAnalysisApp</code>）に移してやり直します。ウイルス対策ソフトがビルド中のファイルを止めていないかも確認します。空き容量も確認します。'],
  ['利用者の PC でインストールできない', '管理者の権限が必要な場合があります。情報システムの窓口に相談してください。空き容量（数GB）も確認します。'],
  ['インストールしたアプリが起動しない・すぐ閉じる', 'インストールが最後まで終わったか（MATLAB Runtime を含む）を確認し、PC を再起動してから試します。それでも起動しない場合は、表示されたエラーの文を記録します。'],
  ['「サンプルファイルが見つかりません」と表示される', 'インストール先のフォルダに <code>samples</code> フォルダがあるか確認します。ない場合は、ビルドに使ったソースの <code>samples</code> フォルダを確認してビルドし直します。'],
  ['Help から手順書が開かない', 'インストール先の <code>docs\\user-guide\\user-manual.html</code> を直接ダブルクリックしても開けます。'],
  ['Pro版の機能が通常版に出る／Pro版に出ない', '<code>edition-manifest.json</code> の Edition を確認します。版はビルドのときに決まるため、違っていれば正しい版でビルドし直します。']
].map(([q, a]) => `<details><summary>${q}</summary><div><p>${a}</p></div></details>`).join('')}</div>
<p>解決しない場合は、<strong>実行したコマンド、表示されたエラーの文、MATLAB のリリースと更新版</strong>を記録して開発の担当者へ伝えてください。</p>
`);

add('references', '参考資料', 'REFERENCES', `
<ul class="source-list">
<li><a href="user-manual.html">利用手順書（配布版・Windows）</a><small>利用者へ渡す手順書。</small></li>
<li><a href="procedure-guide.html">ビルド・利用手順書（詳細）</a><small>Pro版だけの機能の使い方と、計算の詳しい説明。</small></li>
<li><a href="../windows-build.md">Windows での確認・ビルド手順（Markdown）</a></li>
<li><a href="https://www.mathworks.com/help/compiler/compiler.package.installer.html">compiler.package.installer</a><small>インストーラーの作成。RuntimeDelivery の "installer" で MATLAB Runtime を同梱し、インストール時にインターネットへ接続しない。AdditionalFiles はアプリと一緒にインストールされる（MathWorks 公式、2026-11-19 参照）。</small></li>
<li><a href="https://www.mathworks.com/help/compiler/compiler.runtime.download.html">compiler.runtime.download</a><small>同じ更新版の MATLAB Runtime インストーラーの入手。</small></li>
<li><a href="https://www.mathworks.com/help/compiler/compiler.build.standalonewindowsapplication.html">compiler.build.standaloneWindowsApplication</a><small>Windows 用 exe の作成。</small></li>
<li><a href="https://www.mathworks.com/help/compiler/standalone-application-target.html">スタンドアロンアプリの配布</a><small>配るファイルと配布先の条件。</small></li></ul>
<p class="privacy-note">この資料の更新日：${UPDATED}（JST）。画像・フォント・ライブラリを外部から読み込まない構成です。</p>
`);

const html = renderPage({
  sections,
  groups: { 0: 'はじめに', 3: 'ビルドの手順', 8: '確認と対処' },
  sidebarTitle: 'ビルド手順書', sidebarSubtitle: '通常版（配布版）・Pro版 · Windows', updated: UPDATED,
  heroEyebrow: 'BUILD GUIDE', heroTitle: 'Process Insight Tool', heroSubtitle: 'ビルド手順書（通常版・Pro版）',
  heroLead: 'Windows の MATLAB R2025b で、MATLAB Runtime を同梱したインストーラーを作り、MATLAB のない PC へ配るまで。',
  badges: ['対象：インストーラーを作る担当者', '配布先：MATLAB なしの Windows PC', `更新：${UPDATED}`],
  status: '<strong>現在の状態：</strong>ソースとビルドの手順は用意済みです。Windows での実際のビルドと、MATLAB のない PC でのインストールの確認は未実施です。',
  footer: ['Process Insight Tool · ビルド手順書', `${UPDATED} · 利用方法は user-manual.html を参照`],
  title: 'Process Insight Tool｜ビルド手順書（通常版・Pro版）',
  description: 'Process Insight Tool の通常版（配布版）と Pro 版を、Windows の MATLAB R2025b で MATLAB Runtime 同梱のインストーラーにして、MATLAB のない PC へ配るまでの手順書。'
});
fs.writeFileSync(pagePath, html);
console.log(JSON.stringify({ page: pagePath, sections: sections.length, bytes: Buffer.byteLength(html) }));

// 通常版（配布版）と Pro 版のビルド手順書（build-guide.html）を作る。対象は Windows で exe を作る担当者。
// 実行: node docs/user-guide/_src/build_build_guide.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { table, code, note, step, check, renderPage } from './guide_parts.mjs';

const guideRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const pagePath = path.join(guideRoot, 'build-guide.html');
const UPDATED = '2026-11-18';
const BACKSLASH = String.fromCharCode(92);
const winPath = (...parts) => parts.join(BACKSLASH);
const WORK = winPath('C:', 'work', 'StandaloneAnalysisApp');
const REPOSITORY = 'https://github.com/rsakamoto-0824/standalone-analysis-app';
const PRO_FILES = ['app/SwingCurveView.m', 'core/fit_swing_curve.m', 'core/fit_swing_spline.m', 'core/swing_curve_values.m',
  'core/swing_curve_extrema.m', 'core/swing_spline_extrema.m', 'core/swing_residual_diagnostics.m'];
const ui = (text) => `<span class="ui-name">${text}</span>`;
const sections = [];
const add = (id, title, kicker, body) => sections.push({ id, title, kicker, body });

add('overview', '目的と対象', 'START HERE', `
<p>この手順書は、<strong>Process Insight Tool の Windows 用の実行ファイル（exe）を作る担当者</strong>向けです。<strong>通常版（配布版）</strong>と<strong>Pro版</strong>の2種類を作り、MATLAB 本体のない利用者の PC へ配る準備までを説明します。アプリの使い方は<a href="user-manual.html">配布版の利用手順書</a>を参照してください。</p>
${table(['版', '実行ファイル', '画面の題名', '内容'], [
  ['通常版（配布版）', '<code>ProcessInsightTool.exe</code>', 'Process Insight Tool', '学習・比較・保存、推定、SHAP解析（分布図・依存図）、炉内補間、実験計画、ワードクラウド。'],
  ['Pro版', '<code>ProcessInsightToolPro.exe</code>', 'Process Insight Tool Pro', '通常版の機能に加えて、レジスト膜厚の SHAP へのカーブ近似（三角関数・スプライン）、極値・山間／谷間の傾き、近似残差の診断。']])}
<p>版はビルドのときに決まります。起動後の設定や引数で通常版を Pro 版へ切り替えることはできません。通常版の exe には、Pro 版だけの機能のファイルを含めません。</p>
${note('この手順書の範囲', 'ビルドは Windows 64bit の MATLAB R2025b でしか実行できないため、この手順書には MATLAB の画面の画像を載せていません。操作はコマンドウィンドウへの入力で行います。2026-11-18 時点で、Windows での実際のビルドは未実施です。最初のビルドでは、各章の「確認」を一つずつ確かめ、結果を <code>verification.md</code> に記録してください。', 'warning')}
`);

add('prerequisites', '作業前の確認', 'PREPARATION', `
${table(['準備するもの', 'ビルドする PC', '利用者の PC'], [
  ['OS', 'Windows 11（64bit）', 'Windows 11（64bit）'],
  ['MATLAB', '<strong>R2025b</strong>（制御側と同じリリース。ほかのリリースではアプリとビルドが止まります）', '不要'],
  ['追加の製品', 'Statistics and Machine Learning Toolbox、MATLAB Compiler', '<strong>MATLAB Runtime R2025b</strong>（ビルドに使った MATLAB と同じ更新版、またはそれ以降の更新版）'],
  ['ファイル', 'このプロジェクトのフォルダ一式', 'ビルドでできたフォルダ一式（exe だけを抜き出さない）'],
  ['空き容量', 'ビルド1回あたり数百MB程度を目安に余裕を持つ', 'Runtime と exe の分']])}
<ul><li>会社の PC では、Codex・Claude Code などのエージェントAIや GitHub Copilot を使う必要はありません。MATLAB と Windows の標準の操作だけで進められます。</li><li>測定データなど社内の情報を、外部のサービスへアップロードしないでください。ビルドと確認には、同梱の合成サンプルを使います。</li><li>MATLAB Runtime の入手と持ち込みは、会社で承認された手順に従ってください。</li></ul>
`);

add('workflow', '全体の流れ', 'OVERVIEW', `
<div class="compact-flow"><span><b>1</b>ソースを置く</span><i>→</i><span><b>2</b>環境を確認</span><i>→</i><span><b>3</b>通し確認とテスト</span><i>→</i><span><b>4</b>通常版をビルド</span><i>→</i><span><b>5</b>Pro版をビルド</span><i>→</i><span><b>6</b>版と起動を確認</span><i>→</i><span><b>7</b>配る</span></div>
<p>3章のテストに失敗すると、ビルドは自動で止まります。通常版と Pro 版は別々のフォルダに作られるため、順番はどちらが先でもかまいません。</p>
`);

add('source', 'ソースを置く', 'STEP 1', `
${step('1-1', 'プロジェクトのフォルダを用意する', `<ol><li>GitHub の <a href="${REPOSITORY}">${REPOSITORY}</a> を開き、${ui('Code')} → ${ui('Download ZIP')} でダウンロードします。会社の PC から GitHub を開けない場合は、承認された方法でフォルダ一式を持ち込みます。</li><li>ZIP を展開し、フォルダを <code>${WORK}</code> に置きます。</li></ol><p>フォルダの場所には、<strong>日本語や空白を含まない短いパス</strong>を使うことをおすすめします（ビルドの道具が長いパスや日本語のパスで失敗することがあるため）。</p>`,
  `<code>${winPath(WORK, 'build_windows.m')}</code> と <code>${winPath(WORK, 'app')}</code>・<code>${winPath(WORK, 'core')}</code> フォルダがあること。`)}
<pre class="mini-path">${WORK}${BACKSLASH}
  app${BACKSLASH}                 画面のソース（起動口は launch_analysis_app.m）
  core${BACKSLASH}                学習・保存・検証などの計算
  tests${BACKSLASH}               単体テストと全機能の通し確認
  samples${BACKSLASH}             合成サンプル（exe と一緒に配ります）
  docs${BACKSLASH}user-guide${BACKSLASH}     手順書（exe と一緒に配ります）
  build_windows.m      ビルドの入口
  run_tests.m          全テスト</pre>
`);

add('environment', '環境を確認する', 'STEP 2', `
${step('2-1', 'MATLAB R2025b でフォルダを開き、製品を確認する', `<p>MATLAB R2025b を起動し、コマンドウィンドウに次を入力します。</p>${code('MATLAB コマンドウィンドウ', `cd('${WORK}')
setup_paths;
version('-release')
computer('arch')
license('test', 'Compiler')
license('test', 'Statistics_Toolbox')`)}`,
  'リリースが <code>2025b</code>、アーキテクチャが <code>win64</code>、2つの <code>license</code> がどちらも <code>1</code> であること。')}
${note('R2025b 以外では止まります', '製品のアプリと学習処理は、制御側との互換のため R2025b 以外では起動しません（「MATLAB / MATLAB Runtime R2025b が必要です」と表示）。この確認を外さないでください。', 'warning')}
`);

add('tests', '全機能の通し確認とテスト', 'STEP 3', `
${step('3-1', '全機能の通し確認を実行する', `${code('MATLAB コマンドウィンドウ', `addpath('tests');
results = run_app_flow_check;`)}<p>アプリを実際に起動し、同梱サンプルで、学習・比較・保存、炉内補間、推定、SHAP解析、実験計画、ワードクラウド、設定、結果の出力、入力の誤りの検出を、画面のボタンと同じ入口から順に確かめます。R2025b では SHAP も実際に計算します。数分かかります。設定とログは一時フォルダへ保存するため、ふだんの設定は変わりません。</p>`,
  '最後に「確認 15 件中 15 件成功」と表示されること。失敗した項目は、表の Note の内容を記録します。')}
${step('3-2', '全テストを実行する', `${code('MATLAB コマンドウィンドウ', `results = run_tests;
fprintf('Passed=%d, Failed=%d, Incomplete=%d\\n', ...
    sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));`)}<p>学習・保存の正本コードが変わっていないことを照合してから、単体テストを実行します。</p>`,
  '<code>Failed=0</code>、<code>Incomplete=0</code> であること（R2025b ではすべてのテストを実行します）。')}
`);

add('build-standard', '通常版（配布版）をビルドする', 'STEP 4', `
${step('4-1', 'ビルドを実行する', `${code('MATLAB コマンドウィンドウ', `standard = build_windows('standard');`)}<p>次の順に自動で進みます。</p><ol><li>R2025b・Windows 64bit・必要な製品を確認します。</li><li>3章の全テストを実行します（失敗するとここで止まります）。</li><li>一時フォルダへソースを写し、<strong>Pro版だけの7ファイルを除いて</strong>、版を「通常版」に固定します。</li><li>MATLAB Compiler で <code>ProcessInsightTool.exe</code> を作ります。</li><li>exe と同じフォルダへ、サンプル（<code>samples</code>）と手順書（<code>docs${BACKSLASH}user-guide</code>）を置き、版の確認用ファイル <code>edition-manifest.json</code> を書きます。</li></ol><p>ビルドには数分から十数分かかります。途中のメッセージはコマンドウィンドウに表示されます。</p>`,
  `<code>${winPath(WORK, 'build', 'windows', 'standard', 'ProcessInsightTool.exe')}</code> ができていること。`)}
<pre class="mini-path">${winPath(WORK, 'build', 'windows', 'standard')}${BACKSLASH}
  ProcessInsightTool.exe
  readme.txt など       MATLAB Compiler が作る付随ファイル
  edition-manifest.json 版と含めたファイルの一覧
  samples${BACKSLASH}             合成サンプル（ProcessInsight_Samples.xlsx ほか）
  docs${BACKSLASH}user-guide${BACKSLASH}     利用手順書（user-manual.html）ほか</pre>
`);

add('build-pro', 'Pro版をビルドする', 'STEP 5', `
${step('5-1', 'ビルドを実行する', `${code('MATLAB コマンドウィンドウ', `pro = build_windows('pro');`)}<p>通常版と同じ手順で、Pro版だけの機能も含めて <code>ProcessInsightToolPro.exe</code> を作ります。全テストはもう一度実行されます。</p>`,
  `<code>${winPath(WORK, 'build', 'windows', 'pro', 'ProcessInsightToolPro.exe')}</code> ができていること。`)}
${table(['Pro版だけに含めるファイル（通常版には含めない）'], PRO_FILES.map((file) => [`<code>${file}</code>`]))}
`);

add('verify', '版と起動を確認する', 'STEP 6', `
${step('6-1', '版の確認用ファイルを見る', `<p>各フォルダの <code>edition-manifest.json</code> をメモ帳で開きます。</p>${table(['版', '確認すること'], [
  ['通常版', '<code>"Edition": "standard"</code> で、<code>"ProFiles"</code> が空（<code>[]</code>）であること。'],
  ['Pro版', '<code>"Edition": "pro"</code> で、<code>"ProFiles"</code> に上の7ファイルがあること。']])}`)}
${step('6-2', 'ビルドした PC で起動する', `<ol><li>エクスプローラーで出力フォルダを開き、exe をダブルクリックします。初回は起動に時間がかかることがあります。</li><li>画面の題名が、通常版は「Process Insight Tool」、Pro版は「Process Insight Tool Pro」であることを確かめます。ホーム画面の見出しにも「通常版」「Pro版」と表示されます。</li><li>「1 APC 学習」の ${ui('サンプルデータを開く')} でサンプルが開くこと、「10 Help」の ${ui('利用者向け手順書を開く')} で手順書が開くことを確かめます。</li><li>版の違い：「2 Swing Curve学習」でモデルを作り、④ の ${ui('SHAP 依存: RESIST_TH')} を開きます。<strong>Pro版だけ</strong>、膜厚のカーブ近似の設定（近似方式・周期など）が表示されます。</li><li>ウィンドウ右上の × で閉じると、アプリが終了することを確かめます。</li></ol>`,
  '両方の版が起動し、題名と機能の違いが上のとおりであること。')}
`);

add('distribute', '利用者へ配る', 'STEP 7', `
${step('7-1', '配るものをまとめる', `<ol><li>配る版のフォルダ（<code>build${BACKSLASH}windows${BACKSLASH}standard</code> または <code>build${BACKSLASH}windows${BACKSLASH}pro</code>）を、<strong>中身ごと</strong>まとめます。exe だけを抜き出さないでください。</li><li>エクスプローラーでフォルダを右クリックし、${ui('ZIP ファイルに圧縮する')} で1つのファイルにします。</li><li>MATLAB Runtime R2025b（Windows 64bit）のインストーラーを、<a href="https://www.mathworks.com/products/compiler/matlab-runtime.html">MathWorks の配布ページ</a>から入手します。ビルドに使った MATLAB と同じ更新版、またはそれ以降の更新版を選びます。</li></ol>`)}
${table(['配る相手', '渡すもの'], [
  ['一般の利用者', '通常版のフォルダ（ZIP）、MATLAB Runtime R2025b、<a href="user-manual.html">利用手順書</a>（フォルダの <code>docs${BACKSLASH}user-guide${BACKSLASH}user-manual.html</code>）'],
  ['Pro版の利用者', 'Pro版のフォルダ（ZIP）、MATLAB Runtime R2025b、同じ利用手順書（Pro版だけの機能は<a href="procedure-guide.html#shap">ビルド・利用手順書の10章</a>）']])}
${step('7-2', '利用者の PC での準備（担当者または利用者）', `<ol><li>MATLAB Runtime R2025b をインストールします（管理者の権限が必要な場合があります）。</li><li>ZIP を、日本語や空白を含まない場所（例：<code>${winPath('C:', 'Apps', 'ProcessInsightTool')}</code>）に展開します。</li><li>フォルダの中の exe をダブルクリックして起動します。デスクトップにショートカットを作る場合は、ショートカットの「作業フォルダー」を exe のフォルダにします（サンプルと手順書を exe のフォルダから探すため）。</li></ol>`,
  'MATLAB 本体のない PC で起動し、ホーム画面が表示されること。')}
${note('「Windows によって PC が保護されました」と表示された場合', 'インターネットから入手した、署名のない exe で表示されることがあります。実行してよいかは、会社の情報システムのルールに従ってください。', 'warning')}
`);

add('checklist', '完了確認', 'BEFORE HANDOVER', `
<p>チェック欄はこのページを見ている間の確認用です。正式な結果は <code>verification.md</code> に記録してください。</p>
<div class="checklist-grid"><article><h3>ビルドする PC</h3>${[
  'MATLAB R2025b・win64・必要な2製品を確認した。',
  'run_app_flow_check が「15 件中 15 件成功」だった。',
  'run_tests で Failed=0、Incomplete=0 だった。',
  '通常版と Pro 版の exe ができた。',
  'edition-manifest.json の Edition と ProFiles が版どおりだった。',
  '両方の版がビルドした PC で起動し、題名と機能の違いを確認した。'].map(check).join('')}</article>
<article><h3>利用者の PC（MATLAB 本体なし）</h3>${[
  'MATLAB Runtime R2025b を入れた。',
  'フォルダを中身ごと展開し、exe が起動した。',
  'サンプルデータが開き、Help から利用手順書が開いた。',
  'サンプルでモデルを学習・保存し、保存後検証がすべて成功した。',
  '進捗バー、横並びの散布図、予測・SHAPの1ファイル出力（CSV を Excel で開いて文字化けしない）を確認した。',
  'ウィンドウ右上の × で閉じるとアプリが終了した。'].map(check).join('')}</article></div><button type="button" class="reset-checks">この章のチェックをリセット</button>
`);

add('troubleshooting', '困ったとき', 'TROUBLESHOOTING', `
<div class="faq-list">${[
  ['「MATLAB / MATLAB Runtime R2025b が必要です」と表示される', 'MATLAB（またはRuntime）が R2025b ではありません。ビルドする PC は <code>version(\'-release\')</code> で、利用者の PC は入れた Runtime のリリースを確認します。'],
  ['build_windows:wrongPlatform で止まる', 'Windows 64bit の MATLAB で実行してください。Mac や Linux では Windows 用の exe は作れません。'],
  ['build_windows:missingToolbox で止まる', 'MATLAB Compiler または Statistics and Machine Learning Toolbox が入っていないか、ライセンスが使えません。<code>ver</code> で製品を確認し、ライセンスの担当者に相談します。'],
  ['テストの失敗でビルドが止まる', 'コマンドウィンドウに表示された失敗したテストの名前と内容を記録します。テストを外してビルドを続けないでください。'],
  ['ビルドの途中でパスやファイルのエラーが出る', 'フォルダの場所を、日本語や空白を含まない短いパス（例：<code>C:\\work\\StandaloneAnalysisApp</code>）に移してやり直します。ウイルス対策ソフトがビルド中のファイルを止めていないかも確認します。'],
  ['exe が起動しない・すぐ閉じる', '利用者の PC に MATLAB Runtime R2025b が入っているか、更新版がビルドに使った MATLAB と同じかそれ以降かを確認します。フォルダの中身をすべてコピーしたかも確認します。'],
  ['「サンプルファイルが見つかりません」と表示される', 'exe と同じフォルダに <code>samples</code> フォルダがあるか確認します。ショートカットから起動した場合は、ショートカットの「作業フォルダー」を exe のフォルダにします。'],
  ['Help から手順書が開かない', 'exe と同じフォルダに <code>docs\\user-guide\\user-manual.html</code> があるか確認します。直接ダブルクリックしても開けます。'],
  ['Pro版の機能が通常版に出る／Pro版に出ない', '<code>edition-manifest.json</code> の Edition を確認します。版はビルドのときに決まるため、違っていれば正しい版でビルドし直します。']
].map(([q, a]) => `<details><summary>${q}</summary><div><p>${a}</p></div></details>`).join('')}</div>
<p>解決しない場合は、<strong>実行したコマンド、表示されたエラーの文、MATLAB / Runtime のリリースと更新版</strong>を記録して開発の担当者へ伝えてください。</p>
`);

add('references', '参考資料', 'REFERENCES', `
<ul class="source-list">
<li><a href="user-manual.html">利用手順書（配布版・Windows）</a><small>利用者へ渡す手順書。</small></li>
<li><a href="procedure-guide.html">ビルド・利用手順書（詳細）</a><small>Pro版だけの機能の使い方と、計算の詳しい説明。</small></li>
<li><a href="../windows-build.md">Windows での確認・ビルド手順（Markdown）</a></li>
<li><a href="https://www.mathworks.com/help/compiler/compiler.build.standalonewindowsapplication.html">compiler.build.standaloneWindowsApplication</a><small>Windows 用 exe の作成（MathWorks 公式）。</small></li>
<li><a href="https://www.mathworks.com/help/compiler/standalone-application-target.html">スタンドアロンアプリの配布</a><small>配るファイルと配布先の条件（MathWorks 公式）。</small></li>
<li><a href="https://www.mathworks.com/products/compiler/matlab-runtime.html">MATLAB Runtime の入手</a></li></ul>
<p class="privacy-note">この資料の更新日：${UPDATED}（JST）。画像・フォント・ライブラリを外部から読み込まない構成です。</p>
`);

const html = renderPage({
  sections,
  groups: { 0: 'はじめに', 3: 'ビルドの手順', 8: '確認と対処' },
  sidebarTitle: 'ビルド手順書', sidebarSubtitle: '通常版（配布版）・Pro版 · Windows', updated: UPDATED,
  heroEyebrow: 'BUILD GUIDE', heroTitle: 'Process Insight Tool', heroSubtitle: 'ビルド手順書（通常版・Pro版）',
  heroLead: 'Windows の MATLAB R2025b で、通常版（配布版）と Pro 版の exe を作り、利用者へ配るまで。',
  badges: ['対象：exe を作る担当者', '環境：Windows 64bit / R2025b', `更新：${UPDATED}`],
  status: '<strong>現在の状態：</strong>ソースとビルドの手順は用意済みです。Windows での実際のビルドと、Runtime だけの PC での確認は未実施です。',
  footer: ['Process Insight Tool · ビルド手順書', `${UPDATED} · 利用方法は user-manual.html を参照`],
  title: 'Process Insight Tool｜ビルド手順書（通常版・Pro版）',
  description: 'Process Insight Tool の通常版（配布版）と Pro 版を、Windows の MATLAB R2025b でビルドして配るまでの手順書。'
});
fs.writeFileSync(pagePath, html);
console.log(JSON.stringify({ page: pagePath, sections: sections.length, bytes: Buffer.byteLength(html) }));

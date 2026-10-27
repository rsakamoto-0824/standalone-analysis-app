import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const guideRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const pagePath = path.join(guideRoot, 'procedure-guide.html');
const workFolder = ['C:', 'work', 'StandaloneAnalysisApp'].join(String.fromCharCode(92));
const distributionFolder = ['C:', 'Apps', 'StandaloneAnalysisApp'].join(String.fromCharCode(92));
const escape = (text) => String(text).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const table = (heads, rows) => `<table class="guide-table"><thead><tr>${heads.map(x=>`<th scope="col">${x}</th>`).join('')}</tr></thead><tbody>${rows.map(row=>`<tr>${row.map(x=>`<td>${x}</td>`).join('')}</tr>`).join('')}</tbody></table>`;
const code = (label, text) => `<div class="code-block"><div class="code-header"><span>${escape(label)}</span><button type="button" class="copy-button" aria-label="${escape(label)}をコピー">コピー</button></div><pre><code>${escape(text)}</code></pre></div>`;
const note = (title, text, type='info') => `<div class="callout ${type}"><div class="callout-icon" aria-hidden="true">${type==='warning'?'!':'i'}</div><div><h3>${title}</h3><p>${text}</p></div></div>`;
const step = (number, title, body, expected='') => `<article class="step-card"><h3><span class="step-label">${number}</span>${title}</h3>${body}${expected?`<p class="expected"><strong>確認：</strong>${expected}</p>`:''}</article>`;
let figureCount = 0;
const shot = (name, caption, detail='表示専用コピーに合成データを設定した参考画面です。学習・モデル保存・推定・SHAP・DOE の実行結果ではありません。') => {
  figureCount += 1;
  return `<figure class="screenshot"><button type="button" class="image-open" aria-label="${escape(caption)}を拡大"><img src="images/${name}.png" alt="${escape(caption)}" loading="lazy" width="1320" height="860"></button><figcaption><span class="shot-tag">参考撮影 · R2022b / macOS</span><span class="shot-zoom">クリックで拡大 / Escで閉じる</span><strong>図${figureCount}　${caption}</strong><span class="shot-note">${detail}</span></figcaption></figure>`;
};
const officialShot = (name, caption) => {
  figureCount += 1;
  return `<figure class="screenshot vendor-shot"><button type="button" class="image-open" aria-label="${escape(caption)}を拡大"><img src="images/${name}.png" alt="${escape(caption)}" loading="lazy"></button><figcaption><span class="shot-tag">MathWorks公式資料の掲載例</span><span class="shot-zoom">クリックで拡大</span><strong>図${figureCount}　${caption}</strong><span class="shot-note">出典：<a href="https://www.mathworks.com/help/matlab/creating_guis/app-designer-startup-function.html">Specify Startup Tasks and App Input Arguments in App Designer</a>（掲載ページ R2026b、2026-10-28参照）。当プロジェクトの実行画面ではありません。R2025b ではメニュー名・配置が異なる場合があります。画像 © The MathWorks, Inc.</span></figcaption></figure>`;
};
const check = (text) => `<label><input type="checkbox"> <span>${text}</span></label>`;
const sections = [];
const add = (id,title,kicker,body) => sections.push({id,title,kicker,body});

add('overview','目的と対象','START HERE',`
<p>この手順書は、<strong>MATLAB R2025b 用の解析アプリを Windows でビルドし、MATLAB 本体のない端末へ配布して利用する</strong>までの操作を説明します。左の目次から必要な章へ移動でき、画像はクリックして拡大できます。コードは「コピー」ボタンでコピーできます。</p>
<div class="card-grid three-columns"><article class="feature-card"><span class="card-label">作成担当者</span><h3>初回のビルド</h3><p>2〜6章で環境を確認し、App Designer の入口、テスト、exe、Runtime を用意します。</p></article><article class="feature-card"><span class="card-label">利用者</span><h3>データを解析</h3><p>ビルド済みアプリを受け取ったら、6章の起動確認と7〜12章の操作を参照します。</p></article><article class="feature-card"><span class="card-label">保守担当者</span><h3>結果と問題を確認</h3><p>13章の完了確認、14章の対処表、15章のソースと公式資料を参照します。</p></article></div>
${table(['項目','現在の状態'],[
['画面・計算・テストのソース','作成済み。<code>app/</code>、<code>core/</code>、<code>tests/</code> にあります。'],
['App Designer の入口','<code>app/AnalysisApp.mlapp</code> は未作成。4章の手順で R2025b 上に作成します。'],
['R2025b の実行テスト・Windows exe','未実施・未生成。手順書の作成や GitHub への格納で、完了扱いにはしません。'],
['この手順書の画像','アプリは R2022b / macOS の表示専用コピーで撮影。App Designer の説明には MathWorks 公式資料の掲載例も使用。各画像で出典を明記しています。数値はすべて説明用です。']])}
${note('画像の読み方','R2025b の本番画面やビルド成功画面を撮影したものではありません。ボタン・入力欄・確認箇所を知るために使い、実際の成否は Windows R2025b / Runtime R2025b で確認してください。','warning')}
`);

add('prerequisites','作業前の確認','PREPARATION',`
${table(['準備するもの','作成用 Windows PC','配布先 Windows PC'],[
['OS','Windows 11・64bit を想定。<code>win64</code> を確認。','Windows 11・64bit を想定。'],
['MATLAB','R2025b が必要。R2022b ではアプリ・学習処理を停止します。','MATLAB 本体は不要。'],
['追加製品','Statistics and Machine Learning Toolbox、MATLAB Compiler。','MATLAB Runtime R2025b。ビルドに対応する更新版。'],
['アプリのファイル','このプロジェクトのフォルダ一式。','ビルド出力フォルダ一式。exe だけを抜き出さない。'],
['入力','まずは機密情報を含まない確認用 CSV / Excel。','利用する CSV / Excel、必要に応じて学習済み MAT。'],
['その他','書込み可能な作業・保存フォルダ。','書込み可能な保存先とログ先。Excel 本体・API キーは不要。']])}
<p>会社側の操作は MATLAB と Windows の標準操作だけで進められます。Codex / Claude Code や GitHub Copilot の利用は前提にしません。Runtime の取得・持込みは会社の承認済み手順に従ってください。</p>
${step('準備1','フォルダを配置する',`<p>プロジェクトを、例として <code>${workFolder}</code> に配置します。MATLAB でこのフォルダを現在のフォルダにします。別の場所へ配置した場合は、次のパスだけ置き換えます。</p>${code('MATLAB コマンドウィンドウ',`cd('${workFolder}')
setup_paths;
version('-release')
computer('arch')
ver`)}`,'リリースが <code>2025b</code>、アーキテクチャが <code>win64</code>。製品一覧に必要な2製品があること。')}
<pre class="mini-path">StandaloneAnalysisApp/
  app/                  画面ソース。ここに AnalysisApp.mlapp を保存
  core/                 学習・推定・統計・保存後検証
  tests/                単体テスト
  build_windows.m       Windows ビルドの入口
  run_tests.m           R2025b の全テスト
  docs/user-guide/      この手順書と画像・スタイル</pre>
${note('手順書を別の PC へ移すとき','<code>procedure-guide.html</code> だけでなく、<code>docs/user-guide/</code> のフォルダ全体を移してください。画像・CSS・JavaScript は相対パスで参照しています。HTML は PC の Edge / Chrome などで開けます。')}
`);

add('workflow','全体の流れ','TWO WORKFLOWS',`
<h3>作成担当者：最初に1回行う作業</h3><div class="compact-flow"><span><b>1</b>R2025b と製品を確認</span><i>→</i><span><b>2</b>.mlapp を作成</span><i>→</i><span><b>3</b>全テスト</span><i>→</i><span><b>4</b>Windows ビルド</span><i>→</i><span><b>5</b>Runtime 端末で確認</span></div>
<h3>利用者：学習モデルを作成するたびに行う作業</h3><div class="compact-flow"><span><b>1</b>CSV / Excel を読む</span><i>→</i><span><b>2</b>列対応と順序を確認</span><i>→</i><span><b>3</b>実行・MAT 保存</span><i>→</i><span><b>4</b>保存後検証を確認</span><i>→</i><span><b>5</b>結果を出力</span></div>
${note('学習モデルの利用に進む条件','保存後検証がすべて成功したことを確認します。<strong>「このモデルを制御に使用しないでください」</strong>が表示されたファイルは、制御へ渡さずに原因を確認してください。','warning')}
`);

add('app-designer','App Designer の入口を作る','BUILDER · INITIAL SETUP',`
<p class="section-intro">この章は作成担当者向けです。画面の配置・操作は作成済みの <code>AnalysisController.m</code> が担当します。App Designer では、その画面を呼び出す入口だけを用意します。</p>
${step('4-1','ソースの画面を確認する',`${code('MATLAB コマンドウィンドウ',`setup_paths;
controller = launch_analysis_app;`)}<p>R2025b では10個のタブがある画面が開く想定です。R2025b 以外ではリリースエラーとなります。エラーを避けるために製品コードの確認処理を外さないでください。</p>`,'画面が開き、左のタブと右側の結果表が表示されること。')}
${step('4-2','空のアプリを作る',`${code('MATLAB コマンドウィンドウ','appdesigner')}<ol><li>App Designer が開いたら <span class="ui-name">Blank App / 空のアプリ</span> を選びます。</li><li>UIFigure にはボタンや表を手動で置きません。</li><li><span class="ui-name">Code View / コードビュー</span> に切り替えます。</li></ol>`) }
${step('4-3','Controller プロパティを追加する',`<p>Code View のツールバーで <span class="ui-name">Property</span> を選び、private のプロパティを追加します。既定の名前を <code>Controller</code> に変更します。すでに private の properties ブロックがある場合は、その中へ <code>Controller</code> の1行を追加します。</p>${code('アプリ内の private プロパティ',`properties (Access = private)
    Controller
end`)}<p>App Designer が自動生成した UIFigure の定義やコンストラクターは削除しません。</p>`,'コードブラウザーのプロパティ一覧に <code>Controller</code> があること。')}
${step('4-4','startupFcn を追加する',`<ol><li>Component Browser の一番上のアプリ名を右クリックします。</li><li><span class="ui-name">Callbacks → Add StartupFcn callback</span> を選びます。Code View の <span class="ui-name">Callback</span> ボタンから、コンポーネントをアプリ自身、コールバックを <code>StartupFcn</code> として追加してもかまいません。</li><li>生成された <code>function startupFcn(app)</code> の本文に、下の4行を貼り付けます。</li></ol>${code('startupFcn の本文だけを貼り付ける',`project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'core'), fullfile(project_root, 'app'));
require_r2025b();
app.Controller = AnalysisController(app.UIFigure);`)}<p>関数宣言と最後の <code>end</code> は App Designer が生成します。上のコードを新しい別ファイルへ保存する必要はありません。</p>`,'起動時に <code>AnalysisController(app.UIFigure)</code> を呼ぶこと。')}
${officialShot('15-official-startup-menu','アプリノードのメニューから StartupFcn を追加する位置')}
${officialShot('16-official-startup-dialog','Add Callback Function ダイアログで StartupFcn を選ぶ例')}
${step('4-5','AnalysisApp.mlapp として保存・実行する',`<ol><li>Save / 名前を付けて保存を選びます。</li><li>保存先をプロジェクトの <code>app</code> フォルダにします。</li><li>ファイル名を <code>AnalysisApp.mlapp</code> として保存します。</li><li>App Designer の <span class="ui-name">Run</span> を押します。</li><li>一度閉じてから <code>appdesigner('app/AnalysisApp.mlapp')</code> で開き直せることも確認します。</li></ol>`,'10個の機能タブが表示されること。Design View には入口の空の UIFigure が表示され、実行時に画面が組み立てられます。')}
${shot('01-apc','入口から表示される解析画面の構成：左に機能と入力、右に結果・検証')}
${note('参考画像の作成方法','上の画面は撮影用の一時コピーで描画したものです。モデルを作成するコードや本体の R2025b 制約は変更していません。参考画像が表示できたことを、R2025b の動作確認済みとは扱いません。')}
`);

add('build','全テストと Windows ビルド','BUILDER · TEST AND BUILD',`
${step('5-1','全単体テストを実行する',`${code('MATLAB コマンドウィンドウ',`setup_paths;
results = run_tests;`)}<p>正本コードの照合を行ってから、単体テストを実行します。現時点のソースには補助テスト20件とモデル互換等のテスト9件があります。対象 PC の結果を見て、<code>Failed</code> と <code>Incomplete</code> が0件であることを確認してください。</p>`,'エラーで停止せず、すべてのテストが成功すること。手元の R2022b で成功した補助20件とは別に、R2025b で全件を確認します。')}
${code('成否の件数を確認',`fprintf('Passed=%d, Failed=%d, Incomplete=%d\n', ...
    sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));`)}
${step('5-2','現行モデルとの互換性を確認する',`<p>現行アドインで作った旧モデルと、このアプリで同じデータ・同じ条件から作った新モデルを準備します。照合する数値行列 <code>Xcheck</code> を用意して実行します。</p>${code('MATLAB コマンドウィンドウ',`comparison = compare_models('old.mat', 'new.mat', Xcheck);`)}${table(['モデル','Xcheck の列順'],[['APC / スイングカーブ','SIN_TH → SIN_RN → NSG_TH → RESIST_TH の4列。'],['面内','X座標 → Y座標 → 半径の3列。半径は <code>sqrt(X.^2 + Y.^2)</code>。'],['汎用 GPR','学習時と同じ P 列を同じ順序で渡します。']])}`,'属性の比較、予測差の最大値、予測の完全一致を確認すること。旧モデル未提供のまま「互換性確認済み」としないでください。')}
${step('5-3','Windows 実行ファイルを作る',`${code('MATLAB コマンドウィンドウ',`result = build_windows;`)}<p><code>build_windows</code> は R2025b、Windows 64bit、必要製品、<code>app/AnalysisApp.mlapp</code> の存在を確認し、全テスト成功後にビルドします。</p>`,'<code>build/windows/</code> に <code>StandaloneAnalysisApp.exe</code> と付随ファイルが生成されること。')}
<pre class="mini-path">StandaloneAnalysisApp/
  build/
    windows/
      StandaloneAnalysisApp.exe
      readme.txt
      その他、ビルドで生成された付随ファイル</pre>
${note('このコマンドが作成する範囲','現在のスクリプトは exe と付随ファイルを作ります。<strong>MATLAB Runtime や Runtime を含むインストーラーは作りません。</strong>出力の <code>readme.txt</code> も確認してください。Windows 用 exe の作成は Windows 上で実行します。','warning')}
<p>ビルド成功画面・生成済み exe のスクリーンショットはありません。この工程は Windows R2025b で未実施のため、実際の出力を担当者が確認して記録します。</p>
`);

add('runtime','配布とアプリの起動','RUNTIME · INSTALL AND START',`
${step('6-1','Runtime R2025b を用意する',`<ol><li>作成担当者がビルドした MATLAB のリリース・更新版を確認します。</li><li>公式の Runtime 配布ページから Windows 64bit / R2025b の対応版を入手します。</li><li>会社の標準手順に従い、配布先へ Runtime をインストールします。</li></ol><p>リリースは R2025b に揃えます。同じリリース内ではビルドに対応する更新版を使用し、その組合せで確認します。参照：<a href="https://www.mathworks.com/products/compiler/matlab-runtime.html">MathWorks MATLAB Runtime</a>。</p>`)}
${step('6-2','ビルド出力フォルダをコピーする',`<p><code>build/windows/</code> 内のファイルを一式で渡します。配布先の例は <code>${distributionFolder}</code> です。利用者はこの場所で exe を起動します。ソース一式を持っていない利用者は <code>run_tests</code> や <code>build_windows</code> を実行しません。</p>`)}
${step('6-3','exe を起動して最初の動作を確認する',`<ol><li><code>StandaloneAnalysisApp.exe</code> をダブルクリックします。</li><li>起動処理が完了し、10個のタブが表示されるまで待ちます。所要時間の基準値は設定していません。</li><li>機密情報のない確認用データで、読込・結果保存・ログ書込みを確認します。</li></ol>`,'MATLAB 本体が入っていない端末でも、必要な画面と機能が動くこと。')}
${note('アプリの利用中の通信','アプリから外部サービスへ測定データを送信する処理はありません。Runtime の入手・配布と、アプリがデータを解析する操作は別の工程です。')}
`);

add('input','入力ファイルと列の割当','USER · COMMON OPERATION',`
<p>学習・推定・SHAP・指標・要約統計量では、最初に入力データを読み込みます。<strong>ファイルの列順と、モデルへ渡す説明変数の順番は別です。</strong>必ず対応表を確認してください。</p>
${step('7-1','CSV / Excel を選び、シートとヘッダー行を指定する',`<ol><li>使う機能のタブを選び、<span class="ui-name">Excel / CSV を開く</span> を押します。</li><li><code>.xlsx</code> または <code>.csv</code> を選択します。</li><li>Excel ではシート一覧から対象シートを選びます。CSV ではシート選択はありません。</li><li>「ヘッダーの行番号」に列名が書かれている行番号を入力します。先頭行なら <code>1</code> です。</li></ol>`,'選択したファイル名、ヘッダー行、データ件数が左側に表示されること。')}
${table(['SIN_TH','SIN_RN','NSG_TH','RESIST_TH','CD'],[['100.1','1.91','60.2','905','50.3'],['99.8','1.90','60.4','898','50.1']])}
<p class="privacy-note">上の数値は列構成を説明するための例で、製造条件の推奨値ではありません。この2行だけでは APC の学習はできません。</p>
${step('7-2','入力プレビューを確認する',`<p>右側の <span class="ui-name">入力プレビュー</span> タブを開き、ヘッダーと先頭のデータを見ます。画面に表示するのは先頭100行までです。実際の計算には読み込んだ全行を使用します。</p>`,'シートの取り違え、ヘッダー行のずれ、文字列の混入がないこと。')}
${shot('11-input-preview','入力プレビュー：読込内容を確認する場所')}
${step('7-3','列名からモデルの変数へ割り当てる',`<ol><li>左の対応表の <span class="ui-name">入力列</span> を選びます。</li><li>APC / スイングカーブは <code>SIN_TH</code>、<code>SIN_RN</code>、<code>NSG_TH</code>、<code>RESIST_TH</code> の順です。目的変数の行 <code>y</code> には、例では <code>CD</code> を選びます。</li><li>必須変数名と列名が完全一致すれば自動割当されます。一致しない列は手動で割り当てます。</li><li><span class="ui-name">上表の列対応・順序を確認</span> を押します。</li></ol>`,'「列対応・順序を確認済みです。実行できます。」が表示されること。')}
${note('確認をやり直すタイミング','入力ファイル、列割当、入力数、推定 / SHAP の方式、モデルを変更すると確認が解除されます。実行前に再度確認します。目的変数と説明変数に同じ入力列を割り当てることはできません。','warning')}
${table(['入力の状態','アプリの扱い'],[['同名ヘッダーが重複 / ヘッダーが空','読込時に停止します。Excel が自動改名した列として扱いません。'],['選択列に空セル / NaN','学習・推定・SHAP・指標では停止し、元ファイルの行番号を表示します。'],['要約統計量の NaN','8番タブだけは NaN を除外し、欠損件数も集計します。'],['Inf / 数値以外の文字列','停止します。単位変換や文字列の自動置換で補いません。']])}
`);

add('training','4種類のモデルを学習・保存する','USER · TRAINING',`
${table(['タブ','対応表の説明変数','目的変数','特有の動作'],[
['1 APC 学習','SIN_TH → SIN_RN → NSG_TH → RESIST_TH','y','25行未満は停止。25〜149行は警告。保存・検証後に SHAP。'],
['2 スイングカーブ学習','SIN_TH → SIN_RN → NSG_TH → RESIST_TH','y','APC の25行下限・150行警告は追加しません。'],
['3 面内学習・推定','X → Y。半径は内部で追加。','y','推定用データは省略可能。半径150 mm以上も除外しません。'],
['4 汎用 GPR 学習','指定した個数の入力1 → 入力2 → …','y','対応表の順番で数値行列を作り、列名は付けません。']])}
${step('8-1','学習条件を設定する',`<p>7章に従ってデータと対応表を確認します。<code>kernel</code> と <code>fit_method</code> をドロップダウンで選択します。初回の確認では既定値 <code>squaredexponential</code> / <code>exact</code> を使用できます。BasisFunction は変更欄を設けず、正本どおりの設定を使います。</p>${table(['設定','選択肢'],[['kernel','squaredexponential / matern32 / matern52 / exponential / rationalquadratic / ardmatern52 / ardsquaredexponential'],['fit_method','exact / sd / sr / fic']])}<p>学習に使う値を事前に標準化したり、単位変換したりしないでください。モデル内の <code>Standardize=true</code> が標準化を担当します。</p>`)}
${step('8-2','実行して MAT の保存先を選ぶ',`<ol><li>APC でグラフが必要なら <span class="ui-name">グラフを表示（IsPlot = 1）</span> にチェックします。</li><li><span class="ui-name">実行</span> を押します。</li><li>警告が出た場合は内容を読みます。件数不足などで停止した場合は、入力を見直してから再実行します。</li><li>学習後に保存ダイアログが開いたら、保存先とファイル名を指定します。例：<code>apc_model_20261028.mat</code>。</li></ol>`,'保存を確定すると、自動で再読込して検証します。キャンセルした場合は保存せず、後続の SHAP / 面内推定も実行しません。')}
${step('8-3','保存後の検証を確認する',`<p>右下の <span class="ui-name">保存後の自動検証</span> を見て、各行の <code>Passed</code> がすべて成功であることを確認します。1つでも失敗したモデルは制御へ渡しません。APC の SHAP や面内の推定結果が上側に表示された後も、検証表は右下に残ります。</p>`,'変数名は <code>Train_Model</code> だけ、クラスは <code>RegressionGP</code>、説明変数順・ResponseName・学習条件・行数・保存前後の予測値が一致すること。')}
${shot('12-warning-area','警告を残す欄と、保存後検証表の表示位置','警告の文字列と表示位置の見本です。学習・保存後検証は実行していないため、右下の検証表は空欄です。')}
<h3>8-A　スイングカーブ学習</h3><p><span class="ui-name">2 スイングカーブ学習</span> を選びます。RESIST_TH は必ず4番目の説明変数として割り当て、y を指定します。保存・検証までで処理が終わり、学習後 SHAP は自動では実行しません。ノイズ除去用 SHAP は10章から別に実行します。</p>
${shot('02-swing','スイングカーブ学習：RESIST_TH を4列目にする')}
<h3>8-B　面内学習と、追加の推定</h3><ol><li><span class="ui-name">3 面内学習・推定</span> を選び、学習用の X・Y・y を割り当てます。</li><li>学習と同時に別座標を推定するなら、<span class="ui-name">推定用 Excel / CSV を開く（省略可）</span> を押します。</li><li>推定用ファイルについても、シート・ヘッダー行を指定し、下の対応表で X・Y を割り当てます。</li><li>両方の対応表を確認してから実行します。保存・検証の成功後に推定を行います。</li></ol><p>半径は学習・推定の両方へ追加されます。範囲外の行は <code>OutsideTrainingRange</code> で分かります。範囲チェックは X・Y・半径それぞれの最小〜最大であり、範囲内の予測精度を保証するものではありません。</p>
${shot('03-in-plane','面内学習：上が学習データ、下が省略可能な推定データ')}
<h3>8-C　汎用 GPR 学習</h3><ol><li><span class="ui-name">4 汎用 GPR 学習</span> を選びます。</li><li>数値欄で説明変数の個数を指定します。目的変数の y は個数に含めません。</li><li>入力1、入力2…の順に列を選び、最後の y に目的変数を割り当てます。</li><li>列の意味と順序を記録し、確認ボタンを押してから学習します。</li></ol><p>このモデルではファイル上の名前をモデルの PredictorNames に設定しません。後で推定するときも、利用者が同じ入力順を選ぶ必要があります。</p>
${shot('04-generic','汎用 GPR：説明変数数と、入力1からの順序を確認する')}
`);

add('prediction','保存済みモデルで推定する','USER · PREDICTION',`
${step('9-1','モデルと推定方式を選ぶ',`<ol><li><span class="ui-name">5 保存モデルで推定</span> を選びます。</li><li>方式欄で APC / スイング / 汎用は <span class="ui-name">汎用推定</span>、面内モデルは <span class="ui-name">面内推定</span> を選びます。</li><li><span class="ui-name">学習済み MAT を開く</span> を押し、利用するモデルを選びます。</li><li>表示された <code>PredictorNames</code> と <code>ResponseName</code> を確認します。</li></ol>`,'列名を持たないモデルを、列数だけで面内モデルだと判断しないこと。利用するモデル種別を利用者が確認します。')}
${step('9-2','推定データを読み込み、説明変数順を合わせる',`<p>CSV / Excel を読み込み、対応表で入力列を選びます。汎用推定はモデルの PredictorNames の順に合わせます。面内推定に渡す入力は <strong>X・Y の2列</strong>です。半径は内部で追加されます。</p><p>入力ファイルに目的変数の列があっても、推定用の入力列には割り当てません。モデルの列数と異なる入力では停止します。</p>`)}
${step('9-3','確認して推定する',`<p>確認ボタンを押してから <span class="ui-name">実行</span> を押します。結果表の <code>y_pred</code> が予測値、<code>SourceRow</code> が元ファイルの行番号です。面内推定では <code>OutsideTrainingRange=true</code> の行を確認します。</p>`,'予測を出力するとき、元データの順序と SourceRow の対応が分かること。')}
${shot('05-predict','保存モデルで推定：モデル情報・方式・入力列を確認する')}
`);

add('shap','SHAP 解析とノイズ除去用の寄与','USER · SHAP',`
<h3>10-A　APC 学習後の SHAP</h3><p>APC では MAT の保存と自動検証が成功すると SHAP を算出します。対象は先頭から最大1000行です。ランダムに対象行を選びません。1000行を超えると制限の警告が残ります。IsPlot をオンにすると分布図と説明変数ごとの依存図を表示します。</p>
<h3>10-B　別データで SHAP の依存関係を確認する</h3><ol><li><span class="ui-name">6 SHAP 解析</span> を選び、方式を <span class="ui-name">SHAP依存確認</span> にします。</li><li>学習済み MAT と、解析したい CSV / Excel を選びます。</li><li>モデルの PredictorNames と同じ順に入力列を割り当て、確認ボタンを押します。</li><li>グラフが必要なら IsPlot をオンにして実行します。</li></ol><p>画面の処理中表示が消えるまで待ちます。SHAP 結果は行が対象データ、列が説明変数です。<code>SourceRow</code> は元ファイルの行番号です。</p>
${shot('06-shap','SHAP依存確認：モデルと別データを組み合わせる')}
<h3>10-C　スイングカーブのノイズ除去用 SHAP</h3><ol><li>方式を <span class="ui-name">ノイズ除去用SHAP</span> に変更します。</li><li>スイングカーブ仕様の4変数モデルを選びます。</li><li>SIN_TH、SIN_RN、NSG_TH、RESIST_TH を順に割り当てて再確認します。</li><li>実行し、結果の <code>shap_resist</code> を保存します。</li></ol><p><code>shap_resist</code> は RESIST_TH の寄与です。<strong>測定値そのものや、ノイズ除去済みの測定値ではありません。</strong>ノイズ除去用では、背景データ数を変える引数を付けない原仕様を維持しています。</p>
${shot('13-denoise-shap','ノイズ除去用SHAP：4番目の RESIST_TH の寄与を取り出す')}
${note('グラフと処理件数','グラフは別ウィンドウです。重要度順に表示し、依存図の色は自分以外の重要な変数を使います。APC 学習後の1000行制限は対象行数の制限です。背景データは正本どおりモデル内の学習データを使うため、処理が短時間で終わる保証はありません。')}
`);

add('statistics','指標・要約統計・DOE・ワードクラウド','USER · OTHER FUNCTIONS',`
<h3>11-A　評価指標</h3><ol><li><span class="ui-name">7 評価指標</span> でデータを読み込みます。</li><li>col1 に実測値、col2 に予測値を割り当てます。</li><li>指標を選択し、KL / 相互情報量なら必要に応じてビン数を設定します。0 は自動です。</li><li>列の対応を確認し、実行します。</li></ol>
${table(['表示','意味 / 条件'],[['一括','rmse → mae → r → r_squared の順。RMSPE / KL / 相互情報量は含みません。'],['RMSE / MAE','値が小さいほど差が小さい指標です。元の値と同じ単位です。'],['RMSPE (%)','百分率。col1 に0があると計算を停止します。'],['Pearson r','相関係数。2点以上必要です。'],['r²（相関係数の2乗）','<code>1 − SSres / SStot</code> とは異なります。一定量ずれた予測でも1になる場合があります。'],['KL / 相互情報量','ヒストグラムと擬似カウントから計算。単位はそれぞれ nats / bits。ビン数に依存します。']])}
${shot('07-metrics','評価指標：実測値と予測値の2列から算出する','R2022b で説明用のベクトル actual=[1,2,4]、predicted=[2,3,5] から算出した値を表へ設定しています。R2025b アプリの実行結果ではありません。')}
<h3>11-B　列の要約統計量</h3><p><span class="ui-name">8 列の要約統計量</span> で入力ファイルを開き、一覧から対象列を複数選びます。Windows で複数項目を選ぶときは Ctrl / Shift を使います。確認ボタンを押して実行すると、列ごとに横並びで表示します。</p><p>件数、欠損件数、平均、中央値、最大、最小、範囲、IQR、Q1、Q3、不偏標準偏差の11行です。NaN は除外します。有効な値が2件未満なら停止します。</p>
${shot('08-summary','要約統計量：複数列を選び、11項目を横並びで見る','R2022b で説明用ベクトル demo_A=[1,2,3,4,NaN]、demo_B=[2,4,6,8,NaN] から算出した値を表示しています。')}
<h3>11-C　D 最適計画</h3><ol><li><span class="ui-name">9 D 最適計画</span> を選びます。ファイル入力や列確認は不要です。</li><li>因子数と実験数を正の整数で入力します。例：因子数2、実験数12。</li><li>再現したい場合は seed を固定します。例：42。空欄なら毎回初期化します。</li><li>実行し、計画行列を CSV / Excel へ保存します。</li></ol><p>作成するのは二次モデル用の<strong>符号化された計画値</strong>です。実際の温度や膜厚へ自動で換算しません。同じ seed の再現性を、同じ MATLAB 環境で確認してください。</p>
${shot('09-doe','D 最適計画：因子数・実験数・seed を指定する')}
<h3>11-D　ワードクラウド</h3><ol><li><span class="ui-name">10 ワードクラウド</span> を選びます。</li><li>テキスト欄へ直接入力するか、<span class="ui-name">テキストファイルを開く</span> から .txt を読みます。</li><li>日本語は単語間を空白で区切ります。自動の分かち書きはありません。</li><li>実行すると単語の件数表と、別ウィンドウの図が表示されます。</li></ol><p>空白・全角空白・句読点・改行等で分割し、小文字化して集計します。1文字以下の単語は除外します。該当語が残らなければ入力を見直します。</p>
${shot('10-words','ワードクラウド：テキスト入力と単語の件数表','R2022b で説明用テキストから単語数を算出して表示しています。測定データや社内資料は使用していません。')}
${shot('14-wordcloud','別ウィンドウで表示するワードクラウドの例','R2022b / 説明用テキストの描画結果です。撮影用コードは Title プロパティで題名を設定しています。R2025b のアプリ本体のタイトル設定は未検証です。')}
`);

add('export','結果・グラフ・ログを保存する','USER · OUTPUTS',`
${step('12-1','結果を CSV / Excel に保存する',`<p>結果が表示されたら <span class="ui-name">結果を CSV / Excel に保存</span> を押します。保存形式・保存先・ファイル名を選びます。例：<code>apc_shap.csv</code>、<code>in_plane_prediction.xlsx</code>。出力後にファイルを開き、列名・件数・SourceRow を確認してください。</p>`,'MAT モデルの保存と、結果表の書出しを混同しないこと。CSV / Excel から制御用の RegressionGP は復元できません。')}
${step('12-2','グラフを PNG に保存する',`<p>IsPlot をオンにして図を表示した後、<span class="ui-name">グラフを PNG に保存</span> を押します。グラフ一覧で保存する図を選び、保存先を指定します。図を閉じた場合やグラフを表示しなかった場合は、保存する図がない旨を表示します。</p>`)}
${step('12-3','学習ログを確認する',`<p>ログは作成・利用した環境の <code>prefdir</code> 配下に保存します。ユーザー名を含む絶対パスは固定しません。MATLAB 上なら次のコマンドで場所を確認できます。</p>${code('開発用 MATLAB でログの場所を表示',`log_folder = fullfile(prefdir, 'StandaloneAnalysisApp', 'logs');
disp(log_folder)`)}<p>ファイル名は <code>training.jsonl</code> です。exe の利用者で場所が分からない場合は、同じ端末・同じユーザーの環境を確認できる配布担当者に確認します。</p>`)}
${table(['出力','中身 / 注意点'],[['学習済み .mat','変数は Train_Model の1件。完全な RegressionGP で、学習データも含みます。入力データと同じ管理区分で扱います。'],['結果 .csv / .xlsx','SHAP、予測、統計、実験計画、単語件数など。必要に応じて SourceRow が追加されます。'],['グラフ .png','選択した1枚のグラフ。モデルの代わりにはなりません。'],['training.jsonl','日時、機能、入力ファイル名、行数、学習設定、保存先、検証結果、終了状態、処理時間。X・y の測定値自体は記録しません。']])}
`);

add('verification','完了確認','CHECK BEFORE HANDOVER',`
<p>チェック欄はこのページを見ている間の確認用です。ページを再読込するとリセットされます。正式な確認結果はプロジェクトの <code>verification.md</code> 等へ記録してください。</p>
<div class="checklist-grid"><article><h3>作成・配布担当者</h3>${[
'Windows 64bit / MATLAB R2025b と必要製品を確認した。',
'AnalysisApp.mlapp を作成し、開き直して実行できた。',
'R2025b で全テスト成功、失敗・未完了0件を確認した。',
'旧・新モデルの列順・設定・予測差を比較した。',
'Windows ビルド出力を確認し、付随ファイルも配布した。',
'MATLAB 本体のない Runtime R2025b 端末で全機能を確認した。',
'SHAP / ワードクラウドのグラフと PNG 保存を確認した。',
'保存先・ログ先の書込みが可能なことを確認した。'].map(check).join('')}</article>
<article><h3>モデル作成・解析の利用者</h3>${[
'入力ファイル、シート、ヘッダー行を確認した。',
'目的変数と説明変数の意味・単位・順番を確認した。',
'列の対応を確認してから実行した。',
'MAT 保存後の全検証が成功している。',
'件数不足・外挿・SHAP 制限の警告を確認した。',
'結果の件数と SourceRow を確認した。',
'必要な CSV / Excel / PNG を保存できた。',
'モデルファイルと結果を所定の管理場所へ保存した。'].map(check).join('')}</article></div><button type="button" class="reset-checks">この章のチェックをリセット</button>
${note('保存後の検証に失敗した場合','画面上の該当項目を確認し、ファイルのパスとエラー内容を担当者へ伝えます。検証表の値を書き換えたり、チェックを手動で成功扱いにしたりして進めないでください。','warning')}
`);

add('troubleshooting','困ったとき','TROUBLESHOOTING',`
<div class="faq-list">${[
['R2025b が必要、というメッセージで止まる','現在の MATLAB / Runtime が対象外です。作成 PC は <code>version(\'-release\')</code> で確認し、R2025b を使います。配布先は Runtime R2025b と対応する exe の組合せを確認します。製品コードのリリース確認を外さないでください。'],
['build_windows:missingMlapp で止まる','<code>app/AnalysisApp.mlapp</code> がありません。4章の手順で作成し、保存先とファイル名を確認します。別名やプロジェクト直下への保存ではビルド入口に見つかりません。'],
['MATLAB Compiler / Statistics Toolbox が見つからない','作成用 MATLAB の <code>ver</code> で製品のインストールを確認し、利用可能なライセンスも担当者に確認します。Runtime はビルド用 MATLAB の代わりにはなりません。'],
['列対応が未確認、または必須列が不足と表示される','入力列の未選択・重複を見直し、必要な列をすべて割り当てます。その後「上表の列対応・順序を確認」を押します。入力やモデルを変えた後は再確認が必要です。'],
['ヘッダーが空 / 重複、または列名が合わない','元ファイルの指定ヘッダー行を確認します。説明文の行や空行をヘッダーとして指定していないか確認し、列名を一意にします。大小文字や余分な空白も確認します。'],
['欠損値を含む行番号が表示される','表示された元ファイルの行を確認します。アプリはその行を削除して学習を継続しません。勝手な0埋めや平均値補完をせず、入力の扱いを確認して修正したファイルを再読込します。'],
['データが少ないため処理を中止します','APC は25行未満で停止します。25行以上の有効データを用意します。25〜149行では注意警告が残ります。スイングカーブに APC の件数ルールを当てはめないでください。'],
['モデルを保存したのに SHAP / 面内推定が出ない','保存ダイアログをキャンセルしていないか、保存後検証が失敗していないかを確認します。保存キャンセル時は後続処理をしない仕様です。'],
['このモデルを制御に使用しないでください、と表示される','その MAT を制御へ渡さず、右下の検証表の失敗行を確認します。元のモデルとファイルを保持し、モデルを作成した環境・設定とともに担当者へ確認します。'],
['学習済みモデル（Train_Model）が見つかりません','別用途の MAT、または変数名が異なるファイルです。このアプリの仕様で作成されたモデルを選びます。別名の変数をアプリ側で勝手に読み替えません。'],
['SHAP の処理が長い / 算出に失敗する','処理中表示と、停止時の詳細メッセージを確認します。モデルの説明変数順・入力形式・R2025b / Statistics Toolbox を確認します。計算時間の保証値はありません。測定値や機密データを外部サービスへ渡して対処しないでください。'],
['相関や r² が NaN になる','2点未満、または片方の列がすべて同じ値など、相関を定義できない条件を確認します。NaN を良好なモデルの意味で扱わないでください。'],
['ワードクラウドの表が出た後、title の入力引数エラーが出る','R2022b の参考撮影では title にフォント指定を渡す形式が非対応でした。図の撮影用コードでは Title プロパティを使用しています。アプリ本体の R2025b で同じエラーが出る場合は、<code>AnalysisController.m</code> の wordcloud / title 呼出しを保守担当者へ確認します。この手順書作成ではアプリ本体を変更していません。'],
['結果やログの保存に失敗する','保存先フォルダの書込み権限、ファイルが Excel 等で開かれていないか、空き容量を確認します。別の書込み可能なフォルダへ保存する場合も、社内の管理場所のルールに従います。'],
['exe が起動しない / DLL が見つからない','ビルドと同じ R2025b の Runtime、OS・64bit、対応する更新版を確認します。exe だけをコピーしていないか、付随ファイルと出力 readme も確認します。'],
['手順書の画像が見えない','docs/user-guide フォルダ全体を移しているか確認します。images / base.css / procedure-guide.css / procedure-guide.js / guide-extra.css / guide-extra.js を HTML と同じ相対位置に置きます。']
].map(([q,a])=>`<details><summary>${q}</summary><div><p>${a}</p></div></details>`).join('')}</div>
<p>解決しない場合は、<strong>実行日時、利用したタブ、MATLAB / Runtime のリリース・更新版、表示されたエラー文、保存後検証の失敗項目</strong>を担当者へ伝えてください。エラーのスクリーンショットへ測定値や機密のファイル名が写る場合は、送付先と範囲を確認してください。</p>
`);

add('references','参考資料と、この資料の確認範囲','SOURCES AND SCOPE',`
<h3>プロジェクト内の正本</h3><ul class="source-list"><li><a href="../../README.md">README.md</a><small>構成、入力と保存仕様、起動方法。</small></li><li><a href="../windows-build.md">Windows ビルド手順（Markdown）</a></li><li><a href="../specification.md">原仕様</a><small>MR-01〜MR-09、T-01〜T-10、Q-01〜Q-11 の正本。</small></li><li><a href="../../verification.md">検証記録</a> / <a href="../../issues.md">残課題</a></li></ul>
<h3>MathWorks 公式資料</h3><ul class="source-list"><li><a href="https://www.mathworks.com/help/matlab/creating_guis/app-designer-startup-function.html">startupFcn の追加と起動時の処理</a><small>アプリノードの Callbacks メニュー、StartupFcn コールバック。</small></li><li><a href="https://www.mathworks.com/help/matlab/creating_guis/app-designer-code-generation.html">App Designer Code View のコード管理</a><small>プロパティ・コールバックの追加。最新ページには R2026b の新仕様もあるため、R2025b の .mlapp 手順を使用。</small></li><li><a href="https://www.mathworks.com/help/compiler/compiler.build.standalonewindowsapplication.html">compiler.build.standaloneWindowsApplication</a><small>Windows での .mlapp ビルド、出力ファイル、Runtime を含まないこと。</small></li><li><a href="https://www.mathworks.com/help/compiler/standalone-application-target.html">スタンドアローンアプリの配布</a><small>ビルドと配布先の OS、配布するファイル。</small></li><li><a href="https://www.mathworks.com/products/compiler/matlab-runtime.html">MATLAB Runtime の入手</a></li><li><a href="https://www.mathworks.com/help/matlab/ref/exportapp.html">exportapp</a><small>参考 UI 画像の書出しに使用。</small></li></ul>
<h3>画像と文書の確認範囲</h3><p>アプリ画面は <code>app/AnalysisController.m</code> の一時的な表示専用コピーで撮影しました。操作コールバックを無効にし、合成データや説明用の列対応を表へ設定しています。製品ソースのリリース確認と学習・保存処理は変更していません。指標・要約統計・単語件数・ワードクラウドの説明用計算は R2022b です。</p><p>参考プレビューと R2025b 製品アプリの実行確認は別です。R2025b のビルド成功、Runtime 上の実行、モデル互換性は未確認です。手順書のブラウザ確認結果は同梱の <a href="guide-verification.md">guide-verification.md</a> に記録します。</p>
<p>App Designer の2画像は MathWorks 公式資料から取得し、操作位置の説明に使用しています。原画像の出典と掲載ページのリリースは各画像に記載しています。自端末で撮影した画像ではなく、当プロジェクトのビルド成功を示す画像でもありません。</p><p class="privacy-note">この資料の更新日：2026-10-28（JST）。画像・フォント・ライブラリを外部から読み込まない構成です。公式サイトへのリンクを開くときはネット接続を使用します。</p>
`);

const nav = `<aside id="sidebar" class="sidebar" aria-label="目次"><div class="sidebar-header"><p class="eyebrow">MATLAB ANALYSIS APP</p><p class="sidebar-title">ビルド・利用手順書</p><p class="sidebar-subtitle">Windows 64bit · R2025b</p></div><nav><ol class="toc-list">${sections.map((s,i)=>`${[0,3,6,12].includes(i)?`<li class="toc-group">${i===0?'はじめに':i===3?'作成・配布担当者':i===6?'アプリ利用者':'確認と対処'}</li>`:''}<li><a href="#${s.id}">${i+1}. ${s.title}</a></li>`).join('')}</ol></nav><div class="sidebar-footer"><span class="status-dot" aria-hidden="true"></span>更新 2026-10-28 · PC閲覧用</div></aside>`;
const main = `<main id="main-content" class="main-content"><header class="hero"><div class="hero-content"><p class="eyebrow">BUILD &amp; OPERATING GUIDE</p><h1>MATLAB 解析アプリ<br><span>ビルド・利用手順書</span></h1><p class="hero-lead">App Designer の入口作成から、Windows 配布、10機能の操作、出力確認まで。</p><div class="hero-badges"><span>対象：Windows 64bit / R2025b</span><span>画像：R2022b の参考撮影</span><span>更新：2026-10-28</span></div></div></header><p class="guide-status"><strong>現在の到達点：</strong>ソース作成済み。.mlapp 作成・R2025b 全テスト・Windows exe 生成・Runtime 動作確認は後工程です。この資料は、その作業を進めるための手順書です。</p>${sections.map((s,i)=>`<section id="${s.id}" class="content-section"><div class="section-heading"><span class="section-number">${String(i+1).padStart(2,'0')}</span><div><p class="section-kicker">${s.kicker}</p><h2>${s.title}</h2></div></div>${s.body}</section>`).join('\n')}<footer class="page-footer"><p>StandaloneAnalysisApp · ビルド・利用手順書</p><p>2026-10-28 · 画像は参考プレビュー / 対象環境での確認は未完了</p></footer></main>`;
let skeleton = `<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="MATLAB解析アプリの操作手順書"><title>MATLAB解析アプリの手順書</title>
<link rel="icon" href="data:,"><link rel="stylesheet" href="procedure-guide.css"><script src="procedure-guide.js" defer></script>
</head><body id="top"><a class="skip-link" href="#main-content">本文へ移動</a>
<button id="toc-toggle" class="toc-toggle" type="button" aria-controls="sidebar" aria-expanded="false"><span aria-hidden="true">☰</span> 目次</button>
<aside id="sidebar" class="sidebar"></aside><div id="sidebar-overlay" class="sidebar-overlay" aria-hidden="true"></div>
<main id="main-content" class="main-content"></main>
<button id="back-to-top" class="back-to-top" type="button" aria-label="ページ上部へ戻る"><span aria-hidden="true">↑</span> トップへ戻る</button>
</body></html>`;
skeleton = skeleton.replace(/<title>[\s\S]*?<\/title>/,'<title>MATLAB解析アプリ｜ビルド・利用手順書</title>');
skeleton = skeleton.replace(/<meta name="description"[^>]*>/,'<meta name="description" content="MATLAB R2025b解析アプリのWindowsビルド・配布・利用を、参考スクリーンショットとともに説明する手順書。">');
skeleton = skeleton.replace(/<aside id="sidebar"[\s\S]*?<\/aside>/,nav);
skeleton = skeleton.replace(/<main id="main-content"[\s\S]*?<\/main>/,main);
skeleton = skeleton.replace(/\s*<link rel="stylesheet" href="guide-extra.css">/g,'').replace(/\s*<script src="guide-extra.js" defer><\/script>/g,'');
skeleton = skeleton.replace('</head>','  <link rel="stylesheet" href="guide-extra.css">\n  <script src="guide-extra.js" defer></script>\n</head>');
skeleton = skeleton.replace(/\s*<dialog id="image-dialog"[\s\S]*?<\/dialog>/g,'');
skeleton = skeleton.replace('</body>','<dialog id="image-dialog" class="lightbox" aria-labelledby="dialog-caption"><div class="lightbox-bar"><p id="dialog-caption"></p><button id="dialog-close" class="lightbox-close" type="button">閉じる（Esc）</button></div><img id="dialog-image" alt=""></dialog>\n</body>');
fs.writeFileSync(pagePath,skeleton);
console.log(JSON.stringify({page:pagePath,sections:sections.length,figures:figureCount,codeBlocks:(skeleton.match(/class="code-block"/g)||[]).length,bytes:Buffer.byteLength(skeleton)}));

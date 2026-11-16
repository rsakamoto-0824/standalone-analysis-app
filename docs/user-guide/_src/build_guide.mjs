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
const shot = (name, caption, detail='R2022b / macOS で、同梱の合成サンプルを実際に学習して撮影した参考画面です（SHAPだけ代替計算）。R2025b / Windows の画面とは細部が異なる場合があります。') => {
  figureCount += 1;
  const png = fs.readFileSync(path.join(guideRoot, "images", `${name}.png`));
  const width = png.readUInt32BE(16), height = png.readUInt32BE(20);
  return `<figure class="screenshot"><button type="button" class="image-open" aria-label="${escape(caption)}を拡大"><img src="images/${name}.png" alt="${escape(caption)}" loading="lazy" width="${width}" height="${height}"></button><figcaption><span class="shot-tag">参考撮影 · R2022b / macOS</span><span class="shot-zoom">クリックで拡大 / Escで閉じる</span><strong>図${figureCount}　${caption}</strong><span class="shot-note">${detail}</span></figcaption></figure>`;
};
const officialShot = (name, caption) => {
  figureCount += 1;
  return `<figure class="screenshot vendor-shot"><button type="button" class="image-open" aria-label="${escape(caption)}を拡大"><img src="images/${name}.png" alt="${escape(caption)}" loading="lazy"></button><figcaption><span class="shot-tag">MathWorks公式資料の掲載例</span><span class="shot-zoom">クリックで拡大</span><strong>図${figureCount}　${caption}</strong><span class="shot-note">出典：<a href="https://www.mathworks.com/help/matlab/creating_guis/app-designer-startup-function.html">Specify Startup Tasks and App Input Arguments in App Designer</a>（掲載ページ R2026b、2026-10-28参照）。当プロジェクトの実行画面ではありません。R2025b ではメニュー名・配置が異なる場合があります。画像 © The MathWorks, Inc.</span></figcaption></figure>`;
};
const check = (text) => `<label><input type="checkbox"> <span>${text}</span></label>`;
const sections = [];
const add = (id,title,kicker,body) => sections.push({id,title,kicker,body});


add('overview','目的と対象','START HERE',`
<p>この手順書は、<strong>Process Insight Tool（MATLAB R2025b 向け）を Windows でビルドし、MATLAB 本体のない端末へ配布して利用する</strong>までの操作を説明します。左の目次から必要な章へ移動でき、画像はクリックして拡大できます。コードは「コピー」ボタンでコピーできます。</p>
<div class="card-grid three-columns"><article class="feature-card"><span class="card-label">作成担当者</span><h3>初回の確認とビルド</h3><p>2〜6章で環境を確認し、ソースからの起動、通し確認、テスト、exe、Runtime を用意します。</p></article><article class="feature-card"><span class="card-label">利用者</span><h3>データを解析</h3><p>アプリを受け取ったら、6章の起動確認と7〜12章の操作を参照します。</p></article><article class="feature-card"><span class="card-label">保守担当者</span><h3>結果と問題を確認</h3><p>13章の完了確認、14章の対処表、15章のソースと公式資料を参照します。</p></article></div>
${table(['項目','現在の状態'],[
['画面・計算・テストのソース','作成済み。2026-11-16 に画面を作り直しました（4ステップで進む学習画面、ホーム、画面内でのシート・ヘッダー行の指定、常に見える選択欄での列の割当）。'],
['手元（R2022b / macOS）での確認','開発用の例外で起動し、同梱サンプルで全機能を通す確認（<code>run_app_flow_check</code> の14項目）と単体テストに成功。SHAP の計算だけは R2025b 専用のため、代替計算で画面の流れを確認しました。'],
['R2025b / Windows での確認','未実施。4章・5章の手順で、対象の PC で確認します。'],
['Windows exe','未生成。5章の手順で作成します。App Designer での手作業は不要になりました。'],
['この手順書の画像','R2022b / macOS で、同梱の合成サンプルを実際に学習して撮影（SHAP は代替計算）。10章の Pro 版カーブ評価の画像の一部は、作り直す前の画面で撮影したものです。数値はすべて説明用です。']])}
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
  app/                  画面のソース（起動口は launch_analysis_app.m）
  core/                 学習・推定・統計・保存後検証
  tests/                単体テストと、全機能の通し確認（run_app_flow_check.m）
  build_windows.m       Windows ビルドの入口
  run_tests.m           R2025b の全テスト
  docs/user-guide/      この手順書と画像・スタイル</pre>
${note('手順書を別の PC へ移すとき','<code>procedure-guide.html</code> だけでなく、<code>docs/user-guide/</code> のフォルダ全体を移してください。画像・CSS・JavaScript は相対パスで参照しています。HTML は PC の Edge / Chrome などで開けます。')}
`);

add('workflow','全体の流れ','TWO WORKFLOWS',`
<h3>作成担当者：最初に1回行う作業</h3><div class="compact-flow"><span><b>1</b>R2025b と製品を確認</span><i>→</i><span><b>2</b>ソースから起動</span><i>→</i><span><b>3</b>通し確認と全テスト</span><i>→</i><span><b>4</b>Windows ビルド</span><i>→</i><span><b>5</b>Runtime 端末で確認</span></div>
<h3>利用者：学習モデルを作成するたびに行う作業</h3><div class="compact-flow"><span><b>1</b>データを開く</span><i>→</i><span><b>2</b>変数を選ぶ</span><i>→</i><span><b>3</b>条件を決めて実行</span><i>→</i><span><b>4</b>結果を比べる</span><i>→</i><span><b>5</b>選んだモデルをMAT保存</span></div>
<p>学習と評価（SHAP を含む）を先に行い、複数の条件を比べてから、採用する1モデルだけを最後に MAT へ保存します。学習画面では、この順番が上のタブ（①〜④）として左から並んでいます。</p>
${note('学習モデルの利用に進む条件','保存後検証がすべて成功したことを確認します。<strong>「このモデルを制御に使用しないでください」</strong>が表示されたファイルは、制御へ渡さずに原因を確認してください。','warning')}
`);

add('launch','ソースから起動して確認する','BUILDER · INITIAL CHECK',`
<p class="section-intro">この章は作成担当者向けです。exe を作る前に、MATLAB R2025b 上でソースのまま起動し、全機能が動くことを確認します。</p>
${step('4-1','アプリを起動する',`${code('MATLAB コマンドウィンドウ',`setup_paths;
controller = launch_analysis_app;          % 通常版の画面
% controller = launch_analysis_app('pro'); % Pro版の画面を確認する場合`)}<p>R2025b ではホーム画面が開きます。R2025b 以外ではリリースエラーで止まります。エラーを避けるために製品コードの確認処理を外さないでください。</p>`,'ホーム画面と、左に「ホーム」「1 APC 学習」〜「10 Help」のメニューが表示されること。')}
${shot('50-home','ホーム画面：やりたいことから各機能へ進む。左のメニューは目的別に並ぶ')}
${step('4-2','全機能の通し確認を実行する',`${code('MATLAB コマンドウィンドウ',`setup_paths;
addpath('tests');
results = run_app_flow_check;`)}<p>アプリを実際に起動し、同梱サンプルで APC・Swing Curve・汎用回帰の学習と保存、炉内補間、推定、SHAP、実験計画、ワードクラウド、設定、入力の誤りの検出を、画面のボタンと同じ入口から順に実行します。数分かかります。設定とログは一時フォルダへ保存するため、利用者の設定は変わりません。R2025b では SHAP も実際に計算します。</p>`,'表の14項目がすべて成功（Passed が true）で、エラーで止まらないこと。失敗した項目は Note の内容を記録します。')}
${step('4-3','画面を自分でも操作する',`<p>「1 APC 学習」などの学習画面で <span class="ui-name">サンプルデータを開く</span> を押すと、同梱の合成データで7章以降の操作を試せます。</p>`)}
${note('App Designer の入口は必須ではありません','以前は App Designer で <code>AnalysisApp.mlapp</code> を手作業で作る必要がありましたが、現在は <code>app/launch_analysis_app.m</code> をそのまま exe の入口にします。<code>.mlapp</code> を入口にしたい場合の作り方は <a href="../windows-build.md">Windows ビルド手順（Markdown）</a>にあります。')}
`);

add('build','全テストと Windows ビルド','BUILDER · TEST AND BUILD',`
${step('5-1','全単体テストを実行する',`${code('MATLAB コマンドウィンドウ',`setup_paths;
results = run_tests;`)}<p>正本コードの照合を行ってから、数値・モデル互換・周期カーネル・複数カーネル比較などの単体テストを実行します。対象 PC の結果を見て、<code>Failed</code> と <code>Incomplete</code> が0件であることを確認してください。</p>`,'エラーで停止せず、すべてのテストが成功すること。手元の R2022b の補助確認とは別に、R2025b で全件を確認します。')}
${code('成否の件数を確認',`fprintf('Passed=%d, Failed=%d, Incomplete=%d\\n', ...
    sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));`)}
${step('5-2','現行モデルとの互換性を確認する',`<p>現行アドインで作った旧モデルと、このアプリで同じデータ・同じ条件から作った新GPRモデルを準備します。照合する数値行列 <code>Xcheck</code> を用意して実行します。</p>${code('MATLAB コマンドウィンドウ',`comparison = compare_models('old.mat', 'new.mat', Xcheck);`)}${table(['モデル','Xcheck の列順'],[['APC / 従来の4列Swing Curve','SIN_TH → SIN_RN → NSG_TH → RESIST_TH の4列。'],['現行のSwing Curve','学習時のPredictorNamesと同じ順序。RESIST_THの1列から対応。'],['面内','X座標 → Y座標 → 半径の3列。半径は <code>sqrt(X.^2 + Y.^2)</code>。'],['汎用回帰のGPR','学習時と同じ P 列を同じ順序で渡します。']])}`,'属性の比較、予測差の最大値、予測の完全一致を確認すること。旧モデル未提供のまま「互換性確認済み」としないでください。')}
${step('5-3','Windows 実行ファイルを作る',`${code('MATLAB コマンドウィンドウ',`standard = build_windows('standard');
pro = build_windows('pro');`)}<p><code>build_windows</code> は R2025b、Windows 64bit、必要製品を確認し、全テスト成功後にビルドします。入口は <code>app/launch_analysis_app.m</code> です（<code>app/AnalysisApp.mlapp</code> を作成済みなら、そちらを使います）。通常版には Pro 専用の評価ファイルを含めません。</p>`,'<code>build/windows/standard/ProcessInsightTool.exe</code> と <code>build/windows/pro/ProcessInsightToolPro.exe</code> が各版の出力先に生成されること。')}
<pre class="mini-path">StandaloneAnalysisApp/
  build/
    windows/
      standard/ProcessInsightTool.exe
      pro/ProcessInsightToolPro.exe
      （各フォルダにreadme.txtと付随ファイル）
      その他、ビルドで生成された付随ファイル</pre>
${note('このコマンドが作成する範囲','現在のスクリプトは exe と付随ファイルを作ります。<strong>MATLAB Runtime や Runtime を含むインストーラーは作りません。</strong>出力の <code>readme.txt</code> も確認してください。Windows 用 exe の作成は Windows 上で実行します。','warning')}
<p>ビルド成功画面・生成済み exe のスクリーンショットはありません。この工程は Windows R2025b で未実施のため、実際の出力を担当者が確認して記録します。</p>
`);


add('runtime','配布とアプリの起動','RUNTIME · INSTALL AND START',`
${step('6-1','Runtime R2025b を用意する',`<ol><li>作成担当者がビルドした MATLAB のリリース・更新版を確認します。</li><li>公式の Runtime 配布ページから Windows 64bit / R2025b の対応版を入手します。</li><li>会社の標準手順に従い、配布先へ Runtime をインストールします。</li></ol><p>リリースは R2025b に揃えます。同じリリース内ではビルドに対応する更新版を使用し、その組合せで確認します。参照：<a href="https://www.mathworks.com/products/compiler/matlab-runtime.html">MathWorks MATLAB Runtime</a>。</p>`)}
${step('6-2','ビルド出力フォルダをコピーする',`<p><code>build/windows/standard/</code> または <code>build/windows/pro/</code> の配布する版のファイルを一式で渡します。配布先の例は <code>${distributionFolder}</code> です。利用者はこの場所で exe を起動します。ソース一式を持っていない利用者は <code>run_tests</code> や <code>build_windows</code> を実行しません。</p>`)}
${step('6-3','exe を起動して最初の動作を確認する',`<ol><li><code>ProcessInsightTool.exe</code>（Pro版は<code>ProcessInsightToolPro.exe</code>）をダブルクリックします。</li><li>起動処理が完了し、ホーム画面と左のメニューが表示されるまで待ちます。所要時間の基準値は設定していません。</li><li>機密情報のない確認用データで、読込・結果保存・ログ書込みを確認します。</li></ol>`,'MATLAB 本体が入っていない端末でも、必要な画面と機能が動くこと。')}
${note('アプリの利用中の通信','アプリから外部サービスへ測定データを送信する処理はありません。Runtime の入手・配布と、アプリがデータを解析する操作は別の工程です。')}
`);


add('input','画面の構成と、データの開き方','USER · COMMON OPERATION',`
<p class="section-intro">ここからは利用者向けです。どの機能も「左から右へ、上から下へ」進めば操作できるようにしています。</p>
${step('7-1','ホームと左のメニューから機能を選ぶ',`<ol><li>起動するとホームが開きます。やりたいことのボタン、または左のメニューから機能を選びます。</li><li>左のメニューは「モデルを作る（1〜4）」「モデルを使う・調べる（5・6）」「計画・その他（7・8）」「アプリ（9 設定・10 Help）」に分かれています。</li><li>各画面の下にある<strong>状況欄</strong>に、処理の状況と注意を新しい順に表示します。エラーや注意はダイアログでも表示します。</li></ol>`)}
${step('7-2','データを開く',`<ol><li><span class="ui-name">Excel / CSV を開く</span> を押してファイルを選びます。</li><li>Excel で複数のシートがある場合は、同じ画面の <span class="ui-name">シート</span> で選びます。</li><li>列名が1行目でない場合は <span class="ui-name">ヘッダー行</span> の番号を変えます。変えるとすぐに読み直します。</li><li>下の表に先頭100行を表示します。列名と値が正しく読めていることを確認します。</li></ol><p>手元にデータがない場合は <span class="ui-name">サンプルデータを開く</span> で、同梱の合成データを開けます。</p>`,'ファイル名の横に「行数 × 列数」が表示され、表に列名とデータが見えること。')}
${shot('51-data-step','① データを開く：シートとヘッダー行を画面内で指定し、先頭100行を確認する')}
${table(['入力ファイルの条件','内容'],[
['形式','<code>.xlsx</code> または <code>.csv</code>。'],
['列名（ヘッダー）','空でない、重複しない名前にします。同じ列名を自動で変更しません。'],
['値','数値、または数値として読める文字。単位の変換や標準化は行いません。'],
['空欄・NaN','学習・推定・SHAP で選んだ列に空欄があると、元ファイルの行番号を表示して止まります（行を勝手に除いて続行しません）。炉内補間の計測列だけは「未計測」として扱います。'],
['行番号','結果の表の <code>SourceRow</code> は、元ファイルの行番号です。']])}
${note('確認をやり直すタイミング','入力ファイルや選んだ列を変えると、列の確認（✓ 確認済み）は解除されます。もう一度「列対応を確認」を押してください。すでに表示している結果や学習済みモデルの一覧は消えません。','warning')}
`);

add('training','学習：モデルを評価・比較して保存する','USER · MODELING',`
<p class="section-intro">「1 APC 学習」「2 Swing Curve学習」「3 汎用回帰学習」は同じ進め方です。上のタブを左から <strong>① データを開く → ② 変数を選ぶ → ③ 条件を決めて実行 → ④ 結果を比べて保存</strong> の順に進みます。①は7章を参照してください。</p>
${step('8-1','② 変数を選ぶ',`<ol><li>左の <span class="ui-name">目的変数</span> で、予測したい列を選びます。複数選ぶと列ごとに別のモデルを作ります（最大20列。Ctrl を押しながらクリック）。目的変数は自動では選ばれません（列名が CD・y・膜厚・屈折率のときだけ初期選択します）。</li><li>右の <span class="ui-name">説明変数</span> を、下の表のとおりに選びます。</li><li>右下の「モデルへ渡す順序」の表で、変数の名前と順序を確認します。</li><li><span class="ui-name">列対応を確認</span> を押します。数値でない値・空欄・列の重複・目的変数との重なりがあると、理由を表示して止まります。</li></ol>${table(['機能','説明変数の選び方'],[
['1 APC 学習','SIN_TH・SIN_RN・NSG_TH・RESIST_TH の4変数それぞれに、入力ファイルの列をドロップダウンで割り当てます。列名が同じ場合は自動で選びます。保存するモデルの変数名と順序は固定です。'],
['2 Swing Curve学習','<span class="ui-name">モード</span> で「下地なし（膜厚のみ）」か「下地あり」を選びます。<span class="ui-name">レジスト膜厚の列</span> を選び、下地ありのときは <span class="ui-name">下地の説明変数</span> を一覧から複数選びます。膜厚（RESIST_TH）は必ず最後の説明変数になります。'],
['3 汎用回帰学習','入力に使う列を一覧から複数選びます。順序を変えるときは、下の表で行を選んでから <span class="ui-name">▲ 上へ</span> / <span class="ui-name">▼ 下へ</span> を押します。GPR の MAT は列名を持たないため、この順序（1列目、2列目…）で入力と対応します。']])}`,'左下に緑の文字で「✓ 確認済み」と、目的変数・説明変数の列数、行数が表示されること。')}
${shot('52-variables-apc','APC：4変数にドロップダウンで列を割り当て、順序の表で確認する')}
${shot('53-variables-swing','Swing Curve：モード・膜厚の列・下地の説明変数を同じ画面で選ぶ')}
${shot('54-variables-generic','汎用回帰：入力に使う列を選び、順序を確認する')}
<h3 id="kernel-comparison">8-2　③ 条件を決めて実行する（複数条件の比較）</h3>
<ol><li>左の <span class="ui-name">GPRのカーネル</span> を選びます。複数選ぶと比較します（Ctrl を押しながらクリック）。汎用回帰では <span class="ui-name">回帰方式</span>（GPR・重回帰・PLS回帰）も選べ、PLS を選ぶと <span class="ui-name">PLSの成分数</span> を入力できます。</li><li>右で評価の条件を決めます。条件を2つ以上選ぶと、同じ分割の交差検証（学習に使っていない行での予測）で比べます。分割数の初期値は5、乱数seedは0です。</li><li>条件が1つのときは、学習データでの当てはまりを表示します。<span class="ui-name">条件が1つでも交差検証で評価する</span> にチェックを入れると、1条件でも交差検証します。</li><li><span class="ui-name">SHAPも計算する</span> を外すと、SHAP を省いて速く終わります。SHAP は④で後から計算できます。</li><li>下の緑の文で、学習するモデルの数（目的変数 × 条件）を確認し、<span class="ui-name">モデリング・SHAP評価を実行</span> を押します。処理中は進捗を表示し、中止もできます。</li></ol>
<p>GPR の Fit method は「9 設定」で指定した値を、すべての GPR に共通で使います。この画面では変更しません。</p>
${shot('55-conditions','③ 条件を決めて実行：カーネルを複数選ぶと交差検証で比較する')}
${shot('71-conditions-generic','汎用回帰：GPR・重回帰・PLS回帰を選んで同じ分割で比較する')}
${note('検証の範囲と計算量','交差検証の指標は、全行の検証予測をまとめて計算します（分割ごとの平均ではありません）。条件ごとに「分割数＋1」回の学習を行うため、条件や目的変数が多いほど時間がかかります。APC は各分割の学習に25行以上が必要です。行をランダムに分けるため、ロットや時系列のまとまりは分離しません。比較に使った検証値は条件選びにも使っているので、採用後は別のデータでも確認してください。')}
${step('8-3','④ 結果を比べる',`<ol><li>上の一覧に、学習したモデルが1行ずつ並びます。<strong>行をクリックすると、下に評価とグラフを表示します</strong>（選んだ行は青く表示）。</li><li>「順位」は、同じ実行・同じ目的変数の中で RMSE が小さい順です。「評価データ」が「学習データ」の行は、学習に使ったデータでの当てはまりです。</li><li>下の <span class="ui-name">グラフ</span> で、実測値と予測値・残差・条件の比較（RMSE）・SHAP を確認します。実測値と予測値・残差は「色を指定する列」で入力ファイルの任意の列により色分けできます。</li><li>表のタブで、評価指標（8指標）・検証分割・予測結果・列の要約・SHAP値を確認できます。</li><li>条件を変えて③をもう一度実行すると、以前の結果を残したまま一覧へ追加します。</li></ol><p>グラフを広く見たいときは <span class="ui-name">グラフを大きく表示</span> を押すと、一覧をたたみます。一覧はアプリを終了すると消えるため、使うモデルは終了前に保存してください。</p>`,'一覧の「状態」が成功で、見出しに RMSE・R²・件数が表示されること。失敗した行は「備考」に理由が表示されます。')}
${shot('57-results','④ 結果を比べて保存：一覧の行をクリックすると、下に評価とグラフを表示する')}
${shot('72-results-generic','条件の比較（RMSE）：同じ目的変数の条件を棒グラフで比べる')}
${shot('58-results-shap','SHAP分布と依存図もアプリ内に表示する','R2022b のため SHAP は代替計算（1列を平均に置き換えた予測差）で描いた参考画面です。R2025b では shapley の計算結果を標準の swarmchart で表示します。')}
${step('8-4','選んだ1モデルだけをMAT保存する',`<ol><li>一覧で保存するモデルの行をクリックします。</li><li><span class="ui-name">選択モデルをMAT保存</span> を押し、保存先を決めます。初期の名前は <code>Train_Model_目的変数.mat</code>（APC）、<code>SwingCurve_Model_目的変数.mat</code>、<code>GenericGPR_Model_目的変数.mat</code>、<code>GenericRegression_Model_目的変数.mat</code>（重回帰・PLS）です。</li><li>保存後、自動で読み直して検証し、<span class="ui-name">保存後検証</span> の表を表示します。一覧の「保存先」にもファイル名が入ります。</li></ol><p>再学習や SHAP の再計算は行わず、全データで学習済みのそのモデルを保存します。GPR の MAT に入る変数は <code>Train_Model</code> だけです。重回帰・PLS は別形式の <code>Regression_Model</code> で、GPR 専用の制御側へは渡しません。</p>`,'保存後検証の Passed がすべてチェック済みであること。1つでも失敗すると「このモデルを制御に使用しないでください」と表示します。')}
${shot('59-results-verification','保存後検証：変数名・説明変数の名前と順序・設定・行数・予測の一致を確認する')}
<h3 id="periodic-kernel">8-5　Swing Curve向けの周期カーネルを選ぶ</h3>
<p>Swing Curve学習の③で、カーネルに <code>swingperiodic</code> を選べます。レジスト膜厚の周期成分と、膜厚の直線的な変化（バルク効果を想定）を組み合わせた専用カーネルです。周期は入力しません。右の <span class="ui-name">周期の探索範囲</span> の中から、GPR の当てはまり（周辺尤度）が最も大きい周期を内部で選びます。</p>
<ol><li>露光波長（初期値 248 nm）とレジスト屈折率（初期値 1.77）を確認します。基準周期は「波長 ÷ 屈折率」で、初期値では約 140.11 nm です。</li><li>探索範囲は基準周期の 75〜125% です。<span class="ui-name">探索範囲を自分で指定する</span> にチェックを入れると、下限と上限を入力できます。</li><li>実行後、④の <span class="ui-name">周期の最適化</span> の表と「周期探索（周辺尤度）」のグラフで、候補ごとの値と採用した周期を確認します。</li></ol>
<p>候補の周期ごとに GPR を学習し直すため（最大48回）、通常の学習より時間がかかります。交差検証では各分割の学習データだけで周期を探索し直します。周期はモデルの中に保持し、MAT には従来どおり <code>Train_Model</code> だけを保存します。大域的に最良の周期である保証はありません。</p>
${shot('56-conditions-swing','Swing Curve：swingperiodic を選び、周期の探索範囲を同じ画面で指定する')}
${shot('60-period-search','周期探索：候補ごとの周辺尤度と、採用した周期をグラフで確認する')}
`);

add('prediction','保存モデルで推定・評価する','USER · PREDICTION',`
<p class="section-intro">「5 保存モデルで推定」は、左の①〜④を上から進めると、右に結果を表示します。</p>
${step('9-1','① モデルを選ぶ',`<p><span class="ui-name">学習済みMATを開く</span> で MAT を読み込みます。<span class="ui-name">使用するモデル</span> では、読み込んだ MAT のほか、この起動中に学習したモデル（保存していないものを含む）も選べます。選ぶと、説明変数の名前と順序を表示します。信頼できる作成元の MAT だけを開いてください。</p>`)}
${step('9-2','② データを開き、③ 列を割り当てる',`<ol><li>推定したいデータを開きます（操作は7章と同じ）。</li><li><span class="ui-name">処理の種類</span> を選びます。通常は「汎用推定」です。既存の面内モデル（X・Y・半径の3変数）を使うときだけ「面内推定」を選び、X・Y 座標の2列を割り当てます。</li><li>モデルの説明変数ごとに、入力ファイルの列をドロップダウンで選びます。列名が同じ場合は自動で選びます。</li><li>誤差も見たいときは <span class="ui-name">評価用の実測列（任意）</span> を選びます。</li></ol>`)}
${step('9-3','④ 確認して実行する',`<p><span class="ui-name">列の割当を確認</span> を押してから <span class="ui-name">④ 推定を実行</span> を押します。</p>`,'「推定結果」の表に SourceRow と y_pred が表示されること。実測列を選んだ場合は Actual・Residual と、評価指標・列の要約・実測値と予測値のグラフも表示します。')}
${shot('61-predict','保存モデルで推定：左で ①モデル ②データ ③列の割当 ④実行、右に結果')}
<p>実測列を選ばない場合、RMSE・R² は計算しません。面内推定で学習範囲の外の座標が含まれると、警告と <code>OutsideTrainingRange</code> の列で知らせます。評価に使うデータがモデルの学習に使っていないものかどうかは、利用者が確認してください。</p>
`);

add('shap','SHAP解析とアプリ内のグラフ','USER · SHAP',`
<h3 id="save-free-shap">10-A　学習時のSHAP（MATを保存しなくても計算できます）</h3><p>学習画面の③で <span class="ui-name">SHAPも計算する</span> にチェックがあると、各モデルの学習後に先頭最大1000行で SHAP を計算します（評価指標は全行）。背景データは原仕様どおりモデル内の学習データです。計算を省いた場合や失敗した場合は、④で対象の行を選び <span class="ui-name">選択モデルのSHAPを計算</span> を押すと、その1モデルだけ計算します。MAT を保存する必要はありません。SHAP はモデルの予測への寄与を示す値で、因果関係を証明するものではありません。</p>
<h3>10-B　別のデータでSHAPを確認する（6 SHAP 解析）</h3><ol><li>「6 SHAP 解析」を開き、①でモデルを選びます。MAT を開くほか、起動中に学習したモデルも保存せずに選べます。</li><li>②でデータを開き、③で「SHAP依存確認」を選んで、説明変数ごとに列を割り当てます。</li><li>必要なら評価用の実測列を選び、<span class="ui-name">列の割当を確認</span> → <span class="ui-name">④ SHAPを計算</span> を押します。</li></ol><p>結果の「SHAP値」の表に行ごとの値を、「グラフ」に SHAP 分布と、説明変数ごとの依存図を表示します。分布は shapley の計算結果を標準の swarmchart で描きます。行数が多いと時間がかかります。</p>
${shot('62-shap-page','SHAP 解析：起動中に学習したモデルを選び、別のデータで SHAP を確認する','R2022b のため SHAP は代替計算で描いた参考画面です。')}
<h3>10-C　ノイズ除去用SHAP</h3><p>③の処理の種類を「ノイズ除去用SHAP」にすると、Swing Curve モデル（最後の説明変数が RESIST_TH）について、膜厚の SHAP 値だけを <code>shap_resist</code> として出力します。膜厚1列だけのモデルにも対応します。</p>
<h3>10-D　Pro版：Swing Curve近似・極値膜厚・山間／谷間の傾き</h3><p>このカーブ評価と近似残差診断はPro版限定です。通常版はSHAP分布・依存図まで利用できます。APC学習画面にはPro版でもSwing Curve評価を表示しません。</p>
${shot('70-expanded-pro-fit','Pro版：学習画面の④で「グラフを大きく表示」を押し、RESIST_TH のカーブ評価を広く表示する','R2022b / macOS・Pro版の表示で、合成サンプルを実際に学習して撮影。SHAP は代替計算のため、近似の数値は説明用です。')}
<p>レジスト膜厚のSHAP依存図を、<code>c + m(t−t₀) + A sin(2π(t−t₀)/T + φ)</code> で近似します。tは膜厚、Tは周期、Aは片振幅、mは直線トレンドです。表示するR²・RMSEは<strong>SHAP散布点への近似</strong>の評価であり、画面上部のGPRモデルの評価とは別です。</p>
<ol><li>新規学習から進める場合は「2 Swing Curve学習」で下地モード・目的変数・説明変数を指定し、モデリング・SHAP評価を実行します。「④ 結果を比べて保存」の一覧で対象の行をクリックします。MAT保存は不要です。SHAPは先頭最大1000件で、GPR評価は全行です。</li><li>保存済みモデルなら「6 SHAP 解析」でMATと入力を開き、「SHAP依存確認」または「ノイズ除去用SHAP」を実行します。グラフ表示をオンにします。</li><li>結果の「グラフ」→「SHAP 依存: RESIST_TH」を開きます。学習画面では「グラフを大きく表示」を押すと広く表示できます。RESIST_THという説明変数名を持つモデルが対象です。</li><li>「膜厚下限・上限」で近似・プロットする範囲を指定します。読込データ内の範囲を指定し、異なる膜厚を8点以上含めます。</li><li>周期下限・上限を両方0にすると露光波長÷屈折率の75〜125%を探索します。初期値は248nm÷1.77です。周期が既知なら両方に正の値を入力して探索を絞ります。</li><li>バルク効果の傾きを見る場合は「直線トレンドを含む」をオンにし、「近似を更新」を押します。設定変更時は古い近似・表を消します。</li></ol>
<p>近似曲線はオレンジ、極大は紫、極小は青緑で表示します。極値の膜厚を点の近くへ表示し、同じ色の破線で隣接する山同士・谷同士を結びます。凡例のmが傾きです。表示範囲内の極値が24個を超える場合は文字の重なりを避け、膜厚の数値は表で確認します。</p>
${shot('22-swing-fit','SHAP Swing Curve近似：周期・振幅・適合度、山・谷を結ぶ傾きを表示','R2022b / 合成SHAP値の補助確認。入力は膜厚850〜1250、周期80、片振幅2.5、直線傾き0.01。GP学習・実SHAP計算の結果ではありません。作り直す前の画面で撮影した画像です。カーブ評価の表示内容は現在も同じですが、周囲の画面配置は現在の版と異なります。')}
<p>「近似方式」をスプライン補間に切り替えると、同じ膜厚のSHAP値を平均して通るnot-a-knotの3次補間になります。異なる膜厚は4点以上必要です。周期・一定振幅・一定傾きは定義せず、極値は補間曲線の微分から求め、山間・谷間の傾きは区間ごとに表示します。表示範囲は採用した補間点の端へ合わせ、外挿しません。近似残差は元の各観測行で計算します。補間点では残差がほぼ0となり、正規性検定は判定対象外になることがあります。膜厚の目盛・注記は指数表示を使いません。</p>
${shot('36-pro-spline','Pro版：近似方式をスプライン補間へ切り替え、極値と区間ごとの傾きを確認','表示専用コピーに合成SHAP波形を設定した補助確認です。GP学習・実SHAP計算はしていません。膜厚範囲の入力欄と極値注記は通常の小数表記です。グラフ全体と下の表は、この依存図の内側を下へスクロールして確認します。作り直す前の画面で撮影した画像です。カーブ評価の表示内容は現在も同じですが、周囲の画面配置は現在の版と異なります。')}
<p>内容が収まらない場合は、この依存図の内側を下へスクロールします。下の表は「近似指標」「極値の膜厚」「隣接する山・谷の傾き」を切り替えます。「極値の膜厚」は極大・極小ごとの膜厚とSHAP値、「隣接する山・谷の傾き」は両端の膜厚・SHAP値と差分の傾きです。目的の表を選び、結果の右下の「表を保存（CSV / Excel）」で出力します。グラフのPNGには近似曲線・極値・破線・凡例を含めます。</p>
${shot('23-swing-extrema','プロット範囲内の極大・極小となる膜厚を表でも確認','同じ合成データを用いた補助確認。極値は直線トレンドも含めた近似式全体の微分から算出しています。作り直す前の画面で撮影した画像です。カーブ評価の表示内容は現在も同じですが、周囲の画面配置は現在の版と異なります。')}
${note('傾きと極値の読み方','三角関数近似は一定振幅の正弦波＋直線モデルなので、隣接する山間・谷間の傾きは同じ一定値mになります。スプライン補間では形状に応じて区間ごとの傾きが異なります。傾きはSHAP値の差÷膜厚の差で、単位は入力のままです。SHAP値や傾きだけで物理的なバルク効果を証明することはできません。')}
<p>膜厚範囲を変更すると、その範囲の点だけで近似し直します。ズームだけでは近似対象・表を変更しないため、対象を変えるときは膜厚欄を変更して更新してください。曲線が単調で極値を持たない場合は極値なし、同種の極値が2個なければ隣接傾きなしと表示します。定数・直線だけのデータでは周期を表示しません。近似が弱い場合や周期が探索範囲の端にある場合は、説明文を確認して範囲を見直します。</p>

<h3 id="swing-residuals">10-E　Pro版：近似残差の正規性・歪度・尖度を確認する</h3>
<p>ここでの残差は<strong>SHAP値−Swing Curve近似値</strong>です。GPRのモデル評価にある実測値−予測値の残差とは別です。近似に使った膜厚範囲の全観測行を使い、同じ膜厚の繰返しも各1行として診断します。</p>
<ol><li>10-Dの手順で「近似を更新」します。</li><li>近似カーブの横の「残差分布」を選びます。ヒストグラムと、残差の平均・標準偏差から描いた正規分布の曲線を比較します。縦軸は件数ではなく確率密度です。</li><li>図の上にあるLilliefors検定の判定、p値、有意水準α=0.05、歪度・尖度・超過尖度を確認します。</li><li>「正規Q–Q」へ切り替え、点が斜めの基準線から曲がっていないか、両端が大きくずれていないか確認します。</li><li>「残差対膜厚」で、0の線を中心に残差が散らばるか、周期性や膜厚によるばらつきの変化が残っていないか確認します。</li><li>依存図の内側を下へスクロールし、「残差の正規性」または「残差データ」を選んで「表を保存（CSV / Excel）」を押します。CSV / Excelへ出力できます。各図は「グラフをPNG保存」の一覧から選びます。</li></ol>
${shot('24-swing-residual-histogram','近似残差のヒストグラム・正規密度と、正規性検定・歪度・尖度','R2022bの補助確認。周期80の合成SHAP波形へ標準偏差0.15の正規乱数ノイズを加えて再近似した例です。実SHAP計算やR2025bの実行結果ではありません。作り直す前の画面で撮影した画像です。カーブ評価の表示内容は現在も同じですが、周囲の画面配置は現在の版と異なります。')}
${table(['表示','読み方'],[['Lilliefors / α=0.05','平均・標準偏差が未知の正規分布への適合を検定します。検定統計量と臨界値は下の「残差の正規性」表にも記録します。'],['正規性を棄却（参考）','正規分布という仮説と合いにくい結果です。Q–Qや残差対膜厚も確認し、外れ値・残った周期性などを調べます。'],['正規性を棄却できず（参考）','今回の標本では棄却できません。正規分布だと証明された意味ではありません。'],['p &lt;= 0.001 / p &gt;= 0.5','MATLABの計算表の範囲外を含む境界表示です。0.001や0.5ちょうどのp値とは扱いません。'],['歪度 / 尖度 / 超過尖度','偏り補正付き。正規分布の基準は歪度0・尖度3・超過尖度0です。尖度は裾や外れ値の影響を反映します。値だけで正規性を決めません。'],['判定対象外 / NaN','残差のばらつきが数値判定しきい値以下です。数値誤差だけの残差から分布を判断せず、検定・歪度・尖度・Q–Qを対象外にします。理由としきい値は表に残ります。']])}
${shot('25-swing-residual-qq','正規Q–Q：標準化残差と標準正規分布の分位点を比較','同じノイズ付き合成波形の近似残差。基準線はy=xです。点の整列だけでは残差の独立性は確認できません。作り直す前の画面で撮影した画像です。カーブ評価の表示内容は現在も同じですが、周囲の画面配置は現在の版と異なります。')}
${shot('26-swing-residual-thickness','残差対膜厚：周期性や膜厚によるばらつきの偏りを確認','下へスクロールすると残差データの表があります。InputRowはSHAP計算へ渡した入力内の1始まりの行番号で、元ファイルのヘッダーを含む物理行番号ではありません。作り直す前の画面で撮影した画像です。カーブ評価の表示内容は現在も同じですが、周囲の画面配置は現在の版と異なります。')}
${note('検定結果の適用範囲','曲線の係数・周期を同じ点から推定しているため、残差は独立な標本とは限りません。検定p値は再近似による補正をしていない参考診断です。少数標本では非正規性を検出しにくく、多数の点では小さなずれでも棄却される場合があります。正規性・独立性・等分散性・曲線の妥当性はそれぞれ確認してください。')}
`);

add('statistics','評価の読み方・炉内補間・実験計画・設定・Help','USER · INTEGRATED FEATURES',`
<h3>11-A　評価指標の読み方</h3>
${table(['指標','意味'],[
['RMSE / MAE','誤差の二乗平均平方根 / 絶対誤差の平均。実測値と同じ単位で、小さいほど一致します。'],
['決定係数 R²','1 − Σ(実測−予測)² / Σ(実測−実測平均)²。1 が完全一致で、負の値にもなります。'],
['RMSPE','相対誤差の二乗平均平方根（%）。実測に0があると計算できません。'],
['Pearson r / 相関係数の2乗','直線的な関係の強さ。予測の偏りは検出できないため、決定係数 R² とは別の指標です。'],
['KLダイバージェンス / 相互情報量','分布の違い / 依存の強さ。ヒストグラムのビン数で値が変わります。ビン数は「9 設定」で指定します。']])}
<p>計算できない指標は NaN と理由を表示します。「評価データ」が「学習データ」のときは学習に使ったデータでの当てはまりで、未知のデータでの精度ではありません。交差検証、または「5 保存モデルで推定」で学習に使っていない実測と比べて確認してください。</p>
<h3>通常版とPro版</h3><p>通常版は、学習、周期カーネル、SHAP 分布・依存図、炉内補間、実験計画、評価・書出しを利用できます。レジスト膜厚の SHAP への近似（三角関数・スプライン）、極値、山間／谷間の傾き、近似残差の診断は Pro 版だけの機能です。版はビルド時に決まり、起動後に切り替えることはできません。</p>
<h3 id="furnace-interpolation">11-B　LP-CVDの炉内補間：バッチ別にBoatSlotから予測する</h3>
<p>「4 炉内補間」は、一部の BoatSlot だけにある計測値（膜厚・屈折率など）から、ほかの BoatSlot の値を補間します。学習画面と同じ4ステップです。</p>
<ol><li><strong>① データを開く</strong>：WaferId・BoatSlot・計測値の列を持つファイルを開きます。異なる成膜 Run をまとめたファイルは、Run を区別するバッチ列を含めます。</li><li><strong>② 列を選ぶ</strong>：WaferId・BoatSlot・バッチの列と、目的変数（複数可）を選び、<span class="ui-name">列・バッチ区分を確認</span> を押します。列名が WaferId・BoatSlot・Batch・膜厚・屈折率などのときは自動で選びます。</li><li><strong>③ 条件を決めて実行</strong>：比べる方式と、予測する Slot の範囲・間隔を決めて実行します。計測範囲の外側は、チェックを入れたときだけ予測します（外挿）。</li><li><strong>④ 結果を比べて保存</strong>：<span class="ui-name">表示するモデル</span> で Run・目的変数・方式を切り替え、曲線・検証の RMSE・残差を比べます。<span class="ui-name">選択モデルをMAT保存</span> で1モデルを保存できます。</li></ol>
${shot('63-furnace-columns','炉内補間 ②：WaferId・BoatSlot・バッチの列と目的変数を確認する')}
${shot('73-furnace-conditions','炉内補間 ③：比べる方式と、予測する Slot の範囲を決める')}
${shot('64-furnace-results','炉内補間 ④：Run・目的変数・方式を切り替えて補間曲線を比べる（太線が選択中の方式）')}
${table(['方式','内容'],[
['スプライン（3次）','計測点を必ず通る3次補間（not-a-knot）。'],
['3次多項式近似','全計測点を1本の3次式へ最小二乗で当てはめます。計測点を必ず通るとは限りません。'],
['RBF（Gaussian＋直線）','ガウス基底と直線の組合せ。幅と正則化は「9 設定」で指定します（幅 0 は自動）。'],
['GPR（3種類のカーネル）','squaredexponential・matern52・rationalquadratic。GPR だけ、応答の95%予測区間を帯で表示します。']])}
<p>同時に処理した複数 Lot は同じ Run のプロファイルとして扱い、バッチの値が異なる行は別々に補間します。計測値の空欄は項目ごとの「未計測」として扱い、各バッチ・各項目で5点以上の計測 Slot が必要です。検証は、両端の計測 Slot を残して内部の Slot を1点ずつ外す方法で行い、順位はバッチ・目的変数ごとに付けます。入力にない Slot の WaferId は空欄になります。</p>
<p>保存した MAT は専用の <code>Furnace_Model</code> 形式で、制御用の <code>Train_Model</code> とは別です。MATLAB から再利用する場合は次のようにします。</p>
${code('MATLAB コマンドウィンドウ（炉内補間モデルの再利用）',`setup_paths;
bundle = load_furnace_model('FurnaceInterpolation_Model_xxx.mat');
slots = (10:5:150)';   % 学習した範囲内の BoatSlot
[prediction, deviation, interval] = predict_furnace_model(bundle.Model, slots);`)}
${note('検証の限界','内部 Slot の検証は、端部や外挿の精度を評価しません。方式の選択にも使った検証値は独立な評価ではないため、採用前に別の実測でも確認してください。','warning')}
<h3>11-C　実験計画作成</h3><ol><li>「7 実験計画作成」の①で方式（D最適・I最適・直交表・拡張）、評価するモデル、因子数、水準数（2〜5）、実験数を決めます。直交表は必要な実験数を自動で決めます。</li><li>既存の実験に追加する場合は「拡張」を選び、②で既存の計画（−1〜1に符号化した値）のファイルを開いて、因子ごとに列を選びます。</li><li><span class="ui-name">実験計画を作成</span> を押します。右に計画の表と、交絡の確認結果を表示します。</li></ol>
${shot('65-doe','実験計画：左で条件を決め、右で計画と交絡（項どうしの重なり）を確認する')}
${note('最適計画の限界','値は −1〜1 の符号化値です。D最適・I最適は局所探索のため、最良の計画である保証はありません。図の対角線以外が1に近い項どうしは、効果を区別できません。乱数seedは「9 設定」で指定し、同じseedなら同じ計画を再現できます。')}
<h3>11-D　ワードクラウド</h3><p>「8 ワードクラウド」で文章を入力するか <code>.txt</code> を開き、<span class="ui-name">ワードクラウドを作成</span> を押します。日本語は自動で単語に分けないため、単語の間を空白で区切ってください。1文字の単語は除きます。</p>
${shot('66-wordcloud','ワードクラウド：図と単語の出現数を表示する')}
<h3>11-E　設定とHelp</h3><p>「9 設定」で、保存先、テーマ、カーネルの初期値、<strong>Fit method（すべての GPR に共通）</strong>、<strong>KL / MI ビン数</strong>、実験計画の因子数・実験数・<strong>seed</strong>、炉内補間の <strong>RBF 幅・正則化</strong> を変更し、<span class="ui-name">設定を保存して適用</span> を押します。太字の項目はこの画面だけで変更します。変更は次の実行から反映し、表示中の結果や学習済みモデルの一覧は消えません。</p>
${shot('67-settings','設定：項目を目的別にまとめ、保存ボタンは常に見える位置に置く')}
${shot('69-dark-theme','ダークテーマの表示（学習結果を表示したまま切り替えできる）')}
<p>「10 Help」には、用語の説明、操作のまとめ、MathWorks 公式の関数ヘルプ、この手順書への入口があります。ウィンドウの大きさは自由に変えられ、最大化もできます。</p>
${shot('68-help','Help：用語の説明と、公式の関数ヘルプへの入口')}
`);

add('export','結果・グラフ・ログを保存する','USER · OUTPUTS',`
${step('12-1','表を CSV / Excel に保存する',`<p>保存したい表のタブを開き、結果の右下の <span class="ui-name">表を保存（CSV / Excel）</span> を押します。学習画面のモデルの一覧は <span class="ui-name">一覧を保存</span> で保存できます。</p>`)}
${step('12-2','グラフを PNG に保存する',`<p><span class="ui-name">グラフをPNG保存</span> を押します。表示中のグラフがあればそれを、なければ一覧から選んで保存します（150dpi）。</p>`)}
${step('12-3','グラフをクリップボードへコピーする',`<p><span class="ui-name">グラフをコピー</span> を押すと、グラフを画像としてクリップボードへ入れます。Excel や PowerPoint へそのまま貼り付けできます。</p>`)}
${step('12-4','学習ログを確認する',`<p>ログは作成・利用した環境の <code>prefdir</code> の下、<code>StandaloneAnalysisApp/logs/training.jsonl</code> に追記します。日時、機能、入力ファイル名、行数、kernel、fit_method、保存先、検証結果、説明変数名、処理時間を記録します。<strong>測定値そのものは記録しません。</strong></p>${code('MATLAB コマンドウィンドウ（ログの場所）',`fullfile(prefdir, 'StandaloneAnalysisApp', 'logs', 'training.jsonl')`)}`)}
`);

add('verification','完了確認','CHECK BEFORE HANDOVER',`
<p>チェック欄はこのページを見ている間の確認用です。ページを再読込するとリセットされます。正式な確認結果はプロジェクトの <code>verification.md</code> 等へ記録してください。</p>
<div class="checklist-grid"><article><h3>作成・配布担当者</h3>${[
'Windows 64bit / MATLAB R2025b と必要製品を確認した。',
'ソースから起動し、run_app_flow_check の14項目がすべて成功した。',
'R2025b で全テスト成功、失敗・未完了0件を確認した。',
'旧・新モデルの列順・設定・予測差を比較した。',
'Windows ビルド出力を確認し、付随ファイルも配布した。',
'MATLAB 本体のない Runtime R2025b 端末で全機能を確認した。',
'SHAP / ワードクラウドのグラフ、PNG保存、クリップボードからの画像貼付けを確認した。',
'「9 設定」のKL / MIビン数が全画面の評価に反映することを確認した。',
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
['目的変数や説明変数を選ぶ場所が分からない','学習画面の上のタブ「② 変数を選ぶ」を開きます。左が目的変数、右が説明変数です。先に「① データを開く」でファイルを開くと選べるようになります。'],
['MATLAB Compiler / Statistics Toolbox が見つからない','作成用 MATLAB の <code>ver</code> で製品のインストールを確認し、利用可能なライセンスも担当者に確認します。Runtime はビルド用 MATLAB の代わりにはなりません。'],
['列対応が未確認、または必須列が不足と表示される','入力列の未選択・重複を見直し、必要な列をすべて割り当てます。その後「列対応を確認」（推定・SHAP では「列の割当を確認」）を押します。入力やモデルを変えた後は再確認が必要です。'],
['ヘッダーが空 / 重複、または列名が合わない','元ファイルの指定ヘッダー行を確認します。説明文の行や空行をヘッダーとして指定していないか確認し、列名を一意にします。大小文字や余分な空白も確認します。'],
['欠損値を含む行番号が表示される','表示された元ファイルの行を確認します。アプリはその行を削除して学習を継続しません。勝手な0埋めや平均値補完をせず、入力の扱いを確認して修正したファイルを再読込します。'],
['データが少ないため処理を中止します','APC は25行未満で停止します。25行以上の有効データを用意します。25〜149行では注意警告が残ります。Swing Curveに APC の件数ルールを当てはめないでください。'],
['SHAPが出ない','④の一覧の「SHAP」と「備考」を確認します。「未計算」「失敗」の行は、選んでから「選択モデルのSHAPを計算」を押します。MAT保存はSHAPの前提ではありません。'],
['このモデルを制御に使用しないでください、と表示される','その MAT を制御へ渡さず、「保存後検証」タブの表の失敗行を確認します。元のモデルとファイルを保持し、モデルを作成した環境・設定とともに担当者へ確認します。'],
['学習済みモデル（Train_Model）が見つかりません','別用途の MAT、または変数名が異なるファイルです。このアプリの仕様で作成されたモデルを選びます。別名の変数をアプリ側で勝手に読み替えません。'],
['SHAP の処理が長い / 算出に失敗する','処理中表示と、停止時の詳細メッセージを確認します。モデルの説明変数順・入力形式・R2025b / Statistics Toolbox を確認します。計算時間の保証値はありません。測定値や機密データを外部サービスへ渡して対処しないでください。'],
['相関や r² が NaN になる','2点未満、または片方の列がすべて同じ値など、相関を定義できない条件を確認します。NaN を良好なモデルの意味で扱わないでください。'],
['RMSEやR²が表示されない','推定・SHAPでは評価用の実測列を選択してください。2件未満、実測が一定、実測0などで未定義になる指標はNaNと理由を表示します。'],
['画面が狭くて見づらい','ウィンドウを広げるか最大化します。学習画面の④では「グラフを大きく表示」で一覧をたたみ、グラフを広く表示できます。'],
['結果やログの保存に失敗する','保存先フォルダの書込み権限、ファイルが Excel 等で開かれていないか、空き容量を確認します。別の書込み可能なフォルダへ保存する場合も、社内の管理場所のルールに従います。'],
['exe が起動しない / DLL が見つからない','ビルドと同じ R2025b の Runtime、OS・64bit、対応する更新版を確認します。exe だけをコピーしていないか、付随ファイルと出力 readme も確認します。'],
['手順書の画像が見えない','docs/user-guide フォルダ全体を移しているか確認します。images / base.css / procedure-guide.css / procedure-guide.js / guide-extra.css / guide-extra.js を HTML と同じ相対位置に置きます。']
].map(([q,a])=>`<details><summary>${q}</summary><div><p>${a}</p></div></details>`).join('')}</div>
<p>解決しない場合は、<strong>実行日時、利用したタブ、MATLAB / Runtime のリリース・更新版、表示されたエラー文、保存後検証の失敗項目</strong>を担当者へ伝えてください。エラーのスクリーンショットへ測定値や機密のファイル名が写る場合は、送付先と範囲を確認してください。</p>
`);

add('references','参考資料と、この資料の確認範囲','SOURCES AND SCOPE',`
<h3>機能評価用サンプル</h3><p><a href="../../samples/ProcessInsight_Samples.xlsx">サンプルExcel（9シート）</a>と<a href="../../samples/README.md">列指定・使い方</a>を同梱しています。APC、Swing Curve両モード、汎用回帰のGPR・重回帰・PLS、推定・SHAP、2Runの炉内補間、拡張計画、ワードクラウドを試せます。全データは合成で、各データシートのヘッダー行は1です。予測・SHAP用MATはアプリでモデルを作成してから保存します。</p><h3>プロジェクト内の正本</h3><ul class="source-list"><li><a href="../../README.md">README.md</a><small>構成、入力と保存仕様、起動方法。</small></li><li><a href="../windows-build.md">Windows ビルド手順（Markdown）</a></li><li><a href="../specification.md">原仕様</a><small>MR-01〜MR-09、T-01〜T-10、Q-01〜Q-11 の正本。</small></li><li><a href="../../verification.md">検証記録</a> / <a href="../../issues.md">残課題</a></li></ul>
<h3>MathWorks 公式資料</h3><ul class="source-list"><li><a href="https://www.mathworks.com/help/matlab/creating_guis/app-designer-startup-function.html">startupFcn の追加と起動時の処理</a><small>アプリノードの Callbacks メニュー、StartupFcn コールバック。</small></li><li><a href="https://www.mathworks.com/help/matlab/creating_guis/app-designer-code-generation.html">App Designer Code View のコード管理</a><small>プロパティ・コールバックの追加。最新ページには R2026b の新仕様もあるため、R2025b の .mlapp 手順を使用。</small></li><li><a href="https://www.mathworks.com/help/compiler/compiler.build.standalonewindowsapplication.html">compiler.build.standaloneWindowsApplication</a><small>Windows でのビルド、出力ファイル、Runtime を含まないこと。</small></li><li><a href="https://www.mathworks.com/help/compiler/standalone-application-target.html">スタンドアローンアプリの配布</a><small>ビルドと配布先の OS、配布するファイル。</small></li><li><a href="https://www.mathworks.com/products/compiler/matlab-runtime.html">MATLAB Runtime の入手</a></li><li><a href="https://www.mathworks.com/help/matlab/ref/exportapp.html">exportapp</a><small>参考 UI 画像の書出しに使用。</small></li></ul>
<h3>画像と文書の確認範囲</h3><p>アプリ画面は、R2022b / macOS で開発用の例外（環境変数 <code>PROCESS_INSIGHT_DEV_RELEASE=allow</code> を指定した MATLAB 上だけで有効。配布版では使えません）により起動し、同梱の合成サンプルを実際に学習して撮影しました（<code>docs/user-guide/_src/capture_app_screens.m</code>）。GPR の学習・MAT 保存・保存後検証は実際に実行しています。SHAP の計算だけは R2025b 専用のため、代替計算で描いています。10章の Pro 版カーブ評価の画像6枚は、作り直す前の画面で合成 SHAP 値を使って撮影したものです。</p><p>参考プレビューと R2025b 製品アプリの実行確認は別です。R2025b のビルド成功、Runtime 上の実行、モデル互換性は未確認です。手順書のブラウザ確認結果は同梱の <a href="guide-verification.md">guide-verification.md</a> に記録します。</p>
<p class="privacy-note">この資料の更新日：2026-11-16（JST）。画像・フォント・ライブラリを外部から読み込まない構成です。公式サイトへのリンクを開くときはネット接続を使用します。</p>
`);

const nav = `<aside id="sidebar" class="sidebar" aria-label="目次"><div class="sidebar-header"><p class="eyebrow">PROCESS INSIGHT TOOL</p><p class="sidebar-title">ビルド・利用手順書</p><p class="sidebar-subtitle">Windows 64bit · R2025b</p></div><nav><ol class="toc-list">${sections.map((s,i)=>`${[0,3,6,12].includes(i)?`<li class="toc-group">${i===0?'はじめに':i===3?'作成・配布担当者':i===6?'アプリ利用者':'確認と対処'}</li>`:''}<li><a href="#${s.id}">${i+1}. ${s.title}</a></li>`).join('')}</ol></nav><div class="sidebar-footer"><span class="status-dot" aria-hidden="true"></span>更新 2026-11-16 · PC閲覧用</div></aside>`;
const main = `<main id="main-content" class="main-content"><header class="hero"><div class="hero-content"><p class="eyebrow">BUILD &amp; OPERATING GUIDE</p><h1>Process Insight Tool<br><span>ビルド・利用手順書</span></h1><p class="hero-lead">ソースからの起動確認、Windows 配布、8機能と設定・Helpの操作、出力確認まで。</p><div class="hero-badges"><span>対象：Windows 64bit / R2025b</span><span>画像：R2022b の参考撮影</span><span>更新：2026-11-16</span></div></div></header><p class="guide-status"><strong>現在の到達点：</strong>画面を作り直したソースを作成済み。R2025b での通し確認と全テスト・Windows exe 生成・Runtime 動作確認は後工程です。この資料は、その作業を進めるための手順書です。</p>${sections.map((s,i)=>`<section id="${s.id}" class="content-section"><div class="section-heading"><span class="section-number">${String(i+1).padStart(2,'0')}</span><div><p class="section-kicker">${s.kicker}</p><h2>${s.title}</h2></div></div>${s.body}</section>`).join('\n')}<footer class="page-footer"><p>Process Insight Tool · ビルド・利用手順書</p><p>2026-11-16 · 画像は参考プレビュー / 対象環境での確認は未完了</p></footer></main>`;
let skeleton = `<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="Process Insight Toolの操作手順書"><title>Process Insight Toolの手順書</title>
<link rel="icon" href="data:,"><link rel="stylesheet" href="procedure-guide.css"><script src="procedure-guide.js" defer></script>
</head><body id="top"><a class="skip-link" href="#main-content">本文へ移動</a>
<button id="toc-toggle" class="toc-toggle" type="button" aria-controls="sidebar" aria-expanded="false"><span aria-hidden="true">☰</span> 目次</button>
<aside id="sidebar" class="sidebar"></aside><div id="sidebar-overlay" class="sidebar-overlay" aria-hidden="true"></div>
<main id="main-content" class="main-content"></main>
<button id="back-to-top" class="back-to-top" type="button" aria-label="ページ上部へ戻る"><span aria-hidden="true">↑</span> トップへ戻る</button>
</body></html>`;
skeleton = skeleton.replace(/<title>[\s\S]*?<\/title>/,'<title>Process Insight Tool｜ビルド・利用手順書</title>');
skeleton = skeleton.replace(/<meta name="description"[^>]*>/,'<meta name="description" content="Process Insight Tool（MATLAB R2025b）のWindowsビルド・配布・利用を、参考スクリーンショットとともに説明する手順書。">');
skeleton = skeleton.replace(/<aside id="sidebar"[\s\S]*?<\/aside>/,nav);
skeleton = skeleton.replace(/<main id="main-content"[\s\S]*?<\/main>/,main);
skeleton = skeleton.replace(/\s*<link rel="stylesheet" href="guide-extra.css">/g,'').replace(/\s*<script src="guide-extra.js" defer><\/script>/g,'');
skeleton = skeleton.replace('</head>','  <link rel="stylesheet" href="guide-extra.css">\n  <script src="guide-extra.js" defer></script>\n</head>');
skeleton = skeleton.replace(/\s*<dialog id="image-dialog"[\s\S]*?<\/dialog>/g,'');
skeleton = skeleton.replace('</body>','<dialog id="image-dialog" class="lightbox" aria-labelledby="dialog-caption"><div class="lightbox-bar"><p id="dialog-caption"></p><button id="dialog-close" class="lightbox-close" type="button">閉じる（Esc）</button></div><img id="dialog-image" alt=""></dialog>\n</body>');
fs.writeFileSync(pagePath,skeleton);
console.log(JSON.stringify({page:pagePath,sections:sections.length,figures:figureCount,codeBlocks:(skeleton.match(/class="code-block"/g)||[]).length,bytes:Buffer.byteLength(skeleton)}));
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const output = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const created = '2026-11-23';
const updated = '2026-11-25';
const author = '坂本';
const version = '1.1';
const escape = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const table = (head, rows) => `<div class="table-scroll"><table class="guide-table"><thead><tr>${head.map(x => `<th scope="col">${x}</th>`).join('')}</tr></thead><tbody>${rows.map(row => `<tr>${row.map(x => `<td>${x}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;
const ordered = items => `<ol>${items.map(x => `<li>${x}</li>`).join('')}</ol>`;
const notice = text => `<div class="document-note">${text}</div>`;
const code = text => `<pre><code>${escape(text)}</code></pre>`;
const pageLink = (file, title, fragment = '') => `<a href="${file}.html${fragment ? `#${fragment}` : ''}">${title}</a>`;
const shot = (name, title) => {
  const bytes = fs.readFileSync(path.join(output, 'images', `${name}.png`));
  return `<figure class="screenshot"><button type="button" class="image-open" aria-label="${title}を拡大"><img src="images/${name}.png" alt="${title}" width="${bytes.readUInt32BE(16)}" height="${bytes.readUInt32BE(20)}" loading="lazy"></button><figcaption><strong>${title}</strong><span class="shot-note">合成サンプルによるアプリ内部の操作参考画像です。OSのウィンドウ枠を含みません。Windows R2025bの実行証跡ではありません（SHAPは表示確認用の代替計算）。クリックで拡大できます。</span></figcaption></figure>`;
};
const section = (id, title, body) => ({ id, title, body });

// 要求・実装・テストを同じ台帳から出力する。
const requirements = [
 ["R-001", "ファイル入力", "CSV / Excelのシートとヘッダー行を指定し、先頭100行を表示する。空欄・重複ヘッダーを拒否し、元ファイル行番号を保持する。", "T-01"],
 ["R-002", "変数の指定", "目的変数1〜20列を独立したモデルで処理する。説明変数との重複・列の再使用・非数値・欠損・Infを理由と元行付きで拒否する。", "T-02"],
 ["R-003", "APC学習", "SIN_TH → SIN_RN → NSG_TH → RESIST_THの順でGPRを学習。25行未満は停止、25〜149行は注意とする。", "T-03"],
 ["R-004", "Swing Curve学習", "下地なしは膜厚だけ、下地ありは追加説明変数と最後にRESIST_THを使用する。膜厚・下地の入力列を変更できる。", "T-04"],
 ["R-005", "汎用回帰学習", "GPR・重回帰・PLS・ランダムフォレスト・バギング木を選択し、複数条件で比較する。PLS成分数・木の本数を指定できる。", "T-05"],
 ["R-006", "評価と比較", "学習データ評価を初期値とし、任意で共通分割の交差検証を行う。目的変数ごとに順位付けし、R²・RMSEを画面へ表示する。", "T-06"],
 ["R-007", "指標と要約", "8評価指標と列の要約を各評価で計算する。決定係数と相関係数の2乗を区別し、未定義値は理由を表示する。KL / MIビン数は設定だけで変更する。", "T-07"],
 ["R-008", "選択モデル保存", "学習・任意のSHAP評価・比較後に、選択した全行学習モデル1つだけを再学習せずMATへ保存し、保存前後を検証する。", "T-08"],
 ["R-009", "推定・SHAP", "保存MATと起動中のモデルを同じ画面で使用できる。実測列は任意。SHAPを省略・再計算でき、分布と依存図をアプリ内に表示する。", "T-09"],
 ["R-010", "結果出力", "元行・入力・実測・予測・残差・SHAPを1表でCSV / Excelへ保存する。グラフのPNG保存・クリップボードコピー、任意列での色指定を提供する。", "T-10"],
 ["R-011", "炉内補間", "WaferId・BoatSlot・複数目的変数・任意のバッチからRun別に分離し、スプライン・3次多項式・RBF・3種類のGPRを比較する。", "T-11"],
 ["R-012", "炉内検証・保存", "内部Slotの留め置き検証、目的変数ごとのRMSE棒グラフ、外挿の明示、選択したFurnace_Modelの保存・再読込みを提供する。", "T-12"],
 ["R-013", "実験計画", "D最適・I最適・同一水準の直交表（2〜5水準）、交絡、D/A/I/G/VIF等を表示する。初期実験数25、seedは設定だけで指定する。", "T-13"],
 ["R-014", "変数重要度", "Permutation ImportanceとPLSのVIPを結果へ表示し、SHAPとは別の指標として説明する。", "T-14"],
 ["R-015", "データの傾向", "学習前に選択列の単変量の傾向をグラフと要約で確認でき、数値列・カテゴリ列で色を指定できる。", "T-15"],
 ["R-016", "設定・Help", "保存先・テーマ・文字サイズ・GPR Fit method・ビン数・DOE seed・RBF幅と正則化を保存する。用語と公式関数ヘルプを表示する。", "T-16"],
 ["R-017", "操作と表示", "進捗・中止・エラーをアプリ内へ表示し、リサイズに対応する。学習履歴は設定変更後も保持する。", "T-17"],
 ["R-018", "Windows配布", "Windows 64bit / R2025bを対象に、ProcessInsightTool.exeとRuntime同梱インストーラーを作成する。", "T-18"],
 ["R-019", "データ管理・互換性", "処理はローカル。モデルの学習値を入力と同じ管理区分で扱う。GPRの保存契約と旧モデルの互換確認、許可項目だけの運用ログを維持する。", "T-19"],
];
const cases = [
 ['T-01','R-001','入力','ExcelとCSVを開き、シート・ヘッダーを変更する。空欄・重複ヘッダーも入力する。','先頭100行・正しい元行番号を表示し、不正ヘッダーを拒否する。'],
 ['T-02','R-002','入力','2目的変数を選び、説明変数の重複・目的変数との重なり・欠損・Inf・文字を与える。','目的変数ごとにモデルを作り、不正値は列・元行・理由を示して停止する。'],
 ['T-03','R-003','境界','APCを24・25・149・150行で実行し、列順を確認する。','24行で停止、25〜149行で注意、150行で行数注意なし。4列順を保持する。'],
 ['T-04','R-004','画面結合','Swing Curveの下地なし／ありを切り替え、膜厚・下地を別の列へ割り当てる。','下地なしは1入力、ありは選択した下地と最後のRESIST_TH。割当が学習へ反映する。'],
 ['T-05','R-005','単体・結合','GPR・重回帰・PLS・ランダムフォレスト・バギング木を比較し、ランク不足と過大PLS成分も与える。','成功モデルを比較でき、失敗条件には理由が残る。木の本数が学習へ反映する。'],
 ['T-06','R-006','検証','CVなし／5分割CV、1条件／複数条件、2目的変数で実行する。','Scopeを区別し、CVでは各検証行を学習へ含めない。目的変数ごとに順位を表示する。'],
 ['T-07','R-007','数値','完全一致・偏り・一定実測・実測0を含むデータで独立計算と照合する。','R²とr²を区別し、未定義はNaNと理由。設定のビン数を反映する。'],
 ['T-08','R-008','保存・互換','各方式を選択保存し、MAT変数・属性・予測を読み直す。保存もキャンセルする。','1モデルだけを再学習せず保存・検証する。キャンセルでも画面のモデルと結果が残る。'],
 ['T-09','R-009','実SHAP','Windows R2025bで保存MATと起動中モデルを推定し、実測あり／なし、SHAP省略／計算／再計算を行う。','実測なしで精度を捏造せず、標準swarmchartと各入力の依存図をアプリ内へ表示する。'],
 ['T-10','R-010','出力','CSV・Excel・PNG・コピー、色の変更、SHAPの未計算行を確認する。','元行の対応と評価値を維持し、未計算SHAPはNaN。画像・表が選択モデルと一致する。'],
 ['T-11','R-011','炉内','2Run・2目的変数・6方式で実行し、未計測・重複Slot・計測5点未満を入力する。','Runと目的変数を混ぜない。未計測は項目別に除外し、重複と5点未満は停止する。'],
 ['T-12','R-012','炉内保存','内部Slot検証、外挿オフ／オン、GPR区間、6方式のMAT往復を確認する。','端点を留め置かず、RMSE棒は目的変数別。範囲外を明示し、予測と区間が保存前後で一致する。'],
 ['T-13','R-013','実験計画','D/Iと2〜5水準の直交表を生成し、既知計画の効率・交絡・予測分散と照合する。','因子・行数・水準の制限を守り、ランク不足と未定義指標に理由を表示する。'],
 ['T-14','R-014','重要度','既知の効果のデータでPermutation ImportanceとPLS VIPを計算する。','効果の大きい列が高くなり、同じ条件で再現する。因果効果として説明しない。'],
 ['T-15','R-015','探索表示','単変量のグラフで量的／質的な横軸・色の列を選ぶ。','点数・カテゴリ・要約が入力に対応し、色の変更が学習や評価の値を変えない。'],
 ['T-16','R-016','設定','Fit method・ビン数・seed・RBF・文字サイズを変更して再起動。不正なJSONも入力する。','保存値を反映し、Fit method等は設定だけで編集。読込み失敗時は初期値と警告を表示する。'],
 ['T-17','R-017','操作','進捗・中止・エラー・リサイズ・設定後の履歴選択を確認する。','処理後にロック解除し再実行できる。結果とグラフをアプリ内で確認できる。'],
 ['T-18','R-018','Runtime受入','Windows R2025bでビルド後、MATLABなしのPCへRuntime同梱インストーラーをオフライン導入する。','起動、8メニュー、サンプル、実SHAP、保存・再読込み、終了・再起動に成功する。'],
 ['T-19','R-019','受入・互換','利用者の旧／新モデルを同じXcheckで比較し、ログとファイル管理を確認する。','属性・入力順・予測差の合意を得る。実データやログを外部へ自動送信しない。'],
];
const docs=[];
const add=(id,file,title,phase,purpose,sections)=>docs.push({id,file,title,phase,purpose,sections});
const reqTable=rows=>table(['要求ID','対象','現行要件','テスト仕様'],rows.map(r=>[`<span id="${r[0]}">${r[0]}</span>`,r[1],r[2],pageLink('test-plan',r[3],r[3])]));
const testTable=rows=>table(['テストID／要求','種別','手順','期待結果'],rows.map(t=>[`<span id="${t[0]}">${t[0]}</span><br>${t[1]}`,t[2],t[3],t[4]]));

add('PIT-00','index','文書管理台帳・開発計画書','全工程','成果物と責任、係長確認・課長承認の進め方を管理する。',[
 section('scope','目的と対象',`<p>Process Insight Toolの機能を、ウォーターフォール開発の成果物としてまとめた文書です。全9文書を文書版1.1へ更新しました。11月23日の新規作成履歴は残し、今回の変更を11月25日の改定として記録しています。</p>${notice('対象は本書に示す8メニューです。Windows R2025b／Runtimeでの受入は未完了です。')}<p>作成者は坂本、確認者は係長、承認者は課長です。アプリのテスト結果は実施済み・未実施を区別して記録します。</p>`),
 section('catalog','文書管理台帳','<div id="document-catalog"></div>'),
 section('gates','工程と完了条件',`<div class="phase-flow">${['要件定義','基本・詳細設計','実装','単体・結合テスト','総合・受入テスト','運用保守'].map((x,i)=>`<span><b>${i+1}</b>${x}</span>`).join('')}</div>${table(['工程','成果物','係長の確認','課長の承認条件'],[
 ['要件定義','PIT-01','利用目的・範囲・制約・保留要求','必須要求と受入方針を確定。'],['基本・詳細設計','PIT-02〜04','画面・計算・保存契約と要求の整合','設計と未決事項の扱いを承認。'],['実装・単体／結合テスト','ソース・PIT-05〜06','期待結果・実績・不具合と再テスト','次工程への進行を判断。'],['総合・受入テスト','PIT-05〜06','Windows／Runtime・実SHAP・旧モデル互換','証跡と未解消リスクから受入を判断。'],['運用保守','PIT-08と変更文書','障害・変更影響・回帰テスト','変更後の再受入を承認。']])}<p>納期・費用・作業時間は未合意のため新たに設定していません。既にある実装を文書化しており、計画した工程順序と過去の実施履歴を混同しません。</p>`),
 section('roles','役割と責任',table(['役割','責任'],[['作成者：坂本','要求・設計・コード・テストの整合、指摘対応、改定履歴の更新。'],['係長：確認者','技術・業務内容をレビューし、氏名・レビュー日・判定・コメントを記録。'],['課長：承認者','係長確認・未解決事項・受入と配布の可否を判断し記録。'],['利用者／配布担当','代表データによる受入、対象PCでの導入、ファイルと旧版の保管。実名は別途割当。']])),
 section('review-howto','確認・承認記録の保存方法',ordered(['共有用ZIPは新しいフォルダに展開し、index.htmlをPCのEdge / Chromeで開きます。左の文書一覧から対象を開き、文書番号・文書版を確認します。全9文書を個別に確認・承認します。','各文書の末尾の「確認・承認記録」で、係長の氏名・レビュー日・判定・コメント、続いて課長の記録を入力します。日付だけでは判定は変わりません。','「記入済みHTMLを保存」で保存します。保存ファイルは元HTMLと同じフォルダに置き、開き直して記録を確認します。入力は自動保存されません。','スタイル・JavaScript・imagesも一緒に保持します。「印刷／PDF保存」も使えます。記録欄は本人認証や電子署名を行う承認システムではありません。','改定履歴はHTML上で行を追加し、版・日付・区分・内容・作成者を編集できます。最終行の版・日付は文書情報へ反映されます。内容を変更したら係長確認・課長承認を取り直します。'])+notice('記入済みHTML・氏名・コメントは組織の管理先で保管してください。公開リポジトリへそのまま登録しません。')),
]);

add('PIT-01','requirements','要件定義書','要件定義','業務目的・対象機能・品質要求・受入条件を定める。',[
 section('purpose','目的と利用場面',`<p>成膜・露光プロセスの担当者が、CSV / Excelの計測値からモデルを比較し、未計測位置の予測、変数の影響の把握、実験計画を行うローカル解析アプリです。設備へ予測値を自動適用する制御接続は対象に含めません。</p>${table(['場面','成果'],[['露光APC','4変数から学習し、検証したGPRのMATを制御側の確認へ渡す。'],['Swing Curve','膜厚と下地の関係を学習して、予測・誤差・入力の寄与を確認。'],['LP-CVD','Runごとの計測Slotから膜厚・屈折率を補間。'],['解析・計画','共通分割比較、重要度、データの傾向、実験計画の評価を確認。']])}<p>既存の面内モデルの推定は互換用途で残します。面内モデルを新しく学習する画面はありません。</p>`),
 section('functional','機能要求',reqTable(requirements.slice(0,16))),
 section('quality','非機能・品質要求',reqTable(requirements.slice(16))+table(['品質','条件'],[['環境','Windows 64bit、MATLAB / Runtime R2025b。開発環境の補助確認を対象環境の受入へ読み替えない。'],['性能','保証値は未合意。入力件数・条件数・CV・SHAPの有無と実測時間を記録。'],['機密性','解析はローカル。MAT・実入力・ログ・記入済み承認記録を管理する。'],['再現性','比較の分割・DOEのseedと条件を記録。全GPR学習で常に同一結果を保証しない。'],['保守性','画面・計算・保存・テストを分離し、MAT契約と正本を照合。']])),
 section('limits','上限と保留事項',table(['項目','条件'],[['学習','目的変数最大20列、目的変数×条件は100組まで。自動SHAPは先頭最大1000行。'],['炉内','Run・項目あたり計測5〜300点。最大100バッチ・20目的変数・生成2000点、出力20万行・学習2万回。'],['実験計画','1〜8因子、2〜5水準、実験数1〜300。混合水準直交表は対象外。'],['対象外','クラウド保存、アカウント管理、設備への自動制御接続、解析結果の業務上の自動承認。'],['保留','旧制御側入力・精度閾値・処理時間目標・保存期間等は係長確認と課長承認で確定。']])),
 section('acceptance','受入条件',`<p>全要求にテストを対応付け、Windows R2025b / Runtimeと利用者の代表データで確認します。精度の合格値は目的変数・単位・範囲ごとに合意し、一律のRMSE閾値を作りません。${pageLink('test-results','テスト結果・品質評価書')}に証跡を記録し、係長確認と課長の承認を得て受入・配布を判断します。</p>`),
]);

add('PIT-02','basic-design','基本設計書','基本設計','画面、処理の分担、データの流れと外部境界を定める。',[
 section('architecture','構成と責務',`<div class="architecture"><div><b>利用者・入力</b><p>CSV / Excel / MAT</p></div><span>→</span><div><b>画面層 app/</b><p>入力・列割当・条件<br>比較・保存・表示</p></div><span>↔</span><div><b>計算層 core/</b><p>学習・検証・SHAP<br>補間・計画</p></div><span>→</span><div><b>成果物</b><p>MAT・表・画像<br>設定・ログ</p></div></div><p>AnalysisControllerが設定、ページ遅延生成、ダイアログ、計算サービス、起動中のモデルをまとめます。各機能はPageクラス、共通表示はAppPage、モデル共有はModelStoreが担当します。計算関数は画面から分離し、テストではサービスを置換できます。</p>`),
 section('screens','画面構成',table(['番号','メニュー','主なクラス'],[['1','APC 学習','ModelingPage'],['2','Swing Curve学習','ModelingPage'],['3','汎用回帰学習','ModelingPage'],['4','炉内補間','FurnacePage'],['5','保存モデルで推定・SHAP','ModelUsePage'],['6','実験計画作成','DesignPage'],['7','設定','SettingsPage'],['8','Help','HelpPage']])+`<p>ホームは番号なしです。左のメニューで機能を選び、学習画面は上の①〜④へ進みます。</p>${shot('51-data-step','画面構成：左の機能選択と上の4ステップ')}<p class="screen-focus">操作位置：左のメニュー → 上の①〜④ → 中央の入力・結果。下段に処理状況を表示します。</p>`),
 section('flow','学習と保存の処理順',`<div class="phase-flow">${['①データを開く','②変数を選ぶ','③条件を決めて実行','④結果を比べて保存'].map(x=>`<span>${x}</span>`).join('')}</div><p>実行時に入力を検証し、不正なら②へ戻して理由を表示します。目的変数ごとに独立したモデルを作ります。CVなしを初期値とし、利用者が選んだときに未学習行を予測する共通分割の検証を行います。SHAPは省略・後計算が可能。保存は選択した全行学習モデルだけを対象とし、再学習しません。</p>`),
 section('components','部品間の境界',table(['部品','責務','境界'],[['DataSourceControl / ColumnMapper','ファイル、シート、ヘッダー、列の順序と選択','数値検証は実行前にcoreへ。'],['ModelingPage / ResultPanel','条件・進捗・順位・評価・選択保存','計算はevaluate_modeling_batch、共有はModelStore。'],['DataExplorer / EvaluationScatterView','傾向と予実・残差の表示','色の変更はモデルや精度を変えない。'],['FurnacePage','Run別・目的変数別の補間と保存','専用Furnace_Modelを使用。'],['ModelUsePage','保存／起動中モデルの推定とSHAP','PredictorNamesと入力順を維持。'],['SettingsPage / HelpPage','設定と用語・手順','Fit method・ビン数・seed・RBFは設定で編集。']])),
 section('environment','環境と外部境界',`<p>製品はWindows 64bit / R2025bを対象とします。解析のネット送信やDB接続は持たず、ローカルファイルで入出力します。Helpの公式リンクを利用者が開く場合は外部サイトへ移動します。設定と運用ログは端末のprefdir配下です。保存契約は${pageLink('interface-data','データ・外部インターフェース仕様書')}で定義します。</p>`),
]);

add('PIT-03','detailed-design','詳細設計書','詳細設計','学習・検証・数値計算・例外処理の規則を定める。',[
 section('models','回帰モデル',table(['方式','計算と保存の要点'],[['GPR','fitrgpの完全なRegressionGP。設定のFit method（exact / sd / sr / fic）を使用。カーネルは7種類の既存候補。'],['重回帰・PLS','各学習行だけでX/yを標準化。切片付き最小二乗／plsregressで学習し、係数を元単位へ戻す。ランク不足と過大成分数を拒否。'],['ランダムフォレスト／バギング木','回帰木のアンサンブル。初期100本、10〜1000本。方式に応じた説明変数抽出を使用。'],['変数重要度','Permutation Importanceは入力の並べ替えでの誤差変化。PLS VIPは潜在成分への寄与。因果効果ではない。']])),
 section('validation','条件比較・検証・履歴',`<p>GPRはカーネルごと、他の回帰は方式ごとに候補を作り、目的変数×条件が100組以下かを検証します。Folds=0は学習データ評価、Folds≥2は共通分割による検証です。分割の学習行だけで前処理・学習し、未学習行の予測を全行結合して評価します。保存用には全行学習モデルを別に保持します。</p><p>条件が1つでもCVを選べます。順位は目的変数ごとに示します。Scope・単位・入力範囲の違う値は同じ採用判断に混ぜません。過去モデルと評価時の元入力をRecordに保持し、設定や入力の変更後も選択できます。履歴は終了で消えます。</p>`),
 section('metrics','8評価指標・列の要約',table(['指標','定義と未定義条件'],[['決定係数 R²','1−Σ(y−ŷ)²/Σ(y−平均y)²。負値もある。実測一定なら未定義。'],['RMSE / MAE','sqrt(平均((y−ŷ)²)) / 平均(|y−ŷ|)。応答と同じ単位。'],['RMSPE','100×sqrt(平均(((y−ŷ)/y)²))。実測0があれば未定義。'],['Pearson r / 相関係数の2乗','rとr²。決定係数とは異なり、予測の偏りを検出できない場合がある。'],['KLダイバージェンス','共通等幅ビンの度数に1を加え規格化し、Σp log(p/q)。内部は自然対数。'],['相互情報量','2次元ヒストグラムの度数に1を加え、H(X)+H(Y)−H(X,Y)。内部はlog2。']])+`<p>ビン数0は自動（10とceil(log2(N)+1)の大きい方）。0または2〜1000を設定画面で指定します。表示名へnats・bitsを付けません。計算不能はNaNとNoteで表示します。列要約は件数・平均・四分位・標準偏差等です。</p>`),
 section('shap','SHAPと表示',`<p>モデルの学習データを背景としてSHAPを計算します。汎用クラスは予測関数をshapleyへ渡します。自動計算は先頭最大1000行です。分布は標準swarmchart、依存図は説明変数とSHAP値の関係を表示し、点の色の変数を変更できます。SHAPの計算失敗は学習失敗と分け、成功済みモデルを保持して再計算できるようにします。</p><p>予実と残差は同じタブに並べ、色は元行に対応する任意列で指定します。色の変更で学習・評価をやり直しません。</p>`),
 section('furnace','炉内補間',`<p>Runと目的変数ごとに、利用可能な計測Slotで学習します。スプラインはnot-a-knot、poly3は3次最小二乗、RBFはGaussian基底＋直線。RBF幅0はSlot間隔中央値の2倍、正則化初期1e−8。GPRはsquaredexponential・matern52・rationalquadratic、共通Fit method、PredictMethod=exact、線形基底・標準化を使用します。</p><p>内部Slot検証では両端を学習に残し、内部点を1点ずつ外します。検証予測を結合して8指標を計算します。端部・外挿の精度まで検証したとは扱いません。外挿は初期オフで範囲外をNaNと理由にし、有効化したときに区別して表示します。GPRだけが95%応答予測区間を持ちます。</p>`),
 section('doe','実験計画',`<p>D/I計画は−1〜1の2〜5水準候補から座標交換する局所探索です。Iの積分領域は連続な一様領域です。同一水準の直交表を生成し、4水準には有限体GF(4)を使用します。D効率・A効率・I基準・G効率・VIF・予測分散と交絡を表示します。生成成功だけで全効果を識別できるとは扱いません。</p>`),
 section('errors','例外処理',`<p>不正入力は実行前に元行・列と理由を示します。候補ごとの学習失敗とSHAP失敗を分け、中止時やエラー後も操作ロックを解除します。保存後検証の失敗したMATは使用しません。設定の読込み失敗は初期値と警告、ログの書込み失敗は通知で扱います。NaNの結果を0で補いません。</p>`),
]);

add('PIT-04','interface-data','データ・外部インターフェース仕様書','設計・外部結合','入力列・出力項目・MAT保存・設定とログの形式を定める。',[
 section('input','入力仕様',table(['用途','必須項目','検証'],[['共通','CSV / Excel、シート、ヘッダー行、列名、データ行','一意で空欄でないヘッダー。SourceRowを保持。'],['APC','4変数へ割り当てる数値列＋目的変数','説明変数と応答の重複なし。列順固定。'],['Swing Curve','膜厚（nm）・必要な下地列・目的変数','下地なしは膜厚だけ。最後のモデル入力名はRESIST_TH。'],['汎用回帰','数値の説明変数と目的変数','有限値・一意な入力列と順序。'],['炉内','WaferId・正整数BoatSlot・計測列・任意バッチ','Run内WaferIdとSlot重複不可。計測列の空欄だけは未計測。バッチなしは全行1Run。']])),
 section('mat','モデル保存契約',table(['対象','MAT変数','保持するもの','読込み'],[['GPR','Train_Modelのみ','完全なRegressionGP、X・入力名・ResponseName・学習属性。compact化しない。','load_train_model / load_analysis_model。旧制御側は互換確認が必要。'],['重回帰・PLS・木','Regression_Modelのみ','Version=1のProcessRegressionModel、Method・入力名・X/Y・係数またはEnsemble等。','load_analysis_model / predict。必要なcoreクラスを使用。'],['炉内補間','Furnace_Modelのみ','選択Run・目的変数・方式・計測値・Slot・元行・設定・学習器。','load_furnace_model / predict_furnace_model。推定・SHAPのMATとは別。']])+`<p>初期名は<code>Train_Model_目的変数.mat</code>、<code>SwingCurve_Model_目的変数.mat</code>、<code>GenericGPR_Model_目的変数.mat</code>、汎用クラスは<code>GenericRegression_Model_目的変数.mat</code>、炉内は<code>FurnaceInterpolation_Model_…mat</code>です。目的変数名をファイル名へ付けてもResponseNameを勝手に変更しません。</p><p>保存時は既に学習済みの1モデルを再学習せず保存し、変数・属性・学習データと予測の一致を検証します。MATは学習値を含み、入力と同じ管理区分で扱います。</p>`),
 section('results','表と画像の出力',table(['出力','項目と規則'],[['予測・SHAPの1表','SourceRow、元説明変数、任意の実測、予測、残差（実測−予測）、SHAP。列名重複時は番号で区別。'],['未計算SHAP','先頭M行だけ計算したとき、残りはNaN。寄与0とは区別。'],['比較・指標','目的変数、条件、Scope、指標、成否とNote等。'],['炉内予測','Run・目的変数・方式、Slot・WaferId・元行、予測と区間・外挿。生成SlotのWaferIdは空欄。'],['PNG・コピー','表示中または選択したグラフの画像。モデルや数値データの代わりではない。']])),
 section('settings','設定JSON',`<p>設定は<code>prefdir/StandaloneAnalysisApp/settings.json</code>。Windowsの実ユーザー名を固定した絶対パスは作りません。許可項目だけを保存し、一時ファイルから置換します。</p>${table(['項目','初期値','条件'],[['SaveFolder / Theme / FontSize','起動フォルダ／ライト／12','存在するフォルダ、ライト／ダーク、8〜20整数。'],['Kernel / SwingKernel / FitMethod','squaredexponential／squaredexponential／exact','Fit methodはexact・sd・sr・fic。新しいGPR学習へ反映。'],['InputCount / Bins','4 / 0','入力1〜100。ビン数0（自動）または2〜1000。'],['Factors / Runs / Seed','3 / 25 / 42','因子1〜8、実験数1〜300、seed 0〜2³²−1。比較用の初期seed 0とは別。'],['RBFWidth / RBFRidge / ShowPlots','0 / 1e−8 / true','幅0は自動、正則化1e−12〜1、SHAP図表示等の既定。']])}`),
 section('log','運用ログと外部連携',`<p><code>prefdir/StandaloneAnalysisApp/logs/training.jsonl</code>へ追記します。日時（JST）、Function・InputFile・Rows・Kernel・FitMethod・SavePath・Verification・PredictorNames・ResponseName・Status・ElapsedSeconds・Folds・Seedの許可項目を記録します。X/Y値そのものは書きませんが、ファイル名や保存先は含みます。</p><p>設備・DB・外部解析API・自動更新・ログ送信は対象外です。Helpの外部リンクは利用者が開く操作です。ログの保管期間と削除担当は運用レビューで決定します。</p>`),
]);

add('PIT-05','test-plan','テスト計画・テスト仕様書','単体・結合・総合・受入','本書の要求を対象に、手順・期待結果・証跡と判定を定める。',[
 section('strategy','テスト方針',table(['段階','対象','証跡'],[['単体','数値・入力・モデル・保存','テスト名、日付、環境、成功・失敗・未実施。'],['結合','入力→列選択→学習→比較→保存→再読込み','テストID、データ、画面、Status / Note、実SHAPか代替か。'],['総合','Windows R2025bで生成し、MATLABなしPCへ導入','OS・Runtime更新版、配布物ハッシュ・manifest・操作結果。'],['受入','代表業務データ・旧モデルの互換と精度','目的変数・単位・閾値・対象範囲、係長確認・課長承認。']])+notice('他環境の補助確認・代替SHAPの表示確認を、Windows R2025bでの実SHAP・Runtimeの合格へ読み替えません。')),
 section('specification','テスト項目',testTable(cases)),
 section('execute','実行と記録',`<p>Windows R2025bと必要製品を用意し、ソース一式を展開してテスト用フォルダで実行します。開発用例外を受入に使用しません。<code>run_tests</code>はプロジェクトの自動テストを実行するため、本書の要求に対応する結果を抽出して記録します。本書の19項目は画面・対象環境の手動確認も含み、自動テストの件数とは別です。</p>${code("setup_paths;\nresults = run_tests;\nfprintf('Passed=%d Failed=%d Incomplete=%d\\n', ...\n    sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));")}<p>テストIDごとに、実施日・担当・環境・入力・実結果・証跡パス・関連不具合IDを記録します。実行していないものは未実施とし、仮定によるスキップも成功へ数えません。</p>`),
 section('criteria','判定と再テスト',ordered(['数値許容差は既存の関連テストを正本とし、MAT保存前後の予測一致を確認する。','失敗を修正したら該当テストと影響する画面・保存・計算の回帰テストを実施し、旧結果も保持する。','精度と処理時間は目的変数・入力規模ごとの合意値で判定する。未合意の値を本書で捏造しない。','Windows／Runtime・実SHAP・旧制御側互換と高リスクを確認し、係長が技術確認、課長が受入と配布を承認する。'])),
]);

add('PIT-06','test-results','テスト結果・品質評価書','テスト結果・受入','既存証跡と未完了事項を分け、対象環境の判定を記録する。',[
 section('status','品質判定',`<p class="quality-pending">Windows R2025b／Runtimeの受入：未実施・配布承認前</p><p>2026-11-23に作成したテスト記録を、2026-11-25に更新しています。今回アプリの全テストは再実行していません。過去のプロジェクト集計を本書の対象機能だけの合格件数として転記せず、対象別の件数は未確定としています。</p>`),
 section('recorded','既存記録から確認できる範囲',table(['対象','既存の記録','扱い'],[['学習・比較・MAT往復','GPR、重回帰、PLS、木、複数目的変数、保存と再読込みの確認が記録されている。','開発環境の補助確認。対象要求別に証跡を抽出して再集計が必要。'],['入力・表示・出力','列選択、予実と残差、CSV / Excel / PNG、設定、Helpの確認記録。','Windowsでの画面・コピー・印刷を受入で再確認。'],['炉内補間・実験計画','Run分離、6方式、MAT往復、計画指標の数値と表示の記録。','実業務のデータと対象端末の確認は別。'],['SHAP','表示用代替計算を含む記録。','実shapleyの成功とみなさず対象環境で確認。'],['今回の文書','リンク・改定履歴・記録欄・スクリーンショットを別検査。','アプリのテスト件数へ加算しない。<a href="validation-report.json">文書の検証記録</a>。']])),
 section('pending','未完了の受入確認',table(['項目','状態','必要な証跡'],[['Windows R2025b','未実施','T-01〜17の対象要求別結果、OSと更新版。'],['実SHAP','未実施','T-09：モデル形式別の複数行計算・分布・依存図・再計算。'],['ビルド・Runtime導入','未実施','T-18：インストーラー、ハッシュ、manifest、MATLABなしでの動作。'],['旧制御側互換','未実施','T-19：旧／新MAT、同じXcheck、属性と予測差、制御側の読込み。'],['業務上の精度・性能','合格基準未合意','代表データ、単位、閾値と許容時間、判定者。']])+`<p>実行結果はテストID・実施日・環境・実施者・結果・証跡・不具合IDを追記し、文書版を更新します。未実施を空欄のまま合格へ変えません。</p>`),
 section('assessment','品質評価と次工程',`<p>補助環境の実績はありますが、Windowsでの実行・導入と業務受入は未完了です。精度目標・性能・互換性などの未決事項を確認し、対象環境のテスト結果を得て係長確認・課長承認を行います。</p>`),
]);


add('PIT-08','operations','運用・保守設計書','運用保守','日常操作、保存、障害対応、変更時の再確認を定める。',[
 section('daily','日常の利用',ordered(['入力の管理区分・単位・目的変数・Run識別を確認し、初回はサンプルかコピーで試す。','同じ目的変数・単位・入力範囲・Scopeで比較し、採用モデルは独立データでも評価する。','再利用するモデルは終了前に選択MAT保存し、保存後検証を確認する。起動中の履歴は終了で消える。','結果表と必要な画像、採用条件、評価範囲を保存する。未計算SHAPのNaNを0へ変えない。','MAT・設定・ログと承認記録を合意した管理先へ保管する。保存期間は運用レビューで確定する。'])),
 section('storage','管理対象',table(['対象','扱い','担当'],[['入力・MAT','MATは学習値を含む。原本・版を管理し、信頼できる作成元だけ読む。','利用者／管理担当'],['結果表・画像','対象モデル、元行、単位、Scopeと一緒に保持。','利用者'],['settings.json / training.jsonl','prefdir/StandaloneAnalysisApp配下。ファイル名・保存先も管理対象。','利用者／保守担当'],['配布物とソース','コミット、manifest、ハッシュ、旧配布物を保持。','作成者／配布担当'],['確認・承認記録','記入済みHTMLまたは印刷を文書版ごとに保管。公開登録しない。','作成者／係長／課長']])),
 section('incident','障害対応',table(['症状','対応'],[['起動しない','Windows 64bit・Runtime更新版・付随ファイルを確認し、環境情報を配布担当へ渡す。'],['入力で止まる','表示された列・元行と単位・空欄・Inf・重複を確認。原本を上書きせずコピーで直す。'],['学習／SHAP失敗','件数・条件・Status / Noteを確認。SHAPだけ失敗なら保持モデルで再計算。'],['保存後検証失敗','そのMATの利用を止め、元モデル・ログ・保存先と環境を記録する。'],['設定読込み警告','設定を退避し初期値で確認。必要な設定だけ再入力する。'],['精度・解釈が不明','ScopeとHelpを確認し、独立データによる評価・業務レビューを依頼。']])),
 section('maintenance','変更と保守',`<p>障害には再現手順・環境・対象モデル形式・期待と実結果・証跡を記録します。共有するテストデータは合成化し、実データや認証情報を公開しません。設定変更と、再学習してモデルを置き換える変更は別に管理します。</p><p>保存形式・入力順・列処理・カーネルを変える場合は、MAT往復・旧制御側互換・Runtimeを回帰確認します。変更理由・要求・テスト範囲・担当を記録し、必要な文書の改定と係長確認・課長承認を取り直します。</p>`),
]);

add('PIT-09','user-manual','利用者操作手順書','利用・受入','Windowsでの入力、学習、比較、保存と各機能の操作を示す。',[
 section('before','作業前の確認',`<p>対象はWindowsの利用者です。入力の単位・目的変数・Run、出力先を確認します。同梱の<code>samples/ProcessInsight_Samples.xlsx</code>で操作を試せます。左のメニューは1〜8、設定は7、Helpは8、モデルを使う画面は5です。</p><p>掲載画像はアプリ内部だけの操作参考です。実環境のWindows上での合格証跡ではありません。OSのウィンドウ枠や閉じるボタンを含めていません。</p>`),
 section('open','① データを開く',`<p>左でAPC・Swing Curve・汎用回帰を選び、①でExcel / CSVかサンプルを開きます。シートとヘッダー行、先頭の値を確認してください。</p>${shot('51-data-step','① ファイル・シート・ヘッダー行の指定')}<p class="screen-focus">操作位置：中央上の「Excel / CSVを開く」→「シート」「ヘッダー行」。一覧は先頭100行で、学習は全行を使用します。</p>`),
 section('variables','② 目的変数と説明変数',`<p>左側で目的変数を選びます。複数選択は<strong>Ctrlを押しながらクリック</strong>します。APCは4変数へ入力列を割り当て、汎用回帰は説明変数と順序を指定します。</p>${shot('54-variables-generic','② 汎用回帰の目的変数・説明変数と入力順')}<p class="screen-focus">操作位置：左の目的変数 → 右の説明変数 → 右下の順序表と「上へ／下へ」。目的変数と同じ列を説明変数へ入れません。</p><p>Swing Curveでは下地なし／下地ありを選び、膜厚列と必要な下地列を指定します。実行時に数値・空欄・重複等を検証し、誤りがあれば②へ戻ります。</p>${shot('53-variables-swing','② Swing Curveの下地モードと膜厚・下地列')}<p class="screen-focus">操作位置：右上「モード」→「レジスト膜厚の列」→下地の一覧。最下部の順序表でRESIST_THが最後であることを確認します。</p>`),
 section('conditions','③ 条件を決めて実行',`<p>GPRカーネル、汎用回帰では方式・PLS成分数・木の本数を選びます。初期は交差検証なしの学習データ評価です。未知データの目安を比較する場合は交差検証を選びます。SHAPは省略し、後から計算できます。</p>${shot('55-conditions','③ カーネル・交差検証・SHAPと実行')}<p class="screen-focus">操作位置：左のカーネル一覧 → 右の交差検証とSHAP → 右下の実行ボタン。Fit methodは「7 設定」で変更します。</p>`),
 section('save','④ 結果を比べて保存',`<p>目的変数・条件・評価データの範囲（Scope）を確認して行を選びます。R²・RMSE・残差・SHAP・重要度を確認し、必要に応じて条件を変更して比較します。最後に採用モデルを保存します。</p>${shot('57-results','④ 比較一覧・予実と残差・選択モデル保存')}<p class="screen-focus">操作位置：上のモデル行 → 下の評価・グラフ →「選択モデルをMAT保存」。保存後検証を確認します。「予測・SHAPを1ファイルに保存」で元入力と結果を出力できます。</p>`),
 section('prediction','保存モデルで推定・SHAP',`<p>左の5でMATまたは起動中モデルを選び、推定データを開いて保存モデルの入力順へ割り当てます。実測列は任意です。SHAPを選んで実行し、分布・入力別依存図を確認します。色の変数も変更できます。</p>${shot('61-predict','保存モデルの選択・列割当とSHAP分布')}<p class="screen-focus">操作位置：左の①モデル → ②データ → ③割当 → ④実行。右側で結果を見る。炉内補間のFurnace_Modelをこの画面に読み込ませません。</p>`),
 section('furnace','炉内補間',`<p>4でWaferId・BoatSlot・計測列・任意バッチを指定し、予測範囲と6方式を選びます。Runを混ぜず、目的変数ごとの検証RMSEと曲線を確認します。外挿は必要な場合だけ有効にします。</p>${shot('73-furnace-conditions','炉内補間の方式・予測Slotと外挿設定')}<p class="screen-focus">操作位置：左の方式一覧 → 右のSlot範囲 → 必要な場合だけ外挿 → 実行。④で選んだRun・項目・方式を専用MATへ保存します。</p>`),
 section('doe-settings','実験計画・設定',`<p>6でD最適・I最適・直交表を選び、因子数・モデル・水準・実験数を設定します。値は−1〜1の符号化値です。生成したら交絡・ランク・効率も確認します。</p>${shot('65-doe','実験計画の条件と交絡の可視化')}<p class="screen-focus">操作位置：左で方式とモデル等を選び「実験計画を作成」。右の評価指標と交絡を確認。実単位への換算表は別途保持します。</p><p>7で保存先・テーマ・文字サイズ・GPR Fit method・ビン数・DOE seed・RBF条件を変更し、「設定を保存して適用」を押します。</p>${shot('67-settings','共通設定と保存・適用')}<p class="screen-focus">操作位置：必要な設定項目 → 左下「設定を保存して適用」。変更は次回の実行へ反映し、学習済みの履歴は消しません。</p>`),
 section('finish','完了確認と困ったとき',`<p>終了前に使うモデルをMAT保存し、出力表・採用条件・評価範囲を保管してください。入力の誤りは表示された列・元行を確認します。保存後検証に失敗したモデルは使用せず、${pageLink('operations','障害対応')}を参照します。用語は「8 Help」で確認できます。</p>`),
]);


const reviewFields = (key, role, states) => `<tr><th scope="row">${role}</th><td><input name="${key}-name" type="text" autocomplete="off" aria-label="${role}の氏名" value="${key==='author'?author:''}"></td><td><input name="${key}-date" type="date" aria-label="${role}の作成日・レビュー日" value="${key==='author'?created:''}"></td><td>${states?`<select name="${key}-decision" aria-label="${role}の判定">${states.map((value,i)=>`<option value="${value}"${i===0?' selected':''}>${value}</option>`).join('')}</select>`:'作成'}</td><td><textarea name="${key}-comment" aria-label="${role}のコメント" rows="2"></textarea></td></tr>`;
const reviewSection = doc => section('review','確認・承認記録',`<form id="review-form" data-document-id="${doc.id}" data-version="${version}" data-created="${created}" data-updated="${updated}" data-file="${doc.file}"><p>作成者の作成記録、係長の確認、課長の承認を記入します。日付だけで判定は変わりません。改定した内容には、あらためて確認・承認を受けてください。</p><div class="table-scroll"><table class="guide-table review-table"><thead><tr><th>役割</th><th>氏名</th><th>作成日／レビュー日</th><th>判定</th><th>指摘・コメント・残事項</th></tr></thead><tbody>${reviewFields('author','作成者',null)}${reviewFields('checker','確認者（係長）',['未確認','確認済み','差戻し'])}${reviewFields('approver','承認者（課長）',['未承認','承認','差戻し'])}</tbody></table></div><p class="review-status" id="review-status" aria-live="polite">確認：未確認 ／ 承認：未承認</p><div class="review-actions"><button type="button" id="save-reviewed">記入済みHTMLを保存</button><button type="button" id="export-review">記録をJSON保存</button><button type="button" id="print-document">印刷／PDF保存</button></div><p id="review-message" role="status">改定履歴と確認・承認記録を編集した後は保存または印刷してください。入力は自動保存されません。</p><p class="source-note">この欄は記録用です。本人認証・電子署名・承認の外部送信は行いません。記入済みHTMLは元ファイルと同じフォルダで開いてください。</p></form>`);
const initialRevisions = [
  {version:'1.0',date:created,type:'新規作成',description:'文書の初版を新規作成。',author},
  {version,date:updated,type:'改定',description:'改定履歴をHTML上で追加・編集できるように変更。根拠欄を削除し、テストの表記へ統一。文書構成を9点に整理。',author},
];
const revisionRow = (row,index) => `<tr data-revision-row data-row-id="${index}">${['version','date','type','description','author'].map(key=>{
  const label={version:'版',date:'改定日',type:'区分',description:'改定内容',author:'作成者'}[key];
  const attributes=`name="revision-${index}-${key}" data-revision-field="${key}" aria-label="改定履歴${index}行目の${label}"`;
  let field;
  if(key==='description')field=`<textarea ${attributes} rows="3">${escape(row[key])}</textarea>`;
  else if(key==='type')field=`<select ${attributes}>${['新規作成','改定'].map(value=>`<option value="${value}"${value===row[key]?' selected':''}>${value}</option>`).join('')}</select>`;
  else field=`<input ${attributes} type="${key==='date'?'date':'text'}" value="${escape(row[key])}">`;
  return `<td>${field}</td>`;
}).join('')}<td class="revision-operation"><span class="source-note">既存行</span></td></tr>`;
const revisionSection = () => section('revisions','改定履歴',`<form id="revision-form"><p>各セルを直接編集できます。「改定履歴の行を追加」で末尾へ追加します。文書版と更新日は最終行の版・改定日を反映します。</p><div class="revision-actions"><button type="button" id="add-revision">改定履歴の行を追加</button><button type="button" data-save-html>記入済みHTMLを保存</button></div><div class="table-scroll"><table class="guide-table revision-table" id="revision-table"><thead><tr><th>版</th><th>改定日</th><th>区分</th><th>改定内容</th><th>作成者</th><th class="revision-operation">操作</th></tr></thead><tbody>${initialRevisions.map((row,i)=>revisionRow(row,i+1)).join('')}</tbody></table></div><p id="revision-message" role="status">変更内容は「記入済みHTMLを保存」と「記録をJSON保存」に含まれます。</p></form>`);

docs[0].sections.find(item=>item.id==='catalog').body=table(['文書番号','文書名','主工程','文書版','記録状態'],docs.map(doc=>[doc.id,pageLink(doc.file,doc.title),doc.phase,version,'係長未確認・課長未承認']))+'<p>各文書を個別に確認・承認します。実際の記録は、それぞれの記入済みHTMLで確認してください。</p>';
for(const doc of docs){
  const info=section('control','文書管理情報',table(['文書番号','文書版','作成日','更新日','作成者','状態'],[[doc.id,`<span data-document-version>${version}</span>`,created,`<span data-document-updated>${updated}</span>`,author,'<span data-review-summary>確認・承認前</span>']])+`<p>${doc.purpose}</p><p>製品：Process Insight Tool。文書版は製品バージョンとは別に管理します。</p>`);
  const sections=[info,...doc.sections,reviewSection(doc),revisionSection()];
  const nav=`<aside id="sidebar" class="sidebar" aria-label="文書と章の目次"><div class="sidebar-header"><p class="eyebrow">PROCESS INSIGHT TOOL</p><p class="sidebar-title">ウォーターフォール開発文書</p><p class="sidebar-subtitle">文書版 <span data-document-version>${version}</span> · <span data-document-updated>${updated}</span></p></div><nav><p class="nav-label">文書一覧</p><ol class="document-list">${docs.map(item=>`<li><a href="${item.file}.html"${item.id===doc.id?' class="current-document" aria-current="page"':''}><span>${item.id}</span>${item.title}</a></li>`).join('')}</ol><p class="nav-label">この文書の目次</p><ol class="toc-list">${sections.map(item=>`<li><a href="#${item.id}">${item.title}</a></li>`).join('')}</ol></nav><div class="sidebar-footer">${doc.id} ／ 文書版 <span data-document-version>${version}</span><br><span data-review-summary>確認・承認前</span></div></aside>`;
  const html=`<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="Process Insight Toolの${doc.title}。改定履歴と確認・承認欄を編集できます。"><title>${doc.id} ${doc.title}｜Process Insight Tool</title><link rel="icon" href="data:,"><link rel="stylesheet" href="procedure-guide.css"><link rel="stylesheet" href="documents.css"><script src="procedure-guide.js" defer></script><script src="document-review.js" defer></script></head><body id="top"><a class="skip-link" href="#main-content">本文へ移動</a><button id="toc-toggle" class="toc-toggle" type="button" aria-controls="sidebar" aria-expanded="false">目次</button>${nav}<div id="sidebar-overlay" class="sidebar-overlay" aria-hidden="true"></div><main id="main-content" class="main-content"><header class="hero"><div class="hero-content"><p class="eyebrow">${doc.id} / ${doc.phase}</p><h1>${doc.title}</h1><p class="hero-lead">${doc.purpose}</p><div class="hero-badges"><span>文書版 <span data-document-version>${version}</span></span><span>作成者：${author}</span><span>更新：<span data-document-updated>${updated}</span></span><span data-review-summary>確認・承認前</span></div></div></header><p class="guide-status">Windows R2025b／Runtimeでの受入は未完了です。文書の確認・承認は各記録欄へ記入してください。</p>${sections.map(item=>`<section id="${item.id}" class="content-section"><h2>${item.title}</h2>${item.body}</section>`).join('\n')}<footer class="page-footer"><p>${doc.id} ${doc.title} ／ 文書版 <span data-document-version>${version}</span> ／ 更新 <span data-document-updated>${updated}</span></p><p>作成：${author} ／ 係長確認・課長承認は各記録欄へ</p></footer></main><button id="back-to-top" class="back-to-top" type="button" aria-label="ページ上部へ戻る">↑ トップへ戻る</button><dialog id="image-dialog" class="lightbox" aria-labelledby="dialog-caption"><div class="lightbox-bar"><p id="dialog-caption"></p><button id="dialog-close" class="lightbox-close" type="button">閉じる（Esc）</button></div><img id="dialog-image" alt=""></dialog></body></html>
`;
  fs.writeFileSync(path.join(output,`${doc.file}.html`),html);
}
fs.writeFileSync(path.join(output,'document-index.json'),JSON.stringify({created,updated,version,author,documents:docs.map(({id,file,title,phase})=>({id,file:`${file}.html`,title,phase})),requirements:requirements.map(row=>({id:row[0],test:row[3]}))},null,2)+'\n');
fs.writeFileSync(path.join(output,'validation-report.json'),JSON.stringify({updated,version,documentValidation:'pending',applicationTestsThisTask:'not run',checkerReview:'not performed',managerApproval:'not performed'},null,2)+'\n');
console.log(JSON.stringify({documents:docs.length,requirements:requirements.length,tests:cases.length,version,updated}));

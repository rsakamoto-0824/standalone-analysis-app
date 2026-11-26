# 公開ベンチマークデータセット20件

多目的最適化10件、因果探索10件のデータ本体を収録しています。**CSVをダウンロードしてそのまま読み込めます**。ヘッダーはすべて1行目です。CSVはUTF-8 BOM付きで、WindowsのExcelでも列名を表示できます。

公開元はUCI、MOOT、Microsoft CSuite、GraN-DAGです。Kaggleの転載ではなく、出典と再配布条件を確認できる公式の配布先から取得しました。出典ごとのCC BY 4.0 / MITの許諾・著作権を[licenses](licenses/)に収録しています。取得日: **2026-11-25**。

## 多目的最適化（10件）

目的変数は`Y_`で始まる列です。「最小化／最大化」の設定は個別READMEにあります。表のパレート数は、公開候補内の非劣解の行数です。連続空間全体での大域最適性を意味しません。

| ID・データ | 対象 | 行数 | 入力数 | 目的数 | 候補内パレート数 |
|---|---|---:|---:|---:|---:|
| [mo01_energy_efficiency / Energy Efficiency](multiobjective/mo01_energy_efficiency/README.md) | 建物エネルギーシミュレーション | 768 | 8 | 2 | 2 |
| [mo02_concrete_slump / Concrete Slump Test](multiobjective/mo02_concrete_slump/README.md) | コンクリート配合の実測 | 103 | 7 | 3 | 4 |
| [mo03_gas_turbine / Gas Turbine CO and NOx Emission](multiobjective/mo03_gas_turbine/README.md) | タービンの時系列実測 | 36,733 | 8 | 3 | 75 |
| [mo04_ss_e / MOOT SS-E](multiobjective/mo04_ss_e/README.md) | ソフトウェア設定の計測 | 756 | 3 | 2 | 16 |
| [mo05_ss_j / MOOT SS-J](multiobjective/mo05_ss_j/README.md) | ソフトウェア設定の計測 | 3,840 | 6 | 2 | 34 |
| [mo06_ss_q / MOOT SS-Q](multiobjective/mo06_ss_q/README.md) | ソフトウェア設定の計測 | 2,736 | 12 | 3 | 57 |
| [mo07_ss_d / MOOT SS-D](multiobjective/mo07_ss_d/README.md) | ソフトウェア設定の計測 | 196 | 3 | 2 | 15 |
| [mo08_pom3d / MOOT pom3d](multiobjective/mo08_pom3d/README.md) | 開発プロセスのシミュレーション | 500 | 9 | 3 | 7 |
| [mo09_xomo_flight / MOOT xomo_flight](multiobjective/mo09_xomo_flight/README.md) | 開発プロセスのシミュレーション | 10,000 | 25 | 4 | 2 |
| [mo10_coc1000 / MOOT coc1000](multiobjective/mo10_coc1000/README.md) | 開発プロセスのシミュレーション | 1,000 | 20 | 5 | 144 |

XOMOは元の27入力のうち定数列2つを推奨選択から除いています（CSVには残しています）。タービンの完全重複7行も、公開元の行を保つため削除していません。

多目的最適化では、候補表から選ぶ方法を比較できます。複数の目的を予測するモデルの比較にも使用できます。各列の範囲を組み合わせた未知の条件には真値がないため、このデータだけで採点できません。アプリへの最適化アルゴリズムの追加は含みません。

## 因果探索（10件）

すべて**公開済みの合成データ**です。正解グラフが付く連続値のデータを選びました。2～20変数で、アプリの数値列として読み込めます。線形・非線形など前提が異なるため、手法の適用条件を各READMEで確認してください。

| ID・データ | 性質 | 主入力の行数 | 変数数 | 正解の辺数 |
|---|---|---:|---:|---:|
| [cd01_csuite_lingauss / CSuite lingauss](causal/cd01_csuite_lingauss/README.md) | 線形・正規ノイズ | 4,000 | 2 | 1 |
| [cd02_csuite_linexp / CSuite linexp](causal/cd02_csuite_linexp/README.md) | 線形・指数分布ノイズ | 4,000 | 2 | 1 |
| [cd03_csuite_nonlingauss / CSuite nonlingauss](causal/cd03_csuite_nonlingauss/README.md) | 非線形・正規ノイズ | 4,000 | 2 | 1 |
| [cd04_csuite_nonlin_simpson / CSuite nonlin_simpson](causal/cd04_csuite_nonlin_simpson/README.md) | 非線形・Simpsonの逆転 | 2,000 | 4 | 4 |
| [cd05_csuite_symprod_simpson / CSuite symprod_simpson](causal/cd05_csuite_symprod_simpson/README.md) | 積の相互作用・多峰性 | 2,000 | 4 | 4 |
| [cd06_csuite_large_backdoor / CSuite large_backdoor](causal/cd06_csuite_large_backdoor/README.md) | 9変数・バックドア | 2,000 | 9 | 9 |
| [cd07_csuite_weak_arrows / CSuite weak_arrows](causal/cd07_csuite_weak_arrows/README.md) | 9変数・弱い多数の辺 | 2,000 | 9 | 15 |
| [cd08_grandag_er10 / GraN-DAG ER 10変数・疎](causal/cd08_grandag_er10/README.md) | 公開済み非線形GPシミュレーション | 1,000 | 10 | 8 |
| [cd09_grandag_er20 / GraN-DAG ER 20変数・疎](causal/cd09_grandag_er20/README.md) | 公開済み非線形GPシミュレーション | 1,000 | 20 | 21 |
| [cd10_grandag_sf20 / GraN-DAG Scale-free 20変数・密](causal/cd10_grandag_sf20/README.md) | 公開済み非線形GPシミュレーション | 1,000 | 20 | 48 |

CSuiteはtrain/val/testを収録し、表にはtrainの行数を示しています。GraN-DAGは各公開パッケージのreplicate 1を採用し、DAGに加えてCPDAGも保持しています。CSuiteの一部の行数・辺数は配布元の概要と相違があるため、取得したファイルの実数を記録しました。

PCが返す向きの決まらない辺と、DirectLiNGAMが返す有向辺は区別して評価します。特に2変数の線形正規モデルでは観測値だけで方向を特定できません。非線形データには、偏相関PC・線形DirectLiNGAMの限界を確認する用途があります。

## 使い方と出典

1. 個別READMEで開くCSVと選択列を確認します。多目的最適化用は汎用回帰学習、因果探索用は因果探索画面へ読み込みます。目的列は自動で選ばれない場合があるため、一覧から選択してください。
2. 詳しい分割・評価・再取得の手順は[ベンチマークの進め方](benchmark-protocol.md)にあります。正解ファイルや分割表を学習入力へ混ぜないでください。
3. [一覧CSV](catalog.csv)と[詳細メタデータJSON](catalog.json)には、列対応・目的方向・取得URL・固定版・SHA-256・欠損・重複・定数列を記録しています。

再取得用の[_src/prepare_datasets.py](_src/prepare_datasets.py)はPython 3.14.5以上・NumPy 2.4.6で動作します。取得済みCSVの利用にはPythonは不要です。公開データの版を固定し、数値の補間・標準化・外れ値削除は行っていません。

| 公開元 | 対象 | 条件・出典 |
|---|---|---|
| [UCI](https://archive.ics.uci.edu/) | 多目的最適化3件 | 各個別READMEに著者とデータセットDOI、[CC BY 4.0](licenses/CC-BY-4.0.txt) |
| [MOOT](https://github.com/timm/moot) | 多目的最適化7件 | 固定コミットca616386、[MIT](licenses/MOOT-MIT.txt)。Menzies et al., [arXiv:2511.16882](https://arxiv.org/abs/2511.16882) |
| [Microsoft CSuite](https://github.com/microsoft/csuite) | 因果探索7件 | リリースv0.1、[MIT](licenses/CSuite-MIT.txt)。Geffner et al., [arXiv:2202.02195](https://arxiv.org/abs/2202.02195) |
| [GraN-DAG](https://github.com/kurowasan/GraN-DAG) | 因果探索3件 | 固定コミットd86ab593、[MIT](licenses/GraN-DAG-MIT.txt)。Lachapelle et al., [arXiv:1906.02226](https://arxiv.org/abs/1906.02226) |

データの許諾条件は元のライセンスに従います。アプリ本体のライセンスで第三者データを一括で再許諾するものではありません。

## 確認範囲

[データ検査結果](validation.json)に件数・検査内容、[アプリ読込みの確認記録](matlab-import-validation.json)に読込みの確認環境を記録しています。数値のCSV変換と再読込み、欠損・重複・定数列、正解グラフ、パレート解、分割の整合性を確認しています。最適化や因果探索の精度の合格結果ではありません。MATLAB R2025b / Windowsでの動作確認は未実施です。

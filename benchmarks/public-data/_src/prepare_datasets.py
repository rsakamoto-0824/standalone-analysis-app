"""Fetch pinned public benchmark data, convert losslessly, and audit the bundle.

Python 3.14.5+ / NumPy 2.4.6. No application code or external programs run.
"""

import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import tempfile
import urllib.request
import warnings
import xml.etree.ElementTree as ET
import zipfile

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
CONFIG = Path(__file__).with_name("sources.json")
XML_NS = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
RANDOM_SEED = 20261125
DATASET_COUNT_PER_CATEGORY = 10


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_csv(path, headers, rows):
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(headers)
        writer.writerows(rows)


def write_numeric(path, headers, values):
    # Seventeen significant digits preserve every finite IEEE 754 double.
    write_csv(path, headers, ([format(float(cell), ".17g") for cell in row] for row in values))
    actual_headers, actual_values = read_numeric(path)
    if actual_headers != headers or not np.array_equal(actual_values, values):
        raise ValueError(f"Numeric round-trip mismatch: {path}")


def read_numeric(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.reader(stream)
        headers = next(reader)
        rows = list(reader)
    if not rows or len(set(headers)) != len(headers) or any(not name for name in headers):
        raise ValueError(f"Empty data or duplicate/blank headers: {path}")
    if any(len(row) != len(headers) for row in rows):
        raise ValueError(f"Ragged rows: {path}")
    values = np.array(rows, dtype=float)
    if not np.isfinite(values).all():
        raise ValueError(f"Missing or nonfinite value: {path}")
    return headers, values


def fetch(cache, filename, url, expected_sha256):
    path = cache / filename
    if not path.exists():
        request = urllib.request.Request(url, headers={"User-Agent": "ProcessInsightTool-public-benchmarks/1.0"})
        with urllib.request.urlopen(request, timeout=45) as response:
            content = response.read()
        if hashlib.sha256(content).hexdigest() != expected_sha256:
            raise ValueError(f"Upstream content changed; review before replacing: {url}")
        path.write_bytes(content)
    if sha256(path) != expected_sha256:
        raise ValueError(f"Cache checksum mismatch: {path}")
    return path


def parse_csv(content):
    rows = list(csv.reader(io.StringIO(content.decode("utf-8-sig")), skipinitialspace=True))
    return [name.strip() for name in rows[0]], np.array(rows[1:], dtype=float)


def energy_table(path):
    with zipfile.ZipFile(path) as archive:
        workbook_bytes = archive.read("ENB2012_data.xlsx")
    with zipfile.ZipFile(io.BytesIO(workbook_bytes)) as workbook:
        shared = ET.fromstring(workbook.read("xl/sharedStrings.xml"))
        strings = ["".join(item.itertext()) for item in shared]
        sheet = ET.fromstring(workbook.read("xl/worksheets/sheet1.xml"))
        rows = []
        for row in sheet.findall("s:sheetData/s:row", XML_NS):
            values = [None] * 10
            for cell in row.findall("s:c", XML_NS):
                column = re.match(r"([A-Z]+)", cell.attrib["r"])[1]
                index = 0
                for character in column:
                    index = index * 26 + ord(character) - ord("A") + 1
                if index > 10:
                    continue
                value = cell.find("s:v", XML_NS)
                if value is not None and value.text is not None:
                    values[index - 1] = strings[int(value.text)] if cell.attrib.get("t") == "s" else value.text
            if any(value is not None for value in values):
                rows.append(values)
        if any(value is None for row in rows for value in row):
            raise ValueError("Unexpected partially empty Energy Efficiency record")
        return rows[0], np.array(rows[1:], dtype=float)


def clean_name(name):
    return re.sub(r"[^A-Za-z0-9_]", "_", name).strip("_")


def profile(headers, values):
    return {
        "rows": len(values), "columns": len(headers), "missing_cells": 0,
        "nonfinite_cells": 0,
        "duplicate_rows": int(len(values) - len(np.unique(values, axis=0))),
        "constant_columns": [headers[i] for i in range(len(headers)) if np.ptp(values[:, i]) == 0],
        "ranges": {name: {"min": float(values[:, i].min()), "max": float(values[:, i].max()),
                          "distinct": int(len(np.unique(values[:, i])))} for i, name in enumerate(headers)},
    }


def pareto_indices(values, directions):
    costs = values * np.array([1 if direction == "min" else -1 for direction in directions])
    unique, inverse = np.unique(costs, axis=0, return_inverse=True)
    # np.unique sorts lexicographically; later rows cannot dominate earlier rows.
    frontier = np.empty_like(unique)
    count = 0
    selected = np.zeros(len(unique), dtype=bool)
    for index, candidate in enumerate(unique):
        if count and np.any(np.all(frontier[:count] <= candidate, axis=1)):
            continue
        selected[index] = True
        frontier[count] = candidate
        count += 1
    # Identical nondominated objective vectors retain all of their source rows.
    return np.flatnonzero(selected[inverse])


def multiobjective(spec, path, folder):
    transformations = []
    if spec["format"] == "energy_xlsx":
        original, values = energy_table(path)
        headers = spec["inputs"] + ["Y_" + item[0] for item in spec["objectives"]]
        transformations.append("XLSXの非空データ行のみをCSV化。単位・数値は未変更。")
    elif spec["format"] == "slump_csv":
        with zipfile.ZipFile(path) as archive:
            original, values = parse_csv(archive.read("slump_test.data"))
        original, values = original[1:], values[:, 1:]
        headers = spec["inputs"] + ["Y_" + item[0] for item in spec["objectives"]]
        transformations.append("元のNo列を除外。その他の値は未変更。")
    elif spec["format"] == "turbine_csv":
        blocks, years = [], []
        with zipfile.ZipFile(path) as archive:
            for year in range(2011, 2016):
                original, block = parse_csv(archive.read(f"gt_{year}.csv"))
                blocks.append(block)
                years.extend([year] * len(block))
        values = np.concatenate(blocks)
        ordered = spec["inputs"] + [item[0] for item in spec["objectives"]]
        values = values[:, [original.index(name) for name in ordered]]
        original = ordered
        headers = spec["inputs"] + ["Y_" + item[0] for item in spec["objectives"]]
        transformations.append("2011～2015年を年順・元の行順で連結。列を入力→目的の順へ並べ替え。")
    else:
        original, values = parse_csv(path.read_bytes())
        headers = []
        spec["inputs"], spec["objectives"] = [], []
        for name in original:
            objective = name.endswith(("+", "-"))
            cleaned = clean_name(name.rstrip("+-"))
            headers.append(("Y_" if objective else "") + cleaned)
            if objective:
                spec["objectives"].append([cleaned, "max" if name.endswith("+") else "min"])
            else:
                spec["inputs"].append(cleaned)
        transformations.append("列名の空白・記号を整理。目的列にY_を付加。数値・行順は未変更。")
    if len(values) != spec["expected_rows"] or len(headers) != values.shape[1]:
        raise ValueError(f"Unexpected source shape: {spec['id']}")
    write_numeric(folder / "data.csv", headers, values)
    objectives = [{"column": "Y_" + name, "direction": direction} for name, direction in spec["objectives"]]
    targets = values[:, [headers.index(obj["column"]) for obj in objectives]]
    indices = pareto_indices(targets, [obj["direction"] for obj in objectives])
    write_csv(folder / "reference_pareto_indices.csv", ["data_row_1based"], ([int(index) + 1] for index in indices))
    if spec["format"] == "turbine_csv":
        splits = [(i + 1, "train" if year <= 2013 else "test", year) for i, year in enumerate(years)]
        write_csv(folder / "split.csv", ["data_row_1based", "split", "source_year"], splits)
        split_method = "UCIの年別分割（2011～2013 train、2014～2015 test）。"
    else:
        input_values = values[:, [headers.index(name) for name in spec["inputs"]]]
        _, inverse = np.unique(input_values, axis=0, return_inverse=True)
        # Identical inputs stay together, avoiding replicate leakage across splits.
        groups = np.random.default_rng(RANDOM_SEED).permutation(int(inverse.max()) + 1)
        test_groups = set(groups[:max(1, int(np.ceil(len(groups) * 0.2)))].tolist())
        write_csv(folder / "split.csv", ["data_row_1based", "split"],
                  ((i + 1, "test" if int(group) in test_groups else "train") for i, group in enumerate(inverse)))
        split_method = f"同一入力を同じ群にして約80/20に分割。seed={RANDOM_SEED}。"
    input_values = values[:, [headers.index(name) for name in spec["inputs"]]]
    quality = profile(headers, values)
    recommended_inputs = [name for name in spec["inputs"] if name not in quality["constant_columns"]]
    return {"data_file": "data.csv", "headers": headers, "inputs": spec["inputs"],
            "recommended_inputs": recommended_inputs, "objectives": objectives,
            "source_column_mapping": dict(zip(headers, original)), "quality": quality,
            "duplicate_input_rows": int(len(values) - len(np.unique(input_values, axis=0))),
            "reference_pareto_rows": len(indices), "split_method": split_method,
            "transformations": transformations}


def validate_graph(values):
    if values.ndim != 2 or values.shape[0] != values.shape[1]:
        raise ValueError("Graph must be square")
    if not np.isin(values, [0, 1]).all() or np.any(np.diag(values)):
        raise ValueError("Graph must be binary and have no self loops")
    pending = values.sum(axis=0).astype(int)
    queue = list(np.flatnonzero(pending == 0))
    visited = 0
    while queue:
        source = queue.pop()
        visited += 1
        for target in np.flatnonzero(values[source]):
            pending[target] -= 1
            if pending[target] == 0:
                queue.append(int(target))
    if visited != len(values):
        raise ValueError("Reference graph contains a cycle")


def causal(spec, path, folder):
    arrays = {}
    with zipfile.ZipFile(path) as archive:
        if spec["format"] == "csuite_zip":
            for name in ["train", "test", "val"]:
                arrays[name] = np.loadtxt(io.BytesIO(archive.read(name + ".csv")), delimiter=",")
            graph = np.loadtxt(io.BytesIO(archive.read("adj_matrix.csv")), delimiter=",")
            source_names = [variable["name"] for variable in json.loads(archive.read("variables.json"))["variables"]]
            source_members = ["train.csv", "test.csv", "val.csv", "adj_matrix.csv", "variables.json"]
        else:
            prefix = spec["member_prefix"]
            def load_array(name):
                with warnings.catch_warnings():
                    warnings.filterwarnings("ignore", message="Reading.*created on Python 2.*", category=UserWarning)
                    return np.load(io.BytesIO(archive.read(prefix + "/" + name)), allow_pickle=False)
            arrays["data"] = load_array("data1.npy")
            graph = load_array("DAG1.npy")
            cpdag = load_array("CPDAG1.npy")
            source_names = [f"source_column_{i}" for i in range(graph.shape[0])]
            source_members = [prefix + "/" + name for name in ["data1.npy", "DAG1.npy", "CPDAG1.npy"]]
            if not np.isin(cpdag, [0, 1]).all() or np.any(np.diag(cpdag)):
                raise ValueError("Invalid source CPDAG")
            if not np.array_equal((cpdag + cpdag.T) > 0, (graph + graph.T) > 0):
                raise ValueError("DAG and CPDAG skeletons disagree")
            write_numeric(folder / "reference_cpdag.csv", [f"X{i}" for i in range(len(graph))], cpdag)
    validate_graph(graph)
    headers = [f"X{i}" for i in range(len(graph))]
    profiles = {}
    for name, values in arrays.items():
        if values.ndim != 2 or values.shape[1] != len(headers):
            raise ValueError("Observation columns disagree with reference graph")
        write_numeric(folder / (name + ".csv"), headers, values)
        profiles[name + ".csv"] = profile(headers, values)
    data_file = "train.csv" if "train" in arrays else "data.csv"
    if profiles[data_file]["rows"] != spec["expected_rows"]:
        raise ValueError("Unexpected observation count")
    write_numeric(folder / "reference_adjacency.csv", headers, graph)
    write_csv(folder / "reference_edges.csv", ["source", "target"],
              ([headers[i], headers[j]] for i, j in zip(*np.nonzero(graph))))
    return {"data_file": data_file, "headers": headers, "profiles": profiles,
            "quality": profiles[data_file], "nodes": len(graph), "edges": int(graph.sum()),
            "source_column_mapping": dict(zip(headers, source_names)), "source_members": source_members,
            "graph_convention": "A[i,j]=1 means Xi -> Xj; data and matrix columns have the same order; no index column.",
            "transformations": ["元の列順・行順・数値を保持し、X0から始まるヘッダーを付加。NPYは17桁CSVへ変換。",
                                "観測データのみを収録。値の補間・標準化・外れ値削除は行わない。"]}


def dataset_readme(item, folder):
    source = item["source_info"]
    lines = [f"# {item['title']}", "", item["kind"], "", f"- 入力するファイル: [{item['data_file']}]({item['data_file']})（ヘッダー1行目）",
             f"- 行数: {item['quality']['rows']:,} / 列数: {item['quality']['columns']}",
             f"- [配布元]({item['page']}) / [元データ]({item['download_url']})",
             f"- ライセンス: [{source['license']}](../../licenses/{source['license_file']})",
             f"- 取得日: {item['retrieved_on']}", "", item["notes"], ""]
    if item["category"] == "multiobjective":
        lines += ["## 選ぶ列", "", "説明変数: " + ", ".join(f"`{name}`" for name in item["recommended_inputs"]), "",
                  "| 目的変数 | 方向 |", "|---|---|"]
        lines += [f"| `{obj['column']}` | {'最小化' if obj['direction'] == 'min' else '最大化'} |" for obj in item["objectives"]]
        lines += ["", f"候補内の非劣解は{item['reference_pareto_rows']}行。[正解行番号](reference_pareto_indices.csv)はdata.csvの**データ先頭を1**とする番号（CSVの物理行番号ではない）。",
                  "実機や連続空間全体の大域最適解を表すものではない。", "", f"[分割表](split.csv): {item['split_method']}",
                  "分割表・正解行番号を説明変数に入れない。全候補の真値は採点用に保持し、探索中のモデルへ全件を渡さない。"]
    else:
        lines += [f"因果探索で選ぶ列: {', '.join('`' + name + '`' for name in item['headers'])}", "",
                  f"正解は{item['nodes']}変数・{item['edges']}辺。",
                  "[隣接行列](reference_adjacency.csv)の行Xi・列Xjが1なら **Xi → Xj**。行見出し列はなく、行順・列順とも観測データと同じ。",
                  "[辺の一覧](reference_edges.csv)はsourceが原因、targetが結果。正解ファイルはアプリの入力データに混ぜない。"]
        if item["source"] == "csuite":
            lines += ["", "`train.csv`で探索し、`val.csv`で条件選択、`test.csv`を最終確認に使用。各ファイルは元の公開分割を保持する。"]
        else:
            lines += ["", "[CPDAG](reference_cpdag.csv)は公開元のマルコフ同値類の参照。両方向が1の辺は向き未確定を表す。",
                      "PCの未確定辺を誤って2本の有向辺として数えない。"]
    lines += ["", "## 変換と確認", ""] + ["- " + text for text in item["transformations"]]
    lines += [f"- 欠損・非有限値: 0 / 完全重複行: {item['quality']['duplicate_rows']}",
              "- 定数列: " + (", ".join(item["quality"]["constant_columns"]) or "なし"),
              "- 定数列はデータに保持し、説明変数の推奨選択からは外す。",
              "- 数値をCSVへ書き戻して元データと一致することを確認。", "", "| CSV列 | 元の列名 |", "|---|---|"]
    lines += [f"| `{name}` | `{original}` |" for name, original in item["source_column_mapping"].items()]
    lines += ["", "## 出典・再配布", "", item.get("citation", source.get("citation", "")),
              "", f"配布元の{source['license']}に従って再配布。著作権・許諾文は上記ライセンスファイルを参照。変更点は「変換と確認」に記載。", ""]
    (folder / "README.md").write_text("\n".join(lines), encoding="utf-8")


def build(cache):
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    cache.mkdir(parents=True, exist_ok=True)
    (ROOT / "licenses").mkdir(exist_ok=True)
    for key, source in config["sources"].items():
        path = fetch(cache, source["license_file"], source["license_url"], source["license_sha256"])
        (ROOT / "licenses" / source["license_file"]).write_bytes(path.read_bytes())
    catalog = []
    for original_spec in config["datasets"]:
        spec = dict(original_spec)
        print("Preparing " + spec["id"], flush=True)
        folder = ROOT / spec["category"] / spec["id"]
        folder.mkdir(parents=True, exist_ok=True)
        path = fetch(cache, spec["archive"], spec["download_url"], spec["source_sha256"])
        derived = multiobjective(spec, path, folder) if spec["category"] == "multiobjective" else causal(spec, path, folder)
        item = {**spec, **derived, "retrieved_on": config["retrieved_on"], "source_info": config["sources"][spec["source"]]}
        dataset_readme(item, folder)
        item["files"] = {file.name: {"sha256": sha256(file), "bytes": file.stat().st_size}
                         for file in sorted(folder.iterdir()) if file.is_file()}
        catalog.append(item)
    write_json(ROOT / "catalog.json", {"version": config["version"], "retrieved_on": config["retrieved_on"], "datasets": catalog})
    write_csv(ROOT / "catalog.csv", ["id", "category", "title", "rows", "columns", "data_file", "objectives_or_edges", "license", "source_url"],
              ([item["id"], item["category"], item["title"], item["quality"]["rows"], item["quality"]["columns"],
                item["category"] + "/" + item["id"] + "/" + item["data_file"],
                "; ".join(obj["column"] + ":" + obj["direction"] for obj in item["objectives"]) if item["category"] == "multiobjective" else str(item["edges"]) + " edges",
                item["source_info"]["license"], item["page"]] for item in catalog))
    verify()


def verify():
    catalog = json.loads((ROOT / "catalog.json").read_text(encoding="utf-8"))
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    for source in config["sources"].values():
        if sha256(ROOT / "licenses" / source["license_file"]) != source["license_sha256"]:
            raise ValueError("License checksum mismatch")
    counts = {category: sum(item["category"] == category for item in catalog["datasets"])
              for category in ["multiobjective", "causal"]}
    if any(count != DATASET_COUNT_PER_CATEGORY for count in counts.values()):
        raise ValueError(f"Wrong dataset counts: {counts}")
    observations, files = 0, 0
    for item in catalog["datasets"]:
        folder = ROOT / item["category"] / item["id"]
        for name, expected in item["files"].items():
            if sha256(folder / name) != expected["sha256"]:
                raise ValueError(f"Published checksum mismatch: {folder / name}")
            files += 1
        headers, values = read_numeric(folder / item["data_file"])
        if headers != item["headers"] or profile(headers, values) != item["quality"]:
            raise ValueError("Published profile mismatch: " + item["id"])
        observations += len(values)
        if item["category"] == "causal":
            names, graph = read_numeric(folder / "reference_adjacency.csv")
            validate_graph(graph)
            if names != headers or int(graph.sum()) != item["edges"]:
                raise ValueError("Published graph mismatch")
            with (folder / "reference_edges.csv").open(encoding="utf-8-sig") as stream:
                edges = {(row["source"], row["target"]) for row in csv.DictReader(stream)}
            if edges != {(headers[i], headers[j]) for i, j in zip(*np.nonzero(graph))}:
                raise ValueError("Edge list and adjacency disagree")
            if item["source"] == "grandag":
                names, cpdag = read_numeric(folder / "reference_cpdag.csv")
                if names != headers or not np.array_equal((cpdag + cpdag.T) > 0, (graph + graph.T) > 0):
                    raise ValueError("CPDAG skeleton mismatch")
            for name, expected_profile in item["profiles"].items():
                names, block = read_numeric(folder / name)
                if profile(names, block) != expected_profile:
                    raise ValueError("Split profile mismatch")
        else:
            objectives = item["objectives"]
            target_values = values[:, [headers.index(obj["column"]) for obj in objectives]]
            expected = (pareto_indices(target_values, [obj["direction"] for obj in objectives]) + 1).tolist()
            with (folder / "reference_pareto_indices.csv").open(encoding="utf-8-sig") as stream:
                actual = [int(row["data_row_1based"]) for row in csv.DictReader(stream)]
            if actual != expected:
                raise ValueError("Pareto reference mismatch")
            costs = target_values * [1 if obj["direction"] == "min" else -1 for obj in objectives]
            frontier = costs[np.array(actual) - 1]
            selected = np.zeros(len(costs), dtype=bool)
            selected[np.array(actual) - 1] = True
            # Independent, direct dominance check catches sorting/tie mistakes.
            for start in range(0, len(costs), 512):
                block = costs[start:start + 512, None, :]
                dominated = np.any(np.all(frontier[None, :, :] <= block, axis=2) &
                                   np.any(frontier[None, :, :] < block, axis=2), axis=1)
                if not np.array_equal(dominated, ~selected[start:start + 512]):
                    raise ValueError("Independent Pareto dominance check failed")
            with (folder / "split.csv").open(encoding="utf-8-sig") as stream:
                splits = list(csv.DictReader(stream))
            if [int(row["data_row_1based"]) for row in splits] != list(range(1, len(values) + 1)):
                raise ValueError("Missing or duplicate split row")
            if {row["split"] for row in splits} != {"train", "test"}:
                raise ValueError("Invalid split labels")
            if item["format"] != "turbine_csv":
                input_values = values[:, [headers.index(name) for name in item["inputs"]]]
                assignment = {}
                for row, split in zip(input_values, splits):
                    key = tuple(row)
                    if key in assignment and assignment[key] != split["split"]:
                        raise ValueError("Identical inputs leak across train/test")
                    assignment[key] = split["split"]
    report = {"status": "passed", "dataset_counts": counts, "primary_data_rows": observations,
              "dataset_files_verified": files, "checks": ["SHA-256", "unique headers", "finite numeric values",
              "source numeric round-trip during build", "profile consistency", "DAG acyclicity and node order",
              "Pareto membership and independent dominance check", "split row coverage and replicate isolation",
              "license checksums", "edge list and CPDAG consistency"],
              "not_run": ["MATLAB app modeling/causal algorithm scores", "MATLAB R2025b / Windows execution"]}
    write_json(ROOT / "validation.json", report)
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    if sys.version_info < (3, 14, 5):
        raise SystemExit("Python 3.14.5 or later is required")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="Audit included CSVs without network access")
    parser.add_argument("--cache", type=Path, default=Path(tempfile.gettempdir()) / "pit-public-benchmark-cache")
    arguments = parser.parse_args()
    if arguments.verify:
        verify()
    else:
        build(arguments.cache)

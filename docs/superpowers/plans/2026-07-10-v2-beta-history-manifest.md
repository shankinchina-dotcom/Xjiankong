# v2-beta history.json 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` task-by-task. Steps use checkbox syntax.

**Goal:** 在每次 HTML 报告生成后，从已存在的时间戳快照生成仅含公开 HTML 路径的 `output/history.json`，为历史抽屉和历史页提供真实版本列表。

**Architecture:** 在 `trendradar/report/generator.py` 增加纯文件系统 helper，扫描 `output/html/YYYY-MM-DD/HH-MM.html`，按日期和时间倒序产出 manifest；`generate_html_report()` 在写入当前快照后调用它。manifest 不解析 HTML、不访问网络、不查询数据库，也不保存运行时 `source_map`。

**Tech Stack:** Python 标准库（`json`、`pathlib`、`re`、`tempfile`／`os.replace`），现有可执行 fixture 测试风格。

## Global Constraints

- 只修改隔离 worktree 的 TrendRadar fork；主工作树中已有改动一律不触碰。
- 不改数据库 schema，不新增依赖，不访问 NAS、Docker、Cloudflare，不触发 AI。
- manifest 只能包含 `/html/YYYY-MM-DD/HH-MM.html` 形式的公开路径、日期、时间与 `is_latest`；不得包含 `.env`、DB、config、`source_map`、来源 URL 或 URL 可用性结果。
- 排除 `output/html/latest/` 和任何不符合日期目录／时间文件名正则的文件。
- 空快照目录仍需生成合法空 manifest，不能报错。
- 测试必须先失败，再写生产代码；本地验证产物不提交。

---

### Task 1: 生成并验证受控历史 manifest

**Files:**

- Modify: `trendradar/report/generator.py:1-8, 220-246`
- Create: `tests/fixtures/v2_beta_history_manifest.py`

**Interfaces:**

- Produces: `build_history_manifest(output_dir: str | Path) -> dict`
- Produces: `write_history_manifest(output_dir: str | Path) -> Path`
- Consumes: 快照文件布局 `output/html/YYYY-MM-DD/HH-MM.html`
- Output schema:

```json
{
  "schema_version": 1,
  "latest": {"date": "2026-07-10", "time": "20:00", "path": "/html/2026-07-10/20-00.html"},
  "dates": [
    {
      "date": "2026-07-10",
      "versions": [
        {"time": "20:00", "path": "/html/2026-07-10/20-00.html", "is_latest": true}
      ]
    }
  ]
}
```

- [ ] **Step 1: 写失败 fixture**

创建 `tests/fixtures/v2_beta_history_manifest.py`，用 `TemporaryDirectory` 建立以下快照：

```python
from pathlib import Path
from tempfile import TemporaryDirectory

from trendradar.report.generator import build_history_manifest, write_history_manifest


def write_snapshot(root: Path, date: str, time: str) -> None:
    target = root / "html" / date / f"{time}.html"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("<html></html>", encoding="utf-8")


def test_manifest_orders_versions_and_exposes_only_public_paths():
    with TemporaryDirectory() as temp:
        root = Path(temp)
        write_snapshot(root, "2026-07-09", "20-51")
        write_snapshot(root, "2026-07-10", "04-01")
        write_snapshot(root, "2026-07-10", "20-00")
        write_snapshot(root, "latest", "daily")
        (root / "html" / "2026-07-10" / "notes.txt").write_text("ignore", encoding="utf-8")

        manifest = build_history_manifest(root)

        assert manifest["schema_version"] == 1
        assert manifest["latest"] == {
            "date": "2026-07-10",
            "time": "20:00",
            "path": "/html/2026-07-10/20-00.html",
        }
        assert [day["date"] for day in manifest["dates"]] == ["2026-07-10", "2026-07-09"]
        assert [item["time"] for item in manifest["dates"][0]["versions"]] == ["20:00", "04:01"]
        assert manifest["dates"][0]["versions"][0]["is_latest"] is True
        assert all(item["path"].startswith("/html/") for day in manifest["dates"] for item in day["versions"])
        assert "latest" not in str(manifest)


def test_manifest_handles_no_snapshots_and_writes_json():
    with TemporaryDirectory() as temp:
        root = Path(temp)
        manifest_path = write_history_manifest(root)

        assert manifest_path == root / "history.json"
        assert manifest_path.is_file()
        assert manifest_path.read_text(encoding="utf-8") == '{\n  "schema_version": 1,\n  "latest": null,\n  "dates": []\n}\n'


if __name__ == "__main__":
    tests = [
        test_manifest_orders_versions_and_exposes_only_public_paths,
        test_manifest_handles_no_snapshots_and_writes_json,
    ]
    for test in tests:
        test()
        print(f"  ✓ {test.__name__}")
    print(f"\n✅ {len(tests)}/{len(tests)} 通过")
```

- [ ] **Step 2: 运行 fixture，确认因缺少 helper 而失败**

Run:

```bash
python tests/fixtures/v2_beta_history_manifest.py
```

Expected: 导入 `build_history_manifest`／`write_history_manifest` 失败；不能是 fixture 语法错误。

- [ ] **Step 3: 写最小实现**

在 `generator.py` 增加 `import json`、`import re`，并在 `generate_html_report()` 写完 `snapshot_file` 后、返回前调用 `write_history_manifest(output_dir)`。实现必须只匹配：日期 `^\d{4}-\d{2}-\d{2}$`、文件名 `^(\d{2})-(\d{2})\.html$`。

```python
DATE_DIR_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
TIME_FILE_RE = re.compile(r"(\d{2})-(\d{2})\.html")


def build_history_manifest(output_dir: str | Path) -> dict:
    root = Path(output_dir)
    html_root = root / "html"
    entries = []
    if html_root.is_dir():
        for date_dir in html_root.iterdir():
            if not date_dir.is_dir() or not DATE_DIR_RE.fullmatch(date_dir.name):
                continue
            for file_path in date_dir.iterdir():
                match = TIME_FILE_RE.fullmatch(file_path.name)
                if file_path.is_file() and match:
                    entries.append((date_dir.name, f"{match.group(1)}:{match.group(2)}"))

    entries.sort(reverse=True)
    latest = entries[0] if entries else None
    grouped = {}
    for date, time in entries:
        grouped.setdefault(date, []).append({
            "time": time,
            "path": f"/html/{date}/{time.replace(':', '-')}.html",
            "is_latest": (date, time) == latest,
        })
    return {
        "schema_version": 1,
        "latest": None if latest is None else {
            "date": latest[0], "time": latest[1],
            "path": f"/html/{latest[0]}/{latest[1].replace(':', '-')}.html",
        },
        "dates": [{"date": date, "versions": versions} for date, versions in grouped.items()],
    }


def write_history_manifest(output_dir: str | Path) -> Path:
    root = Path(output_dir)
    root.mkdir(parents=True, exist_ok=True)
    destination = root / "history.json"
    temporary = root / ".history.json.tmp"
    temporary.write_text(json.dumps(build_history_manifest(root), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(destination)
    return destination
```

- [ ] **Step 4: 运行 fixture，确认通过**

Run:

```bash
python tests/fixtures/v2_beta_history_manifest.py
```

Expected: 两个测试均通过；输出的 manifest 无非法文件名、内部文件或来源 URL。

- [ ] **Step 5: 做集成验证**

Run:

```bash
python -c "from trendradar.report.generator import write_history_manifest; from pathlib import Path; import json; p=write_history_manifest('output'); d=json.loads(Path(p).read_text(encoding='utf-8')); assert d['schema_version'] == 1; assert all(v['path'].startswith('/html/') for day in d['dates'] for v in day['versions']); print(p, len(d['dates']))"
```

Expected: `output/history.json` 生成成功；只报告路径与日期／时间。此本地验证产物不提交。

- [ ] **Step 6: 运行回归与检查工作树**

Run:

```bash
python tests/fixtures/v2_alpha_fixture.py
python tests/fixtures/v2_alpha_task3.py
git diff --check
git status --short
```

Expected: 既有 v2-alpha fixture 通过；仅 `generator.py` 和新 fixture 为预期代码改动，`output/history.json` 保持未提交。

- [ ] **Step 7: 提交隔离分支**

```bash
git add trendradar/report/generator.py tests/fixtures/v2_beta_history_manifest.py
git commit -m "feat: generate public history manifest"
```

Expected: 只包含 Gate 5 代码和 fixture；不包含 output、配置、Docker 或主工作树既有改动。

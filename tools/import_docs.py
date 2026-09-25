#!/usr/bin/env python3
"""Builds the app content (assets/content/library.json) from a folder of HR files.

Usage (Windows):
    py -m pip install python-docx pypdf openpyxl
    py tools\\import_docs.py "C:\\Users\\Alaa Helal\\Downloads\\لائحة تنظيم العمل و الجزاءات"

Supported: .docx, .pdf (text PDFs, not scanned images), .xlsx, .txt, .md.
Old .doc files must be re-saved as .docx from Word first.

Each file becomes one document. Its section (قسم) is chosen from keywords in
the file or folder name; see CATEGORIES below. Word files placed in a
"نماذج" folder (or with "نموذج" in the name) are also copied into
assets/forms so users can share/save them from the app.
"""

import argparse
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_JSON = ROOT / "assets" / "content" / "library.json"
FORMS_DIR = ROOT / "assets" / "forms"

# Order matters: the first category whose keyword appears in the path wins.
CATEGORIES = [
    {"id": "penalties", "title": "لائحة الجزاءات", "icon": "warning",
     "description": "المخالفات والجزاءات المقررة لها",
     "keywords": ["جزاء", "جزاءات", "مخالف", "تأديب", "تاديب"]},
    {"id": "forms", "title": "نماذج الموارد البشرية", "icon": "forms",
     "description": "نماذج جاهزة للطباعة والمشاركة",
     "keywords": ["نموذج", "نماذج", "استمارة", "form"]},
    {"id": "work_rules", "title": "لائحة تنظيم العمل", "icon": "rule",
     "description": "مواعيد العمل والإجازات والحقوق والواجبات",
     "keywords": ["لائحة", "لائحه", "تنظيم العمل", "نظام العمل"]},
    {"id": "procedures", "title": "دليل الإجراءات", "icon": "steps",
     "description": "خطوات تنفيذ عمليات الموارد البشرية",
     "keywords": ["اجراء", "إجراء", "اجراءات", "إجراءات", "دليل", "سياسة", "سياسات"]},
    {"id": "laws", "title": "التشريعات", "icon": "gavel",
     "description": "قانون العمل والقرارات الوزارية والتأمينات",
     "keywords": ["قانون", "تشريع", "قرار", "تأمين", "تامين", "لائحة تنفيذية"]},
]
DISPLAY_ORDER = ["laws", "work_rules", "penalties", "procedures", "forms", "other"]
OTHER = {"id": "other", "title": "مستندات أخرى", "icon": "book",
         "description": "", "keywords": []}

# Lines that start a new section: "مادة (5)", "المادة 5", "الباب الأول", "أولاً:" ...
HEADING_RE = re.compile(
    r"^\s*(ال)?(مادة|المادة|باب|الباب|فصل|الفصل|بند|البند|الفرع|القسم)\b"
    r"|^\s*(أولا|اولا|ثانيا|ثالثا|رابعا|خامسا|سادسا|سابعا|ثامنا|تاسعا|عاشرا)[ًً]?\s*[:\-–]"
    r"|^\s*(إجراء|اجراء|خطوة|الخطوة)\s*(رقم)?\s*[\d٠-٩]+"
)
MAX_SECTION = 4000


def categorize(path: Path, base: Path):
    rel = str(path.relative_to(base)).lower()
    for c in CATEGORIES:
        if any(k.lower() in rel for k in c["keywords"]):
            return c
    return OTHER


def clean(text: str) -> str:
    text = text.replace("\u00a0", " ").replace("\r", "")
    text = re.sub(r"[ \t]+", " ", text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


# ---------- readers: each returns a list of (is_heading, text) ----------

def read_docx(path: Path):
    import docx
    from docx.table import Table
    from docx.text.paragraph import Paragraph

    d = docx.Document(str(path))
    out = []
    for child in d.element.body.iterchildren():
        tag = child.tag.rsplit("}", 1)[-1]
        if tag == "p":
            p = Paragraph(child, d)
            t = p.text.strip()
            if not t:
                continue
            style = (p.style.name or "").lower() if p.style is not None else ""
            out.append((style.startswith("heading") or style == "title", t))
        elif tag == "tbl":
            rows = []
            for r in Table(child, d).rows:
                cells = []
                for c in r.cells:
                    ct = " ".join(c.text.split())
                    if ct and (not cells or cells[-1] != ct):  # merged cells repeat
                        cells.append(ct)
                if cells:
                    rows.append(" | ".join(cells))
            if rows:
                out.append((False, "\n".join(rows)))
    return out


def read_pdf(path: Path):
    from pypdf import PdfReader

    lines = []
    for page in PdfReader(str(path)).pages:
        lines += [(False, l) for l in (page.extract_text() or "").splitlines() if l.strip()]
    return lines


def read_xlsx(path: Path):
    import openpyxl

    wb = openpyxl.load_workbook(str(path), data_only=True, read_only=True)
    out = []
    for ws in wb.worksheets:
        out.append((True, ws.title))
        for row in ws.iter_rows(values_only=True):
            cells = [str(v).strip() for v in row if v is not None and str(v).strip()]
            if cells:
                out.append((False, " | ".join(cells)))
    return out


def read_text(path: Path):
    return [(l.startswith("#"), l.lstrip("# ").strip())
            for l in path.read_text(encoding="utf-8", errors="ignore").splitlines()
            if l.strip()]


READERS = {".docx": read_docx, ".pdf": read_pdf, ".xlsx": read_xlsx,
           ".txt": read_text, ".md": read_text}


def to_sections(blocks):
    sections, title, body = [], "", []

    def flush():
        text = clean("\n".join(body))
        if not text and not title:
            return
        # Very long sections are split so they stay readable on a phone.
        while len(text) > MAX_SECTION:
            cut = text.rfind("\n", 0, MAX_SECTION)
            cut = cut if cut > MAX_SECTION // 2 else MAX_SECTION
            sections.append({"title": title, "body": text[:cut].strip()})
            text = text[cut:].strip()
        sections.append({"title": title, "body": text})

    for is_heading, text in blocks:
        short = len(text) <= 120
        split = re.search(r"[:：\-–]\s*\S", text[:60])
        if HEADING_RE.match(text) and split and len(text) - split.end() > 30:
            # "الخطوة 1: نص طويل..." → title "الخطوة 1", body "نص طويل..."
            flush()
            head, rest = re.split(r"\s*[:：\-–]\s*", text, maxsplit=1)
            title, body = head.strip(), [rest]
        elif (is_heading and short) or (short and HEADING_RE.match(text)):
            flush()
            title, body = text, []
        else:
            body.append(text)
    flush()
    with_body = [s for s in sections if s["body"]]
    return with_body or sections


def doc_id(rel: str) -> str:
    return "d" + hashlib.md5(rel.encode("utf-8")).hexdigest()[:10]


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder", help="المجلد الذي يحتوي على ملفات الموارد البشرية")
    args = ap.parse_args()
    base = Path(args.folder).expanduser().resolve()
    if not base.is_dir():
        sys.exit(f"المجلد غير موجود: {base}")

    FORMS_DIR.mkdir(parents=True, exist_ok=True)
    for old in FORMS_DIR.iterdir():
        if old.is_file() and old.name != ".gitkeep":
            old.unlink()

    documents, used, skipped = [], set(), []
    for path in sorted(base.rglob("*")):
        if not path.is_file() or path.name.startswith(("~$", ".")):
            continue
        ext = path.suffix.lower()
        rel = str(path.relative_to(base))
        if ext not in READERS:
            skipped.append(rel)
            continue
        try:
            sections = to_sections(READERS[ext](path))
        except Exception as e:  # keep going; report at the end
            skipped.append(f"{rel} ({e})")
            continue
        cat = categorize(path, base)
        used.add(cat["id"])
        did = doc_id(rel)
        doc = {"id": did, "category": cat["id"], "title": path.stem.strip(),
               "summary": path.parent.name if path.parent != base else "",
               "sections": sections}
        if cat["id"] == "forms" and ext in (".docx", ".xlsx", ".pdf"):
            name = f"{did}{ext}"
            shutil.copy2(path, FORMS_DIR / name)
            doc["file"] = f"forms/{name}"
        if not sections and "file" not in doc:
            skipped.append(f"{rel} (بدون نص — ربما ملف ممسوح ضوئياً)")
            continue
        documents.append(doc)
        print(f"✓ [{cat['title']}] {rel} — {len(sections)} فقرة")

    cats = [{k: c[k] for k in ("id", "title", "icon", "description")}
            for c in sorted(CATEGORIES + [OTHER],
                            key=lambda c: DISPLAY_ORDER.index(c["id"]))
            if c["id"] in used]
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps({"categories": cats, "documents": documents},
                                   ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\nتم: {len(documents)} مستند في {len(cats)} قسم → {OUT_JSON}")
    if skipped:
        print("\nملفات لم يتم استيرادها:")
        for s in skipped:
            print("  - " + s)


if __name__ == "__main__":
    main()

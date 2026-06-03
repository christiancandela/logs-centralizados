#!/usr/bin/env python3
"""Prepara las fuentes del libro a partir de los .md canónicos (NO los modifica).

Dos transformaciones, solo para la compilación del libro (salida en _generated/,
ignorada por git):

1. Trocea readme.md en capítulos coherentes (Parte I "Documento base" + apéndice
   de referencias), descartando la portada y el cierre cita/licencia.
2. Convierte los "GitHub Alerts" (> [!NOTE], > [!WARNING], …) — que GitHub
   renderiza nativamente — en callouts de Quarto (::: {.callout-note}), que en el
   PDF se renderizan como cajas con etiqueta. Se aplica a los capítulos del readme
   y a copias de las guías y la guía docente.

Se ejecuta antes de `quarto render` (ver Makefile y el workflow de release).
"""

import os
import re
import shutil
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(SCRIPT_DIR, "..", ".."))
README = os.path.join(ROOT, "readme.md")
OUTDIR = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "_generated"))

SECTION_RE = re.compile(r"^##\s+(\d+)\.\s+(.*)$")
HEADING_RE = re.compile(r"^(#{3,6})(\s.*)$")  # niveles 3-6, para degradar
FENCE_RE = re.compile(r"^\s*```")

# (archivo, título del capítulo, [secciones], modo, ancla)
CHAPTERS = [
    ("01-introduccion-objetivos.qmd", "Introducción, justificación y objetivos", [1, 2, 3], "group", None),
    ("02-metodologia.qmd", None, [4], "promote", None),
    ("03-marco-conceptual.qmd", "Marco conceptual", [5], "promote", "sec-marco-conceptual"),
    ("04-alcance-conclusiones.qmd", "Alcance, articulación y conclusiones", [6, 7, 8], "group", None),
    ("99-referencias.qmd", None, [9], "promote", None),
]

# Guías y material docente que se copian (con conversión de alerts) a _generated/.
GUIDES = [
    "elk-guide", "olo-guide", "fluentd-guide", "promtail-guide", "gelf-graylog-guide",
    "otel-guide", "vector-guide", "signoz-guide", "alloy-guide",
]
DOCS = ["guia_estudio", "guia_docente"]

ALERT_MAP = {"NOTE": "note", "TIP": "tip", "IMPORTANT": "important",
             "WARNING": "warning", "CAUTION": "caution"}


def convert_alerts(text):
    """Convierte bloques '> [!TIPO] …' (GitHub Alerts) en '::: {.callout-tipo} … :::'."""
    lines, out, i, in_code = text.split("\n"), [], 0, False
    while i < len(lines):
        if FENCE_RE.match(lines[i]):
            in_code = not in_code
            out.append(lines[i]); i += 1; continue
        m = None if in_code else re.match(r"^>\s*\[!(\w+)\]\s*$", lines[i])
        if m and m.group(1).upper() in ALERT_MAP:
            i += 1
            body = []
            while i < len(lines) and lines[i].startswith(">"):
                body.append(re.sub(r"^>\s?", "", lines[i])); i += 1
            out.append(f"::: {{.callout-{ALERT_MAP[m.group(1).upper()]}}}")
            out.extend(body)
            out.append(":::")
        else:
            out.append(lines[i]); i += 1
    return "\n".join(out)


def parse_sections(lines):
    start = next((i for i, l in enumerate(lines) if SECTION_RE.match(l)), None)
    if start is None:
        sys.exit("ERROR: no se encontró ninguna sección '## N.' en readme.md")
    sections, cur = {}, None
    for line in lines[start:]:
        m = SECTION_RE.match(line)
        if m:
            cur = int(m.group(1))
            sections[cur] = {"title": m.group(2).strip(), "lines": [line]}
        elif cur is not None:
            sections[cur]["lines"].append(line)
    return sections


def demote_body(body_lines):
    out, in_code = [], False
    for line in body_lines:
        if FENCE_RE.match(line):
            in_code = not in_code; out.append(line); continue
        if not in_code:
            m = HEADING_RE.match(line)
            if m:
                out.append(m.group(1)[1:] + m.group(2)); continue
        out.append(line)
    return out


def build_chapter(title, nums, mode, anchor, sections):
    suffix = f" {{#{anchor}}}" if anchor else ""
    if mode == "group":
        body = [f"# {title}{suffix}", ""]
        for n in nums:
            body += sections[n]["lines"] + [""]
        content = "\n".join(body)
    else:  # promote
        sec = sections[nums[0]]
        chapter_title = title if title else sec["title"]
        rest = demote_body(sec["lines"][1:])
        content = "\n".join([f"# {chapter_title}{suffix}", ""] + rest)
    return convert_alerts(content).rstrip() + "\n"


def main():
    os.makedirs(os.path.join(OUTDIR, "guias"), exist_ok=True)

    # 1. Trocear readme en capítulos (con conversión de alerts)
    with open(README, encoding="utf-8") as f:
        sections = parse_sections(f.read().splitlines())
    for fname, title, nums, mode, anchor in CHAPTERS:
        missing = [n for n in nums if n not in sections]
        if missing:
            sys.exit(f"ERROR: faltan secciones {missing} para {fname}")
        with open(os.path.join(OUTDIR, fname), "w", encoding="utf-8") as f:
            f.write(build_chapter(title, nums, mode, anchor, sections))
        print(f"  ✓ {fname}  (§{','.join(map(str, nums))})")

    # 2. Copiar guías y material docente con conversión de alerts
    for g in GUIDES:
        src = os.path.join(ROOT, "guias", f"{g}.md")
        dst = os.path.join(OUTDIR, "guias", f"{g}.md")
        with open(src, encoding="utf-8") as fi, open(dst, "w", encoding="utf-8") as fo:
            fo.write(convert_alerts(fi.read()))
    for d in DOCS:
        src = os.path.join(ROOT, f"{d}.md")
        dst = os.path.join(OUTDIR, f"{d}.md")
        with open(src, encoding="utf-8") as fi, open(dst, "w", encoding="utf-8") as fo:
            fo.write(convert_alerts(fi.read()))
    print(f"  ✓ {len(GUIDES)} guías + {len(DOCS)} documentos copiados a _generated/ (alerts→callouts)")
    print(f"Listo. Salida en {OUTDIR}")


if __name__ == "__main__":
    main()

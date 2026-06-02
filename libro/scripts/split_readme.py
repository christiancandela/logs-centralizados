#!/usr/bin/env python3
"""Trocea readme.md en capítulos para el libro (NO modifica el readme).

El readme.md es la fuente única y canónica (válida como documento autónomo en
GitHub/Zenodo). Este script lo descompone, solo para la compilación del libro,
en capítulos coherentes dentro de la Parte I "Documento base" + un apéndice de
referencias. Se ejecuta antes de `quarto render`. La salida vive en
libro/_generated/ (derivada, ignorada por git).

Mapeo (decidido editorialmente):
  - Cap. 1  Introducción, justificación y objetivos   <- §1, §2, §3
  - Cap. 2  Metodología de Construcción...             <- §4
  - Cap. 3  Marco conceptual                            <- §5 (Desarrollo de la temática)
  - Cap. 4  Alcance, articulación y conclusiones        <- §6, §7, §8
  - Apéndice  Referencias bibliográficas                <- §9
  - Se omiten en el libro: §10 (Cómo citar) y §11 (Licencia) — ya están en
    la portada/colofón del libro.
"""

import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
README = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "..", "readme.md"))
OUTDIR = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "_generated"))

SECTION_RE = re.compile(r"^##\s+(\d+)\.\s+(.*)$")
HEADING_RE = re.compile(r"^(#{3,6})(\s.*)$")  # solo niveles 3-6, para degradar
FENCE_RE = re.compile(r"^\s*```")

# (archivo, título del capítulo, [secciones], modo, ancla)
#   modo "group":   antepone un H1 nuevo y conserva los §N como subsecciones (##)
#   modo "promote": el capítulo ES una sección; promueve su ## a # y degrada el resto
#   ancla: identificador estable {#id} para referencias cruzadas (o None)
CHAPTERS = [
    ("01-introduccion-objetivos.qmd", "Introducción, justificación y objetivos", [1, 2, 3], "group", None),
    ("02-metodologia.qmd", None, [4], "promote", None),                 # título tomado de §4
    ("03-marco-conceptual.qmd", "Marco conceptual", [5], "promote", "sec-marco-conceptual"),
    ("04-alcance-conclusiones.qmd", "Alcance, articulación y conclusiones", [6, 7, 8], "group", None),
    ("99-referencias.qmd", None, [9], "promote", None),                 # título tomado de §9
]


def parse_sections(lines):
    """Devuelve {num: {'title': str, 'lines': [str...]}} desde el primer '## 1.'."""
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
    """Degrada en uno los encabezados de nivel 3-6 fuera de bloques de código."""
    out, in_code = [], False
    for line in body_lines:
        if FENCE_RE.match(line):
            in_code = not in_code
            out.append(line)
            continue
        if not in_code:
            m = HEADING_RE.match(line)
            if m:
                out.append(m.group(1)[1:] + m.group(2))  # un '#' menos
                continue
        out.append(line)
    return out


def build_chapter(title, nums, mode, anchor, sections):
    suffix = f" {{#{anchor}}}" if anchor else ""
    if mode == "group":
        body = [f"# {title}{suffix}", ""]
        for n in nums:
            body += sections[n]["lines"] + [""]
        return "\n".join(body).rstrip() + "\n"
    # promote: una sola sección
    sec = sections[nums[0]]
    chapter_title = title if title else sec["title"]
    rest = demote_body(sec["lines"][1:])  # omite la línea '## N. ...' original
    return "\n".join([f"# {chapter_title}{suffix}", ""] + rest).rstrip() + "\n"


def main():
    with open(README, encoding="utf-8") as f:
        lines = f.read().splitlines()
    sections = parse_sections(lines)
    os.makedirs(OUTDIR, exist_ok=True)
    for fname, title, nums, mode, anchor in CHAPTERS:
        missing = [n for n in nums if n not in sections]
        if missing:
            sys.exit(f"ERROR: faltan secciones {missing} para {fname}")
        content = build_chapter(title, nums, mode, anchor, sections)
        path = os.path.join(OUTDIR, fname)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        shown = title or sections[nums[0]]["title"]
        print(f"  ✓ {fname}  (§{','.join(map(str, nums))})  → {shown[:50]}")
    print(f"Generados {len(CHAPTERS)} archivos en {OUTDIR}")


if __name__ == "__main__":
    main()

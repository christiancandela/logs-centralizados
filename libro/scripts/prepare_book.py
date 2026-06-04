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


def load_bib_keys():
    """Carga las claves de citación desde references.bib."""
    bib_path = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "references.bib"))
    if not os.path.exists(bib_path):
        sys.exit(f"ERROR: no se encontró el archivo de bibliografía en {bib_path}")
    keys = set()
    with open(bib_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("@"):
                m = re.match(r"@\w+\s*\{\s*([^,\s]+),", line)
                if m:
                    keys.add(m.group(1).lower())
    return keys


def convert_citations(text, bib_keys):
    """Busca citas parentéticas del tipo (Autor, Año) y las reemplaza por claves de Pandoc [@clave]."""
    def replacer(match):
        inside = match.group(1)
        
        # Si no hay un año de 4 dígitos (19XX o 20XX), no es una cita
        years = re.findall(r'\b(19\d{2}|20\d{2})\b', inside)
        if not years:
            return match.group(0)
            
        parts = inside.split(';')
        converted_parts = []
        for part in parts:
            part_clean = part.strip()
            year_match = re.search(r'\b(19\d{2}|20\d{2})\b', part_clean)
            if not year_match:
                converted_parts.append(part_clean)
                continue
            year = year_match.group(1)
            
            # Buscar palabras alfabéticas
            words = re.findall(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ]+', part_clean)
            found_key = None
            accents = {
                'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
                'ñ': 'n', 'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u', 'Ñ': 'n'
            }
            for word in words:
                key_candidate = f"{word.lower()}-{year}"
                for char, replacement in accents.items():
                    key_candidate = key_candidate.replace(char, replacement)
                if key_candidate in bib_keys:
                    found_key = key_candidate
                    break
                    
            if found_key:
                converted_parts.append(f"@{found_key}")
            else:
                # Alerta si parece una cita pero no está en la base de datos de referencias
                is_likely_citation = re.search(r'[A-Z][a-zA-Z]*.*,\s*\d{4}', part_clean)
                if is_likely_citation:
                    print(f"WARNING: Cita no resuelta en references.bib: '{part_clean}'", file=sys.stderr)
                converted_parts.append(part_clean)
                
        has_any_key = any(p.startswith('@') for p in converted_parts)
        if has_any_key:
            return "[" + "; ".join(converted_parts) + "]"
        else:
            return match.group(0)
    return re.sub(r'\(([^)]+)\)', replacer, text)


def convert_mermaid(text):
    """Convierte bloques '```mermaid' en '```{mermaid}' para que Quarto los procese nativamente."""
    return re.sub(r'^\s*```\s*mermaid\b', '```{mermaid}', text, flags=re.MULTILINE)


def main():
    os.makedirs(os.path.join(OUTDIR, "guias"), exist_ok=True)
    bib_keys = load_bib_keys()

    # 1. Trocear readme en capítulos (con conversión de alerts, citas y mermaid)
    with open(README, encoding="utf-8") as f:
        sections = parse_sections(f.read().splitlines())
    for fname, title, nums, mode, anchor in CHAPTERS:
        if fname == "99-referencias.qmd":
            # Output nativo de referencias para Quarto
            with open(os.path.join(OUTDIR, fname), "w", encoding="utf-8") as f:
                f.write("# Referencias bibliográficas {.unnumbered}\n\n::: {#refs}\n:::\n")
            print(f"  ✓ {fname}  (native refs placeholder)")
            continue

        missing = [n for n in nums if n not in sections]
        if missing:
            sys.exit(f"ERROR: faltan secciones {missing} para {fname}")
        
        chapter_content = build_chapter(title, nums, mode, anchor, sections)
        converted_content = convert_citations(chapter_content, bib_keys)
        converted_content = convert_mermaid(converted_content)
        
        with open(os.path.join(OUTDIR, fname), "w", encoding="utf-8") as f:
            f.write(converted_content)
        print(f"  ✓ {fname}  (§{','.join(map(str, nums))})")

    # 2. Copiar guías y material docente con conversión de alerts, citas y mermaid
    for g in GUIDES:
        src = os.path.join(ROOT, "guias", f"{g}.md")
        dst = os.path.join(OUTDIR, "guias", f"{g}.md")
        with open(src, encoding="utf-8") as fi, open(dst, "w", encoding="utf-8") as fo:
            content = convert_alerts(fi.read())
            content = convert_citations(content, bib_keys)
            fo.write(convert_mermaid(content))
    for d in DOCS:
        src = os.path.join(ROOT, f"{d}.md")
        dst = os.path.join(OUTDIR, f"{d}.md")
        with open(src, encoding="utf-8") as fi, open(dst, "w", encoding="utf-8") as fo:
            content = convert_alerts(fi.read())
            content = convert_citations(content, bib_keys)
            fo.write(convert_mermaid(content))
    print(f"  ✓ {len(GUIDES)} guías + {len(DOCS)} documentos copiados a _generated/ (alerts→callouts, citations, mermaid)")
    print(f"Listo. Salida en {OUTDIR}")


if __name__ == "__main__":
    main()

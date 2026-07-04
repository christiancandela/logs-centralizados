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
    ("02-metodologia.qmd", None, [4], "promote", "sec-metodologia"),
    ("03-marco-conceptual.qmd", "Marco conceptual", [5], "promote", "sec-marco-conceptual"),
    ("04-alcance-articulacion.qmd", "Alcance y articulación con las actividades prácticas", [6, 7], "group", None),
    ("05-resultados.qmd", None, [8], "promote", "sec-resultados"),
    ("06-discusion.qmd", None, [9], "promote", "sec-discusion"),
    ("07-conclusiones.qmd", None, [10], "promote", "sec-conclusiones"),
    ("08-trabajo-futuro.qmd", None, [11], "promote", "sec-trabajo-futuro"),
    ("99-referencias.qmd", None, [12], "promote", None),
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


TABLE_CAPTION_RE = re.compile(r"^\*\*Tabla (\d+)\.\*\*\s*(.*\S)\s*$")


def convert_table_captions(text, prefix):
    """Convierte los rótulos manuales '**Tabla N.** Título' (colocados antes de
    cada tabla en los .md canónicos, donde GitHub los renderiza como texto en
    negrita) en captions nativos de Quarto (': Título {#tbl-...}', colocados
    después de la tabla). Quarto numera entonces las tablas por capítulo
    ('Tabla 2.1.') igual que las figuras. Las referencias textuales 'Tabla N'
    del mismo documento se convierten en referencias cruzadas '@tbl-...' con
    hiperenlace y numeración real del PDF."""
    lines, out, i, in_code = text.split("\n"), [], 0, False
    mapping = {}
    while i < len(lines):
        if FENCE_RE.match(lines[i]):
            in_code = not in_code
            out.append(lines[i]); i += 1; continue
        m = None if in_code else TABLE_CAPTION_RE.match(lines[i])
        if m:
            j = i + 1
            while j < len(lines) and lines[j].strip() == "":
                j += 1
            if j < len(lines) and lines[j].lstrip().startswith("|"):
                num, caption = m.group(1), m.group(2)
                label = f"tbl-{prefix}-{num}"
                mapping[num] = label
                k = j
                while k < len(lines) and lines[k].lstrip().startswith("|"):
                    out.append(lines[k]); k += 1
                out.append("")
                out.append(f": {caption} {{#{label}}}")
                i = k
                continue
        out.append(lines[i]); i += 1

    # Referencias textuales 'Tabla N' -> '@tbl-...' (solo números con caption
    # definido en este mismo documento y solo fuera de bloques de código).
    result, in_code = [], False
    ref_re = re.compile(r"\bTabla (\d+)\b")
    for line in out:
        if FENCE_RE.match(line):
            in_code = not in_code
            result.append(line)
            continue
        if not in_code and not line.lstrip().startswith(": "):
            line = ref_re.sub(
                lambda m: f"@{mapping[m.group(1)]}" if m.group(1) in mapping else m.group(0),
                line,
            )
        result.append(line)
    return "\n".join(result)


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


ACCENT_MAP = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n',
    'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u', 'Ñ': 'n',
}


def _strip_accents(s):
    for char, repl in ACCENT_MAP.items():
        s = s.replace(char, repl)
    return s


# Cadena de apellidos: tokens que inician en mayúscula, unidos por separadores de
# autoría (coma, &, "y", "and") o un espacio, admitiendo "et al.".
_NAME = r"[A-ZÁÉÍÓÚÑ][A-Za-zÁÉÍÓÚÑáéíóúñ.'’-]*"
_AUTHOR_CHAIN = (
    rf"{_NAME}(?:(?:,\s*|\s+&\s+|\s+y\s+|\s+and\s+|\s+)(?:et\s+al\.|{_NAME}))*"
)
NARRATIVE_CITE_RE = re.compile(rf"({_AUTHOR_CHAIN})\s*\((19\d{{2}}|20\d{{2}})\)")


def convert_narrative_citations(text, bib_keys):
    """Convierte citas narrativas 'Autor (Año)' (con el autor FUERA del paréntesis)
    en la forma narrativa de Pandoc '@clave', que citeproc renderiza como 'Autor (Año)'.

    Solo actúa cuando la clave resultante existe en references.bib; de este modo, los
    patrones que parezcan citas pero no lo sean (p. ej. 'la versión (2024)') se dejan
    intactos. La cadena de autores exige tokens que inician en mayúscula, lo que evita
    capturar palabras minúsculas previas (p. ej. en 'permite a Lamport (1978)' solo se
    captura 'Lamport').
    """
    def replacer(match):
        author_blob, year = match.group(1), match.group(2)
        for word in re.findall(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]+', author_blob):
            key = _strip_accents(f"{word.lower()}-{year}")
            if key in bib_keys:
                return f"@{key}"
        return match.group(0)
    return NARRATIVE_CITE_RE.sub(replacer, text)


def convert_citations(text, bib_keys):
    """Reemplaza las citas por claves de Pandoc: primero las narrativas 'Autor (Año)'
    por '@clave', y luego las parentéticas '(Autor, Año)' por '[@clave]'."""
    text = convert_narrative_citations(text, bib_keys)

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


def _sec_label(num):
    """'5.7.3' -> 'sec-5-7-3' (etiqueta Quarto de la sección del marco conceptual)."""
    return "sec-" + num.replace(".", "-")


def inject_section_ids(text):
    """Inyecta identificadores Quarto '{#sec-N-N}' en los encabezados numerados del
    capítulo del marco conceptual, para que las referencias cruzadas puedan apuntar a
    ellos. La numeración manual visible la elimina después clean-headers.lua; el id
    permanece y Quarto renumera de forma automática."""
    out, in_code = [], False
    for line in text.split("\n"):
        if FENCE_RE.match(line):
            in_code = not in_code
            out.append(line)
            continue
        m = None if in_code else re.match(r'^(#{2,6})\s+(\d+(?:\.\d+)+)\s+(.+?)\s*$', line)
        if m and "{#" not in line:
            out.append(f"{m.group(1)} {m.group(2)} {m.group(3)} {{#{_sec_label(m.group(2))}}}")
        else:
            out.append(line)
    return "\n".join(out)


# Referencias a secciones del marco conceptual (siempre numeradas '5.x'):
#   '§5.7.3', '§§5.7.1 y 5.6', 'sección 5.6', 'secciones 5.7.1 y 5.7.2'.
# Se reemplazan por la referencia cruzada Quarto '@sec-5-7-3', que Quarto renderiza
# como 'Sección 3.7.3' (el número REAL del PDF, distinto del .md) con hiperenlace.
# La palabra clave en minúscula ('sección') se descarta para no duplicar el prefijo
# 'Sección' que aporta la propia referencia cruzada. Solo actúa sobre números '5.x',
# de modo que las referencias internas de las guías (p. ej. 'sección 7.1') quedan intactas.
_SEC_NUM = r'5(?:\.\d+)+'
_SECREF_KW_RE = re.compile(rf'\bsecci[oó]n(?:es)?\s+{_SEC_NUM}(?:\s+y\s+{_SEC_NUM})?')
_SECREF_SIGN_RE = re.compile(rf'§§?\s*{_SEC_NUM}(?:\s+y\s+{_SEC_NUM})?')


def convert_section_refs(text):
    """Convierte las referencias textuales a secciones del marco conceptual en
    referencias cruzadas Quarto (@sec-...). Ver la nota anterior."""
    def repl(m):
        nums = re.findall(_SEC_NUM, m.group(0))
        return " y ".join(f"@{_sec_label(n)}" for n in nums)
    text = _SECREF_KW_RE.sub(repl, text)
    text = _SECREF_SIGN_RE.sub(repl, text)
    return text


def main():
    os.makedirs(os.path.join(OUTDIR, "guias"), exist_ok=True)
    bib_keys = load_bib_keys()

    # 1. Trocear readme en capítulos (con conversión de alerts, citas y mermaid)
    with open(README, encoding="utf-8") as f:
        readme_text = convert_table_captions(f.read(), "base")
    sections = parse_sections(readme_text.splitlines())
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
        if anchor == "sec-marco-conceptual":
            chapter_content = inject_section_ids(chapter_content)
        converted_content = convert_citations(chapter_content, bib_keys)
        converted_content = convert_section_refs(converted_content)
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
            content = convert_table_captions(content, g.replace("-guide", ""))
            content = convert_citations(content, bib_keys)
            content = convert_section_refs(content)
            fo.write(convert_mermaid(content))
    DOC_PREFIX = {"guia_estudio": "ge", "guia_docente": "gd"}
    for d in DOCS:
        src = os.path.join(ROOT, f"{d}.md")
        dst = os.path.join(OUTDIR, f"{d}.md")
        with open(src, encoding="utf-8") as fi, open(dst, "w", encoding="utf-8") as fo:
            content = convert_alerts(fi.read())
            content = convert_table_captions(content, DOC_PREFIX.get(d, d))
            content = convert_citations(content, bib_keys)
            content = convert_section_refs(content)
            fo.write(convert_mermaid(content))
    print(f"  ✓ {len(GUIDES)} guías + {len(DOCS)} documentos copiados a _generated/ (alerts→callouts, citations, mermaid)")
    print(f"Listo. Salida en {OUTDIR}")


if __name__ == "__main__":
    main()

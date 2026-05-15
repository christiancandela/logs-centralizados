#!/usr/bin/env python3
"""Reemplaza el DOI y la versión del recurso en los archivos del repositorio."""

import re
import sys

if len(sys.argv) != 3:
    print("Uso: update_doi.py <nuevo_doi> <tag>", file=sys.stderr)
    print("  Ejemplo: update_doi.py 10.5281/zenodo.12345678 v1.0.2", file=sys.stderr)
    sys.exit(1)

new_doi = sys.argv[1]
tag = sys.argv[2]
new_version = tag.lstrip("v")   # "v1.0.2" → "1.0.2"

OLD_DOI_PATTERN = re.compile(r"10\.5281/zenodo\.\d+")

# Patrones de versión del recurso (no afectan versiones de librerías como 1.5.18)
VERSION_PATTERNS = [
    # (Versión 1.0.0)  →  citas APA en .md y .qmd
    (re.compile(r"\(Versión \d+\.\d+\.\d+\)"), f"(Versión {new_version})"),
    # version      = {1.0.0}  →  BibTeX en readme.md
    (re.compile(r"(version\s*=\s*\{)\d+\.\d+\.\d+(\})"), rf"\g<1>{new_version}\2"),
    # version: 1.0.0  →  CITATION.cff (evita cff-version: 1.2.0)
    (re.compile(r"^version: \d+\.\d+\.\d+", re.MULTILINE), f"version: {new_version}"),
    # **Versión:** 1.0.0 ·  →  encabezado de readme.md
    (re.compile(r"(\*\*Versión:\*\* )\d+\.\d+\.\d+"), rf"\g<1>{new_version}"),
]

FILES = [
    "readme.md",
    "CITATION.cff",
    "guia_docente.md",
    "libro/index.qmd",
]

for filepath in FILES:
    try:
        with open(filepath, encoding="utf-8") as f:
            original = f.read()
    except FileNotFoundError:
        print(f"  — {filepath} no encontrado, omitido")
        continue

    updated = OLD_DOI_PATTERN.sub(new_doi, original)
    for pattern, replacement in VERSION_PATTERNS:
        updated = pattern.sub(replacement, updated)

    if updated != original:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(updated)
        print(f"  ✓ {filepath}")
    else:
        print(f"  — {filepath} sin cambios")

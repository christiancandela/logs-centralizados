#!/usr/bin/env python3
"""Reemplaza el DOI de Zenodo en readme.md y CITATION.cff con el nuevo valor."""

import re
import sys

if len(sys.argv) != 2:
    print("Uso: update_doi.py <nuevo_doi>", file=sys.stderr)
    sys.exit(1)

new_doi = sys.argv[1]
OLD_DOI_PATTERN = re.compile(r"10\.5281/zenodo\.\d+")
FILES = ["readme.md", "CITATION.cff"]

for filepath in FILES:
    with open(filepath, encoding="utf-8") as f:
        original = f.read()
    updated = OLD_DOI_PATTERN.sub(new_doi, original)
    if updated != original:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(updated)
        count = len(OLD_DOI_PATTERN.findall(original))
        print(f"  ✓ {filepath} — {count} referencia(s) actualizada(s)")
    else:
        print(f"  — {filepath} sin cambios")

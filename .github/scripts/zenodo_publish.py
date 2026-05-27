#!/usr/bin/env python3
"""Publica una nueva versión del recurso en Zenodo vía API REST (InvenioRDM).

Los metadatos (autores, título, keywords, licencia, descripción) se leen
directamente de CITATION.cff para mantener una única fuente de la verdad.
Solo quedan hardcodeados los campos que CFF no contempla: resource_type y
languages.
"""

import json
import os
import sys
import urllib.error
import urllib.request
from datetime import date

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml no está disponible. Ejecuta: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

TOKEN = os.environ["ZENODO_TOKEN"]
RECORD_ID = "20187576"
TAG = os.environ["TAG"]
VERSION = TAG.lstrip("v")
PDF_PATH = os.environ["PDF_PATH"]
PDF_NAME = os.path.basename(PDF_PATH)
ZIP_PATH = os.environ["ZIP_PATH"]
ZIP_NAME = os.path.basename(ZIP_PATH)
BASE_URL = "https://zenodo.org/api"


def load_cff(path="CITATION.cff"):
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def map_author(author):
    """Convierte una entrada de autor CFF al formato de creador de Zenodo."""
    # CFF usa guión para separar apellidos compuestos (Candela-Uribe → Candela Uribe)
    family = author["family-names"].replace("-", " ")
    given = author["given-names"]
    person = {"type": "personal", "family_name": family, "given_name": given}
    if "orcid" in author:
        orcid_id = author["orcid"].replace("https://orcid.org/", "")
        person["identifiers"] = [{"scheme": "orcid", "identifier": orcid_id}]
    result = {"person_or_org": person}
    if "affiliation" in author:
        result["affiliations"] = [{"name": author["affiliation"]}]
    return result


def build_metadata(cff):
    repo_url = f"https://github.com/christiancandela/logs-centralizados/tree/{TAG}"
    description_html = cff["abstract"].strip() + f"<br><br><strong>Available in:</strong> <a href=\"{repo_url}\">{repo_url}</a>"
    return {
        "metadata": {
            # Zenodo-specific: no tiene equivalente directo en CFF
            "resource_type": {"id": "publication-other"},
            "languages": [{"id": "spa"}],
            # Derivados de CITATION.cff
            "title": cff["title"].strip(),
            "version": VERSION,
            "publication_date": str(date.today()),
            "creators": [map_author(a) for a in cff["authors"]],
            "description": description_html,
            "rights": [{"id": cff["license"].lower()}],
            "subjects": [{"subject": kw} for kw in cff["keywords"]],
            "publisher": cff["institution"]["name"],
            "related_identifiers": [
                {
                    "identifier": repo_url,
                    "relation_type": {"id": "issupplementto"},
                    "scheme": "url"
                }
            ],
        }
    }


def api(method, path, *, data=None, binary=False):
    url = f"{BASE_URL}{path}"
    headers = {"Authorization": f"Bearer {TOKEN}"}
    if data is not None and not binary:
        data = json.dumps(data).encode()
        headers["Content-Type"] = "application/json"
    elif binary:
        headers["Content-Type"] = "application/octet-stream"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"ERROR {e.code} — {method} {url}\n{body}", file=sys.stderr)
        sys.exit(1)


def upload_file(draft_id, path, name):
    print(f"  Subiendo {name}...")
    api("POST", f"/records/{draft_id}/draft/files", data=[{"key": name}])
    with open(path, "rb") as f:
        data = f.read()
    api("PUT", f"/records/{draft_id}/draft/files/{name}/content", data=data, binary=True)
    api("POST", f"/records/{draft_id}/draft/files/{name}/commit")
    print(f"  ✓ {name}")


# ── Leer metadatos desde CITATION.cff ────────────────────────────────────────
print("→ Leyendo metadatos desde CITATION.cff...")
cff = load_cff()
metadata = build_metadata(cff)
print(f"  Título:  {metadata['metadata']['title']}")
print(f"  Versión: {VERSION}")
print(f"  Autores: {len(cff['authors'])}")

# ── 1. Crear nueva versión ────────────────────────────────────────────────────
print(f"\n→ Creando nueva versión {VERSION} en Zenodo...")
draft = api("POST", f"/records/{RECORD_ID}/versions")
draft_id = draft["id"]
print(f"  Draft ID: {draft_id}")

# ── 2. Eliminar archivos heredados ────────────────────────────────────────────
print("→ Eliminando archivos heredados...")
files = api("GET", f"/records/{draft_id}/draft/files")
for entry in files.get("entries", []):
    fname = entry["key"]
    api("DELETE", f"/records/{draft_id}/draft/files/{fname}")
    print(f"  Eliminado: {fname}")

# ── 3. Subir archivos ─────────────────────────────────────────────────────────
print("→ Subiendo archivos...")
upload_file(draft_id, PDF_PATH, PDF_NAME)
upload_file(draft_id, ZIP_PATH, ZIP_NAME)

# ── 4. Actualizar metadatos ───────────────────────────────────────────────────
print("→ Actualizando metadatos...")
api("PUT", f"/records/{draft_id}/draft", data=metadata)
print("  ✓ Metadatos aplicados desde CITATION.cff")

# ── 5. Publicar ───────────────────────────────────────────────────────────────
print("→ Publicando...")
result = api("POST", f"/records/{draft_id}/draft/actions/publish")
doi = result.get("doi", "N/A")
rec_id = result.get("id", draft_id)
print(f"  ✓ Publicado correctamente")
print(f"  DOI: {doi}")
print(f"  URL: https://zenodo.org/records/{rec_id}")

# ── Exportar DOI para pasos siguientes del workflow ───────────────────────────
github_output = os.environ.get("GITHUB_OUTPUT")
if github_output:
    with open(github_output, "a") as f:
        f.write(f"doi={doi}\n")

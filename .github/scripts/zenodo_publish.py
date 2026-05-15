#!/usr/bin/env python3
"""Publica una nueva versión del recurso en Zenodo vía API REST (InvenioRDM)."""

import json
import os
import sys
import urllib.error
import urllib.request
from datetime import date

TOKEN = os.environ["ZENODO_TOKEN"]
RECORD_ID = "20187576"
TAG = os.environ["TAG"]
VERSION = TAG.lstrip("v")
PDF_PATH = os.environ["PDF_PATH"]
PDF_NAME = os.path.basename(PDF_PATH)
ZIP_PATH = os.environ["ZIP_PATH"]
ZIP_NAME = os.path.basename(ZIP_PATH)
BASE_URL = "https://zenodo.org/api"

METADATA = {
    "metadata": {
        "resource_type": {"id": "publication-other"},
        "title": (
            "Recurso educativo para el despliegue de ecosistemas "
            "de centralización de logs mediante Docker"
        ),
        "version": VERSION,
        "publication_date": str(date.today()),
        "creators": [
            {
                "person_or_org": {
                    "type": "personal",
                    "family_name": "Candela Uribe",
                    "given_name": "Christian Andrés",
                    "identifiers": [
                        {"scheme": "orcid", "identifier": "0000-0002-3961-1840"}
                    ],
                },
                "affiliations": [{"name": "Universidad del Quindío"}],
            },
            {
                "person_or_org": {
                    "type": "personal",
                    "family_name": "Acero Franco",
                    "given_name": "Paola Andrea",
                    "identifiers": [
                        {"scheme": "orcid", "identifier": "0000-0002-7058-6137"}
                    ],
                },
                "affiliations": [{"name": "Universidad del Quindío"}],
            },
            {
                "person_or_org": {
                    "type": "personal",
                    "family_name": "Sepúlveda Rodríguez",
                    "given_name": "Luis Eduardo",
                    "identifiers": [
                        {"scheme": "orcid", "identifier": "0000-0003-2446-0602"}
                    ],
                },
                "affiliations": [{"name": "Universidad del Quindío"}],
            },
        ],
        "description": (
            "Recurso educativo abierto que desarrolla los fundamentos conceptuales "
            "de la observabilidad en sistemas distribuidos, con énfasis en la "
            "centralización de logs. Incluye un marco teórico tecnológicamente neutral "
            "y un conjunto de guías prácticas para el despliegue de ecosistemas de "
            "centralización de logs (ELK, OLO, Fluentd, Loki, Graylog, OpenTelemetry, "
            "Vector y SigNoz) mediante Docker Compose, usando aplicaciones "
            "Java/Quarkus como fuente de logs."
        ),
        "rights": [{"id": "cc-by-sa-4.0"}],
        "languages": [{"id": "spa"}],
        "keywords": [
            "observabilidad",
            "centralización de logs",
            "sistemas distribuidos",
            "Docker",
            "ELK",
            "OpenTelemetry",
            "recurso educativo abierto",
        ],
        "publisher": "Universidad del Quindío",
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
    # 1. Inicializar entrada del archivo
    api("POST", f"/records/{draft_id}/draft/files", data=[{"key": name}])
    # 2. Subir contenido
    with open(path, "rb") as f:
        data = f.read()
    api("PUT", f"/records/{draft_id}/draft/files/{name}/content", data=data, binary=True)
    # 3. Confirmar
    api("POST", f"/records/{draft_id}/draft/files/{name}/commit")
    print(f"  ✓ {name}")


# 1. Crear nueva versión
print(f"→ Creando nueva versión {VERSION} en Zenodo...")
draft = api("POST", f"/records/{RECORD_ID}/versions")
draft_id = draft["id"]
print(f"  Draft ID: {draft_id}")

# 2. Eliminar archivos heredados de la versión anterior
print("→ Eliminando archivos heredados...")
files = api("GET", f"/records/{draft_id}/draft/files")
for entry in files.get("entries", []):
    fname = entry["key"]
    api("DELETE", f"/records/{draft_id}/draft/files/{fname}")
    print(f"  Eliminado: {fname}")

# 3. Subir PDF y ZIP de fuentes
print("→ Subiendo archivos...")
upload_file(draft_id, PDF_PATH, PDF_NAME)
upload_file(draft_id, ZIP_PATH, ZIP_NAME)

# 4. Actualizar metadatos
print("→ Actualizando metadatos...")
api("PUT", f"/records/{draft_id}/draft", data=METADATA)
print("  ✓ Tipo: Publication → Other")
print("  ✓ ORCID de autores registrados")
print("  ✓ Licencia CC BY-SA 4.0")

# 5. Publicar
print("→ Publicando...")
result = api("POST", f"/records/{draft_id}/draft/actions/publish")
doi = result.get("doi", "N/A")
rec_id = result.get("id", draft_id)
print(f"  ✓ Publicado correctamente")
print(f"  DOI: {doi}")
print(f"  URL: https://zenodo.org/records/{rec_id}")

# Exportar DOI para pasos siguientes del workflow
github_output = os.environ.get("GITHUB_OUTPUT")
if github_output:
    with open(github_output, "a") as f:
        f.write(f"doi={doi}\n")

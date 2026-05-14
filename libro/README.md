# Libro compilado del recurso educativo

Este directorio contiene la configuración necesaria para compilar el **recurso educativo completo** (marco conceptual + guía de estudio + guía docente + 9 guías prácticas) en un único **libro PDF** unitario, mediante [Quarto](https://quarto.org/).

El libro generado es el **artefacto principal de entrega** del trabajo: incluye portada institucional, tabla de contenido global, numeración continua de páginas, bibliografía consolidada y pies de página con la información de licencia y versión.

---

## Prerrequisitos

### 1. Quarto (≥ 1.4)

Instalación según sistema operativo: <https://quarto.org/docs/get-started/>

Verificar:

```bash
quarto --version
```

### 2. Distribución LaTeX con motor `lualatex`

Quarto puede instalar automáticamente **TinyTeX**, una distribución LaTeX mínima y suficiente para compilar este libro:

```bash
quarto install tinytex
```

Alternativamente, en macOS:

```bash
brew install --cask mactex-no-gui
```

Y en Linux:

```bash
sudo apt install texlive-luatex texlive-latex-extra texlive-fonts-extra
```

### 3. Mermaid CLI (para los diagramas Mermaid en el PDF)

El recurso contiene diagramas escritos en sintaxis ` ```mermaid ` (compatible con GitHub, que los renderiza nativamente). Para que estos diagramas también aparezcan en el PDF se utiliza un filtro Pandoc Lua que invoca la **Mermaid CLI** (`mmdc`) durante la compilación.

Instalación (requiere Node.js):

```bash
npm install -g @mermaid-js/mermaid-cli
```

Verificar:

```bash
mmdc --version
```

> Si `mmdc` no está instalado, la compilación no falla: los bloques Mermaid se mostrarán en el PDF como código fuente con una nota indicando cómo habilitar el renderizado. La versión HTML los renderiza siempre (mediante mermaid.js en el navegador).

---

## Compilar el libro

Desde este directorio (`libro/`):

```bash
make pdf      # PDF principal (formato de entrega)
make html     # Versión web navegable
make all      # Ambos formatos
make clean    # Limpia artefactos de compilación
make check    # Verifica que el entorno esté listo
```

Sin `make` (Windows o entornos sin Make):

```bash
quarto render --to pdf
```

El PDF resultante se genera en `_output/recurso-educativo.pdf`.

---

## Estructura

```
libro/
├── _quarto.yml              ← Configuración del proyecto Quarto (libro)
├── index.qmd                ← Prefacio
├── 01-marco-conceptual.qmd  ← Wrapper que incluye ../readme.md
├── 02-guia-estudio.qmd      ← Wrapper que incluye ../guia_estudio.md
├── 03-guia-docente.qmd      ← Wrapper que incluye ../guia_docente.md
├── guias/                   ← Wrappers para las 9 guías prácticas
│   ├── 01-elk.qmd
│   ├── 02-olo.qmd
│   ├── 03-fluentd.qmd
│   ├── 04-promtail.qmd
│   ├── 05-gelf-graylog.qmd
│   ├── 06-otel.qmd
│   ├── 07-vector.qmd
│   ├── 08-signoz.qmd
│   └── 09-alloy.qmd
├── strip-emojis.lua         ← Filtro Pandoc que retira emojis al renderizar a PDF
├── mermaid-filter.lua       ← Filtro Pandoc que renderiza bloques Mermaid como PDFs incrustados
├── Makefile                 ← Comandos de compilación
├── .gitignore               ← Excluye artefactos de compilación del repo
└── README.md                ← Este archivo
```

### Filosofía del diseño

Los archivos `.qmd` en este directorio son **envolventes mínimos**: cada uno declara el título del capítulo (en YAML *frontmatter*) e incluye el archivo Markdown fuente correspondiente mediante el *shortcode* `{{< include >}}` de Quarto. De este modo:

- **El contenido vive en un solo lugar.** Los archivos `.md` del repositorio siguen siendo la fuente única de verdad. Si un archivo se edita, basta con recompilar el libro para reflejar los cambios.
- **El repositorio sigue siendo navegable** en GitHub/GitLab sin necesidad de compilar.
- **El libro es un artefacto regenerable** en cualquier momento, sin pérdida de información.

---

## Formatos generados

| Formato | Salida | Propósito |
|---------|--------|-----------|
| PDF | `_output/recurso-educativo.pdf` | **Principal.** Documento académico unitario para evaluación, distribución impresa y depósito institucional. |
| HTML | `_output/index.html` y archivos asociados | **Complementario.** Sitio web navegable para uso en clase (búsqueda global, navegación lateral, enlaces vivos). Publicable en GitHub Pages. |

---

## Versionado del libro

La versión del libro está fijada en `_quarto.yml` (campo `date` y subtítulo). Para liberar una nueva versión:

1. Actualizar `date` y los campos de versión en `_quarto.yml`.
2. Actualizar el bloque de metadatos del `readme.md` (campo *Versión* y *Fecha*).
3. Recompilar con `make pdf`.
4. Etiquetar el commit en Git: `git tag v1.0.0` (versión semántica).
5. Opcionalmente: registrar la nueva versión en Zenodo para obtener un DOI específico.

---

## Solución de problemas frecuentes

**`lualatex not found` al compilar**

Ejecute `quarto install tinytex` y vuelva a intentar.

**Los emojis no aparecen en el PDF**

Es el comportamiento esperado: el filtro Lua `strip-emojis.lua` retira automáticamente los emojis al renderizar a PDF para evitar dependencias de fuentes externas (Noto Color Emoji, Apple Color Emoji, etc.). Los emojis se conservan en la versión HTML, donde el navegador los renderiza nativamente. Si desea ver los emojis también en el PDF, edite `_quarto.yml` y comente la línea `- strip-emojis.lua` en `filters`, e instale la fuente Noto Color Emoji junto con el paquete LaTeX `emoji`.

**Los diagramas Mermaid aparecen como código fuente en el PDF**

Instale la Mermaid CLI (ver prerrequisito 3): `npm install -g @mermaid-js/mermaid-cli`. Tras instalarla, vuelva a ejecutar `make clean && make pdf`.

**La compilación falla por memoria al renderizar el libro completo**

Reintente la compilación; LuaLaTeX puede consumir varios GB de RAM con documentos largos. Si persiste, cierre otras aplicaciones o use un equipo con más memoria.

---

## Licencia

Este libro y todo el material que lo compone se distribuye bajo **Creative Commons Atribución-CompartirIgual 4.0 Internacional (CC BY-SA 4.0)**. Vea el archivo `LICENSE` en la raíz del repositorio para los términos completos.

.PHONY: help pdf html all clean check

help:
	@echo "Comandos disponibles:"
	@echo "  make pdf      - Compila el libro a PDF (formato principal)"
	@echo "  make html     - Compila la versión web (HTML navegable)"
	@echo "  make all      - Compila ambos formatos"
	@echo "  make clean    - Elimina los artefactos de compilación"
	@echo "  make check    - Verifica que Quarto y LaTeX estén instalados"

check:
	@echo "Verificando Quarto..."
	@command -v quarto >/dev/null 2>&1 || { echo "  ❌ Quarto no encontrado. Instale desde https://quarto.org/docs/get-started/"; exit 1; }
	@quarto --version
	@echo "Verificando motor LaTeX (lualatex)..."
	@command -v lualatex >/dev/null 2>&1 || { echo "  ❌ lualatex no encontrado. Ejecute: quarto install tinytex"; exit 1; }
	@echo "  ✅ Entorno listo"

pdf: check
	quarto render --to pdf

html: check
	quarto render --to html

all: pdf html

clean:
	rm -rf _output _book _mermaid .quarto

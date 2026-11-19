# viewers

Visores de resultados de proyectos de OverThere, publicados con GitHub Pages.
`https://carriero-overther.github.io/viewers/<proyecto>/`

Reglas:
- Cada carpeta es un proyecto, con su propio `data/vault.json` cifrado y **su propia contraseña**.
- El código fuente de cada visor vive en el repo privado de su proyecto; acá solo se publica.
- Cada publicación reemplaza la historia con un único commit: no se acumulan versiones del vault.
- Los visores no guardan nada en el navegador (todos comparten el dominio).

## Publicar

```bash
./publicar.sh <proyecto> <ruta/al/visor/index.html> [ruta/al/vault.json]
# ej.: ./publicar.sh ovt-ia-e3-ocr ../ovt-ia-caso-1-e3-ocr-forms/visor/index.html ~/vault-nuevo.json
```

Sin `vault.json` se conserva el publicado (solo cambia el visor). El script se niega a publicar si:
- el `index.html` tiene cambios sin commitear en el repo del proyecto, o usa almacenamiento del navegador;
- el vault no es un vault cifrado (`v, iter, s, iv, ct`), por ejemplo un fragmento en claro;
- el vault nuevo es más chico que el publicado (el vault es acumulativo; `--permitir-achicar` si es a propósito);
- el repo no es este, el autor no es `carriero-overther` o hay cambios sueltos.

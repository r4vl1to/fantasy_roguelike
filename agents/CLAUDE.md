# CLAUDE.md — Guía de comportamiento del agente

Arquitectura y detalle técnico del proyecto → `AGENTS.md` (leer solo la sección necesaria, bajo demanda, nunca entero "por si acaso").

## Principio general
El token más barato es el que nunca se gasta. Antes de leer, buscar o escribir nada: pensar qué es lo mínimo necesario para resolver lo pedido. Preferir siempre la operación más barata que resuelva la tarea (grep/sed/bash) sobre leer o reescribir archivos completos.

## Alcance: no tocar lo que no se pide
- Modifica solo los archivos estrictamente necesarios para la tarea. No "aproveches" para refactorizar, renombrar o limpiar algo que no se pidió.
- No toques `addons/` ni carpetas de dependencias/terceros bajo ningún concepto.
- No borres ni sobrescribas archivos sin confirmación explícita si la tarea no lo pide directamente.
- Si detectas algo mejorable fuera del alcance pedido, dilo en una línea al final, no lo cambies por tu cuenta.
- Ante ambigüedad sobre si algo entra en el alcance: pregunta o asume el alcance mínimo, nunca el máximo.

## Antes de leer un archivo
1. Comprueba el tamaño (`wc -l`) antes de leerlo entero.
2. Si buscas algo concreto (función, patrón, error), usa `grep`/`rg` con contexto en vez de pedir que se lea todo el archivo.
3. Si es un log o archivo grande, usa `tail`/`head`/`grep`, no lectura completa.
4. Lee rangos de líneas concretos si ya sabes dónde mirar, no el archivo entero.

## Operaciones de archivo
- Copiar, mover, reemplazar texto, añadir líneas → usa `cp`, `mv`, `sed`, sin leer el contenido.
- No reescribas un archivo completo si el cambio es una línea o un patrón puntual.
- Comandos con salida potencialmente larga: limita siempre (`head`, `-maxdepth`, `--quiet`).

## Exploración del proyecto
- No leas el proyecto entero para orientarte. Usa `find`/`tree` con profundidad limitada y `grep` dirigido a lo que buscas.
- Da preferencia a explorar de forma quirúrgica (localizar archivo relevante → leer solo ese) sobre exploración amplia.

## Preguntar vs explorar
Antes de lanzarte a buscar, leer o deducir algo, compara el coste: preguntar una frase al desarrollador suele costar muchísimos menos tokens que explorar el proyecto para averiguarlo.
- Si una pregunta corta del desarrollador te ahorraría varias lecturas/greps/exploración, pregunta primero en vez de explorar.
- Aplica esto sobre todo a: ubicación de un archivo/función que no localizas en 1-2 greps, decisiones de diseño o alcance ambiguas, y datos que el desarrollador ya sabe de memoria (versión, convención elegida, dónde vive algo).
- Si la respuesta es rápida de deducir con una operación barata (un grep, un `wc -l`), hazla tú; no preguntes por pereza.
- Nunca preguntes solo para confirmar algo obvio o ya dicho en la conversación: eso también cuesta tokens.

## Conversación y contexto
- Una tarea, una conversación. Si el usuario cambia de tema/tarea, sugiere `/clear`.
- No repitas ni resumas innecesariamente lo ya dicho en la conversación.
- Si el usuario corrige algo, aplica la corrección sin repetir el error ni reexplicar qué pasó.

## Estilo de respuesta (los tokens de salida cuestan más que los de entrada)
- Directo, sin preámbulos, sin "voy a explicarte qué es X" salvo que se pida.
- Código y diffs mínimos, no prosa alrededor salvo que aporte algo necesario.
- Nada de disculpas, cortesías o resúmenes de lo obvio.
- Si el usuario pide una explicación, dala; si no, entrega el resultado y punto.

## Seguridad del proyecto
- Nunca ejecutes comandos destructivos (`rm -rf`, sobrescritura masiva, `git push --force`, etc.) sin confirmación explícita del usuario.
- No instales dependencias, addons o paquetes nuevos sin que se pida.
- No cambies configuración del proyecto (`project.godot`, `.editorconfig`, settings) salvo que sea el objetivo de la tarea.
- Antes de una operación irreversible o de amplio alcance, explica en una línea qué vas a hacer y espera confirmación si hay duda.

## Cómo actuar como guía para el desarrollador
- No te limites a ejecutar: cuando tomes una decisión de diseño o alcance, dilo brevemente para que el desarrollador entienda el porqué, no solo el qué.
- Si una petición es ambigua, no asumas el interpretación más costosa en tokens/cambios; pregunta con una frase corta o elige el criterio mínimo razonable y dilo.
- Prioriza que el desarrollador entienda el problema, no solo que quede resuelto.

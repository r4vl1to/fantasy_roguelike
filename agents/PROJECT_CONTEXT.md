# Contexto y mapa del proyecto

## En una frase

`fantasy_roguelike` es un proyecto 2D de Godot 4.7.2: usa GECS para entidades/sistemas y Gaea para generación procedural, streaming, representación y persistencia de chunks.

## Punto de entrada

- Escena principal: `res://game.tscn`.
- Script que la ensambla: `res://game.gd`. Configura cámara, mundo GECS, generación, gestor y render de chunks, streaming, jugador e interfaz de movimiento.
- Autoload: `ECS` (GECS), declarado en `project.godot`.
- Inputs configurados: `move_left`, `move_right`, `move_up`, `move_down`, `move_click`.
- Ejecutar el proyecto desde Godot o abrir `game.tscn` para inspeccionar la escena principal.

## Mapa de carpetas y archivos

| Ruta | Contenido / cuándo consultarla |
|---|---|
| `agents/` | Contexto y flujo de trabajo para agentes. Este documento es el índice breve. |
| `game.tscn`, `game.gd` | Escena principal y composición/inicialización del juego. |
| `components/`, `entities/`, `systems/` | Código de GECS del juego (componentes, entidades y sistemas). Buscar aquí la lógica de simulación y movimiento. |
| `utils/generation/` | Subsistema del mundo: `GaeaWorldManager`, streaming, chunks, mapeo de terreno, base de datos y persistencia. |
| `utils/generation/gaea_graphs/` | Grafo/configuración de generación Gaea (incluye `graph_gaea.tres`). |
| `utils/generation/tests/` | Pruebas y escenas de test/perfil de generación, streaming, persistencia y movimiento. Revisar scripts/escenas concretos antes de elegir cómo ejecutarlos. |
| `assets/` | Recursos propios del juego: personajes, tileset y cámara. |
| `ui/` | Interfaz y overlays de movimiento (por ejemplo, confirmación de movimiento y visualización de ruta). |
| `addons/gaea/`, `addons/gecs/` | Addons de terceros: generación procedural y ECS. No modificar su código para cambios del juego salvo petición expresa o necesidad demostrada. La documentación GECS está en `addons/gecs/docs/`. |
| `project.godot` | Ajustes del proyecto, escena de inicio, autoloads, plugins e inputs. Evitar cambios globales si la tarea no los requiere. |

> La estructura puede evolucionar: verificar rutas con búsqueda/glob antes de asumir que un archivo existe. Las carpetas `components/`, `entities/`, `systems/` y `ui/` son parte del código del juego; el detalle de cada clase se encuentra buscando por nombre/clase en el proyecto.

## Arquitectura esencial del mundo

- Gaea genera terreno nuevo; su grafo está en `utils/generation/gaea_graphs/`.
- `GaeaWorldManager` coordina carga/descarga y es la frontera de integración. El recorrido de obtención de chunk debe priorizar RAM, luego disco y solo entonces generación Gaea.
- `WorldDatabase` mantiene chunks en RAM; `WorldPersistence` guarda/restaura datos en disco (`user://world` en la escena principal).
- `GaeaChunkStreamer` determina el conjunto activo; `GaeaChunkRenderer` dibuja los chunks.
- `ChunkEntityLifecycle` / `ChunkEntityPersistence` integran entidades GECS residentes en chunks. El jugador no es una entidad residente que se descargue con el chunk.
- La escena principal conecta estos subsistemas; evitar duplicar sus responsabilidades en sistemas de jugador o renderer.

## Documentos de agentes

- `agents/agent_task_loop.md`: ciclo de trabajo y validación/entrega.
- `agents/CLAUDE.md`: directrices de alcance y estilo para agentes que lo utilicen.
- `agents/CURRENT_TASK_Plantilla.md`: contexto detallado y reglas de la integración Gaea–GECS; consultarlo si se toca generación, streaming, ciclo de vida o persistencia de chunks. No es necesario leerlo para tareas no relacionadas.

## Validación

- Hay pruebas y escenas auxiliares bajo `utils/generation/tests/`; localizar la prueba pertinente y sus instrucciones antes de ejecutarla.
- Para un cambio de escena o comportamiento, ejecutar/probar la escena afectada y revisar errores de Godot. Para cambios de generación/streaming/persistencia, priorizar las pruebas correspondientes y comprobar regresiones de la escena principal.
- Mantener cambios acotados: no alterar addons ni tareas ajenas al objetivo.

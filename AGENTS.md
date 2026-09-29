# AGENTS.md — fantasy-roguelike

Documento de referencia para agentes de IA y colaboradores que trabajen en este proyecto.
Léelo completo antes de tocar cualquier archivo.

---

## 1. Visión general del proyecto

**fantasy-roguelike** es un juego roguelike 2D en desarrollo activo, construido con **Godot 4.7.2 (Mono/C# habilitado, pero código actual en GDScript)**. El juego combina dos pilares técnicos principales:

- **ECS (Entity-Component-System)** vía el addon **GECS** para toda la lógica de entidades del juego.
- **Generación procedural de mundo por chunks** vía el addon **Gaea** para el mapa del mundo.

El renderer usa **GL Compatibility / D3D12** con canvas items escalables.

---

## 2. Arquitectura principal

### 2.1 ECS con GECS

El proyecto usa el addon [GECS](https://github.com/codingwithsascha/gecs) como sistema ECS. Hay un único **Autoload** registrado:

```
ECS  →  uid://dfqwl5njvdnmq
```

Los tres tipos fundamentales son:

| Tipo | Clase base | Rol |
|---|---|---|
| **Entity** | `Entity` | Nodo que representa una "cosa" en el mundo. Contenedor de componentes. Glue entre el árbol de escenas y el mundo ECS. |
| **Component** | `Component` / `Component_Node` | Contenedor de datos puro. **Sin lógica**. Solo datos y operaciones sobre sí mismo. |
| **System** | `System` | Contiene toda la lógica. Procesa entidades que encajan con su query. |
| **Observer** | `Observer` | Nodo reactivo. Responde a eventos (ADDED, REMOVED, CHANGED...) sobre queries. |

#### Regla Entity vs Component
- **Glue en Entity**: referencias a nodos hijo del árbol de escenas (`NavigationAgent2D`, `AnimationPlayer`, `CollisionShape2D`). No cambia en runtime, ningún sistema lo consulta por query, no serializable con Resource.
- **Dato en Component (C_\*)**: números, vectores, enums, cualquier cosa por la que un sistema filtre con `with_all`/`with_none`, cualquier cosa que cambie en runtime.

#### Plantillas disponibles
En `script_templates/` hay plantillas de Godot para crear cada tipo desde el editor:
- `Node/entity.gd` → Entity
- `Node/component.gd` → Component_Node
- `Node/system.gd` → System
- `Node/observer.gd` → Observer
- `Resource/component.gd` → Component (Resource)

### 2.2 Generación de mundo por chunks

Todo el sistema vive en `utils/generation/`. El flujo completo es:

```
ChunkStreamer
    │  detecta qué chunks cargar/descargar según posición del jugador
    ▼
GaeaWorldManager
    │  coordina las tres fuentes de datos
    ├─► WorldDatabase (RAM)         — caché en memoria
    ├─► WorldPersistence (Disco)    — JSON en user://world_chunks/
    └─► GaeaWorldGenerator (Gaea)  — genera si no existe
            │
            ▼
        GaeaGenerator (addon)
            │  emite generation_finished(GaeaGrid)
            ▼
        GaeaChunkImporter
            │  convierte GaeaGrid → ChunkData
            │  usando GaeaMappingRegistry (GaeaMaterial → TerrainId)
            ▼
        ChunkData
```

#### Prioridad de fuentes en `GaeaWorldManager.request_chunk()`
1. **RAM** (`WorldDatabase`) — si está en memoria, responde inmediatamente.
2. **Disco** (`WorldPersistence`) — si existe el JSON, lo carga y guarda en RAM.
3. **Gaea** — genera proceduralmente, guarda en RAM y disco.

---

## 3. Clases clave y sus responsabilidades

### Generación de mundo

| Clase | Archivo | Responsabilidad |
|---|---|---|
| `ChunkData` | `utils/generation/ChunkData.gd` | Datos de un chunk: `terrain: PackedInt32Array`, `biome: PackedInt32Array`, `coord: Vector2i`, `size: int`. Índice lineal: `y * size + x`. |
| `ChunkMath` | `utils/generation/ChunkMath.gd` | Utilidades estáticas de conversión de coordenadas (chunk ↔ world ↔ local ↔ index). |
| `ChunkSerializer` | `utils/generation/ChunkSerializer.gd` | Serializa/deserializa `ChunkData` a/desde `Dictionary` (para JSON). |
| `ChunkStreamer` | `utils/generation/ChunkStreamer.gd` | Calcula qué chunks cargar/descargar según `loading_radius` y posición actual del jugador. Emite `chunks_to_load` y `chunks_to_unload`. |
| `WorldDatabase` | `utils/generation/WorldDatabase.gd` | Caché en RAM. Diccionario `Vector2i → ChunkData`. |
| `WorldPersistence` | `utils/generation/WorldPersistence.gd` | Persistencia en disco. Guarda/carga chunks como JSON en `user://world_chunks/<x>_<y>.json`. |
| `GaeaWorldGenerator` | `utils/generation/GaeaWorldGenerator.gd` | Wrapper sobre `GaeaGenerator`. Traduce chunk coord → `AABB` para Gaea y convierte el resultado. |
| `GaeaWorldManager` | `utils/generation/GaeaWorldManager.gd` | Orquestador principal. Coordina las tres fuentes. Emite `chunk_ready`, `chunk_generation_started`, `chunk_generation_failed`. |
| `GaeaChunkImporter` | `utils/generation/GaeaChunkImporter.gd` | Convierte `GaeaGrid` (resultado de Gaea) en `ChunkData`. |
| `GaeaMappingRegistry` | `utils/generation/GaeaMappingRegistry.gd` | Mapea `GaeaMaterial` → `TerrainId`. Se construye desde el grafo de Gaea. |
| `TerrainId` | `utils/generation/TerrainId.gd` | Constantes de terreno: `DIRT=0, GRASS=1, SAND=2, STONE=3, WATER=4`. |
| `WorldConfig` | `utils/generation/world_config.gd` | Resource exportable: `world_seed`, `chunk_size` (default 32), `tile_size` (default 16), `generation_version`. |

### ECS

| Clase | Archivo | Responsabilidad |
|---|---|---|
| `C_Sprite_Render` | `c_sprite_render.gd` | Componente de renderizado. Contiene `sprite: AnimatedSprite2D` y `tween: Tween`. |

---

## 4. Convenciones de nomenclatura

| Elemento | Convención | Ejemplo |
|---|---|---|
| Componentes | Prefijo `C_` + PascalCase | `C_Sprite_Render`, `C_Health`, `C_Position` |
| Systems | `S_` + PascalCase (sugerido) | `S_Movement`, `S_Combat` |
| Observers | `O_` + PascalCase (sugerido) | `O_Death`, `O_SpawnEnemy` |
| Entities | PascalCase sin prefijo | `Player`, `Enemy`, `Chest` |
| Archivos GDScript | snake_case | `world_config.gd`, `chunk_math.gd` |
| Clases GDScript | PascalCase | `WorldConfig`, `ChunkMath` |
| Constantes | UPPER_SNAKE_CASE | `TerrainId.DIRT` |

---

## 5. Addons utilizados

| Addon | Ruta | Propósito |
|---|---|---|
| **GECS** | `addons/gecs/` | Entity-Component-System |
| **Gaea** (editor) | `addons/gaea/editor/` | Plugin editor para grafos de generación |
| **Gaea** (plugin) | `addons/gaea/` | Core de generación procedural |
| **Gaea** (runtime) | `addons/gaea/runtime/` | Runtime de generación, `GaeaGenerator`, `GaeaGrid`, etc. |

**No modificar los addons directamente.** Si necesitas extender comportamiento, hazlo mediante las clases de `utils/` o subclasificando desde fuera del directorio `addons/`.

---

## 6. Escena principal y estructura de escenas

La escena raíz actual es `world.tscn`:

```
world (Node)
├── Node (test.tscn instanciado) — script: gaea_world_manager_test.gd
├── GaeaGenerator (Node) — script: addons/gaea/runtime/.../generator.gd
│       graph: graph_gaea.tres
│       settings: GenerationSettings (seed: 3151708176)
└── GaeaWorldManager (Node) — script: utils/generation/GaeaWorldManager.gd
```

Actualmente `world.tscn` es una escena de prueba/desarrollo. El juego real se construirá sobre esta base.

---

## 7. Sistema de coordenadas de chunks

```
Tile      → Vector2i absoluto en el mundo (en tiles)
Chunk     → Vector2i de coordenada de chunk
Local     → Vector2i relativo dentro del chunk [0, chunk_size)
Index     → int lineal: index = local.y * chunk_size + local.x
```

Conversiones disponibles en `ChunkMath` (todas estáticas):
- `chunk_to_world_origin(chunk, size)` → Vector2i
- `chunk_to_world_rect(chunk, size)` → Rect2i
- `local_to_index(local, size)` → int
- `index_to_local(index, size)` → Vector2i
- `local_to_world(chunk, local, size)` → Vector2i
- `world_to_chunk(world, size)` → Vector2i
- `world_to_local(world, size)` → Vector2i

---

## 8. Tests y debug

Los tests están en `utils/generation/tests/` y son scripts de nodo que se ejecutan al hacer `_ready()`. No hay framework de testing formal todavía — los tests imprimen resultados por consola y usan `assert()`.

| Test | Qué prueba |
|---|---|
| `generation_test01.gd` | Matemáticas de chunks (`ChunkMath`): conversiones, round-trips, negativos. |
| `world_manager_test.gd` | Flujo completo: generación → RAM cache → segunda petición desde RAM. |
| `gaea_world_manager_test.gd` | Integración con `ChunkStreamer`: cargar/descargar chunks al mover al jugador. |
| `chunk_serializer_test.gd` | Serialización/deserialización de `ChunkData`. |
| `chunk_streamer_test.gd` | Lógica del streamer. |
| `world_persistence_test.gd` | Persistencia en disco. |
| `world_database_test.gd` | Caché en RAM. |

Para ejecutar un test, abre `world.tscn` (o `utils/generation/tests/test.tscn`) y ejecuta el proyecto.

---

## 9. Reglas para agentes

1. **Leer antes de escribir.** Antes de crear un archivo nuevo, revisar si ya existe algo similar.
2. **Los componentes no tienen lógica.** Si te piden añadir lógica a un `C_*`, es una señal de que deberías crear un System u Observer en su lugar.
3. **No tocar `addons/`.** Extender siempre desde fuera.
4. **Seguir la nomenclatura** de la sección 4.
5. **`ChunkMath` es la única fuente de verdad** para conversiones de coordenadas. No recalcules manualmente.
6. **El flujo de chunks siempre pasa por `GaeaWorldManager`**. No interactuar con `WorldDatabase` o `WorldPersistence` directamente desde el gameplay.
7. **Chunk size por defecto: 32 tiles.** No hardcodear este valor — usar `WorldConfig.chunk_size` o el parámetro pasado al `setup()`.
8. **Los tests deben seguir pasando.** Si modificas `ChunkMath`, `ChunkData`, `ChunkSerializer` o `WorldPersistence`, verifica que los tests correspondientes sigan funcionando.
9. **GDScript, no C#**, a menos que se indique explícitamente lo contrario.

---

## 10. Estado actual del proyecto

- ✅ Sistema de chunks completo (generación, RAM, disco, streaming)
- ✅ Integración con Gaea para generación procedural
- ✅ ECS configurado con GECS
- ✅ Primer componente: `C_Sprite_Render`
- 🔧 Escena de juego real: pendiente (actualmente solo hay escena de test)
- 🔧 Entidades de gameplay (Player, Enemy...): pendiente
- 🔧 Systems de gameplay: pendiente
- 🔧 UI/HUD: pendiente
- 🔧 Combate: pendiente
- 🔧 Inventario: pendiente

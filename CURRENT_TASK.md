El siguiente trabajo

Yo haría ahora una integración GECS mínima, sin tocar todavía el pipeline que ya funciona:

lee res://addons/gecs/docs/

sigue la estructura de carpetas creada al crear los archivos

Crear la entidad Player en GECS.
Añadirle un componente de posición.
Añadir componente/estado de chunk actual.
Crear un sistema ChunkStreamingSystem.
Ese sistema detecta cuándo el jugador cambia de chunk.
Llama a GaeaChunkStreamer.update_player_chunk().
GaeaChunkStreamer sigue siendo responsable de calcular qué chunks cargar/descargar.
GaeaWorldManager sigue siendo responsable de obtener/generar/persistir ChunkData.
GaeaChunkRenderer sigue siendo responsable exclusivamente del render.

Así GECS no rompe nada de lo que ya está validado.

Y hay una buena señal: el test actual ya tiene claramente separadas las responsabilidades de WorldManager, ChunkStreamer y Renderer; por ejemplo, al movernos se cargan los nuevos chunks, se descargan los antiguos y el manager decide si proceden de disco o Gaea.

Por tanto, estamos en el punto ideal para hacer la primera integración GECS. No necesitamos rehacer el sistema de chunks; necesitamos conectar el ECS como capa de orquestación del jugador y las entidades.

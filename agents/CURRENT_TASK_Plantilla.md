# CURRENT TASK

## Objective

Maintain and extend the integration between

 Gaea — procedural terrainchunk generation.
 GaeaWorldManager — authoritative chunk lifecycle coordinator.
 GaeaChunkStreamer — determines which chunks must currently be active.
 WorldDatabase — in-memory chunk storage.
 WorldPersistence — disk persistence for terrainchunk data.
 GaeaChunkRenderer — visual representation of loaded chunks.
 GECS — entity simulation.
 ChunkEntityLifecycle — associates persistent GECS entities with chunk loadunload.
 ChunkEntityPersistence — serializationdeserialization of chunk-resident entities.

The target architecture is

```text
                    ┌─────────────────────┐
                    │   GaeaChunkStreamer  │
                    │ active chunk set     │
                    └──────────┬──────────┘
                               │ loadunload
                               ▼
                    ┌─────────────────────┐
                    │  GaeaWorldManager   │
                    │ lifecycle authority │
                    └──────┬───────┬──────┘
                           │       │
              ┌────────────┘       └─────────────┐
              ▼                                  ▼
      ┌───────────────┐                  ┌─────────────────┐
      │ GaeaGenerator │                  │ WorldDatabase   │
      │ terrain source│                  │ RAM chunks      │
      └───────┬───────┘                  └────────┬────────┘
              │                                   │
              ▼                                   ▼
      ┌───────────────┐                  ┌─────────────────┐
      │   ChunkData   │◄────────────────►│ WorldPersistence│
      └───────────────┘                  │ disk chunks     │
                                         └─────────────────┘

                    GaeaWorldManager
                           │
                           ▼
                 ChunkEntityLifecycle
                           │
                 ┌─────────┴─────────┐
                 ▼                   ▼
        GECS entity world     ChunkEntityPersistence
                                  │
                                  ▼
                             entities.json
```

## Current Status

The Gaea ↔ GECS chunk lifecycle integration is implemented and verified.

Do not reimplement the completed integration unless a regression is found.

Verified behavior

 Gaea generates missing chunks.
 Generated chunks enter RAM.
 Generated chunks are persisted to disk.
 Loaded chunks are rendered.
 Streaming loads only the required chunk set.
 Streaming unloads chunks outside the required set.
 Unloaded chunks are removed from RAM.
 Unloaded chunk-resident GECS entities are removed from GECS.
 Chunk-resident entities are persisted to disk on unload.
 Chunk-resident entities are restored from disk on reload.
 Restored entities retain their serialized component data.
 The Player remains in GECS and is not treated as a chunk-resident entity.
 Returning to a previously visited area restores chunks from disk without invoking new Gaea generation.
 Rapid player movement does not leave stale rendered chunks.
 Abandoned Gaea generation results are discarded when their chunk is no longer required.
 Standalone entity persistence testing passes 1313 checks.

The real streaming test reaches

```text
=== REAL STREAMING TEST PASS ===
[PASS] All chunk residents removed from GECS when their chunk unloads
[PASS] All chunk residents persisted to disk on unload
[PASS] Disk contains every resident entity record
[PASS] Visited area restored without new Gaea generation
[PASS] No chunk generation failures
[PASS] Player remains in GECS and is not treated as chunk-resident
```

The streaming test also verifies that the active radius contains exactly 9 chunks for `stream_radius = 1`.

---

# Architecture Rules

## 1. Gaea owns terrain generation

Gaea is the source of truth for newunpersisted terrain.

When requesting a chunk

```text
RAM hit
    ↓
return RAM chunk

else disk hit
    ↓
restore persisted ChunkData
    ↓
return chunk

else
    ↓
generate with Gaea
    ↓
store in RAM
    ↓
persist
    ↓
return chunk
```

A disk hit must not trigger Gaea generation.

A RAM hit must not trigger Gaea generation.

The existing integration test explicitly verifies both conditions.

---

## 2. GaeaWorldManager owns chunk lifecycle coordination

`GaeaWorldManager` is the integration boundary.

It coordinates

 Gaea generation.
 RAM insertionremoval.
 disk persistence.
 chunk-ready notifications.
 generation failures.
 optional `ChunkEntityLifecycle`.

Do not move entity persistence logic into

 `GaeaGenerator`
 `GaeaChunkStreamer`
 `GaeaChunkRenderer`

unless there is a specific architectural reason.

---

## 3. GaeaChunkStreamer owns the active chunk set

The streamer determines

```text
required_chunks
```

It does not own

 terrain generation,
 entity serialization,
 GECS simulation,
 disk persistence.

Its job is to emit

```text
chunks_to_load
chunks_to_unload
```

For

```text
stream_radius = 1
```

the active set is exactly

```text
3 × 3 = 9 chunks
```

After every stable transition

```text
required_chunks == 9
rendered_chunks == 9
RAM_chunks == 9
```

No rendered chunk may exist outside `required_chunks`.

---

# GECS Entity Rules

## Chunk-resident entities

An entity is chunk-resident when it contains

```text
C_ChunkResident
C_CurrentChunk
```

The entity's chunk is determined from

```text
C_CurrentChunk.coord
```

Persistent entity data is handled by

```text
ChunkEntityLifecycle
ChunkEntityPersistence
```

---

## Player exception

The Player is a GECS entity but is not chunk-resident.

Do not add `C_ChunkResident` to the Player merely because it has

```text
C_CurrentChunk
C_Position
```

The Player must survive chunk streaming.

The integration test explicitly verifies

```text
Player remains in GECS
Player is not treated as chunk-resident
```

---

# Entity Lifecycle

## Chunk load

When a chunk becomes active

```text
GaeaChunkStreamer
        ↓
GaeaWorldManager.request_chunk()
        ↓
RAM  disk  Gaea
        ↓
chunk becomes ready
        ↓
ChunkEntityLifecycle
        ↓
restore persisted chunk residents
        ↓
GECS
        ↓
GaeaChunkRenderer
```

If the chunk has no persisted entity file, no entity restoration is required.

---

## Chunk unload

When a chunk leaves the active set

```text
GaeaChunkStreamer
        ↓
GaeaWorldManager.unload_chunk()
        ↓
ChunkEntityLifecycle
        ↓
find C_ChunkResident entities
        ↓
serialize entity components
        ↓
write entitiesx_y.json
        ↓
remove entities from GECS
        ↓
WorldPersistence  WorldDatabase chunk lifecycle
```

After unload

```text
entity must not remain in GECS
entity data must exist on disk
```

---

# Persistence Rules

## Chunk files

Terrainchunk persistence is handled by

```text
WorldPersistence
```

Do not duplicate terrain serialization in GECS persistence.

---

## Entity files

Entity persistence is handled separately

```text
entitiesx_y.json
```

Example

```text
entities0_0.json
```

The file should contain only actual serializable component data.

Built-in Godot implementation properties such as

```text
script
resource_
```

must not be serialized as entity gameplay state.

---

# Serialization Rules

`ChunkEntityPersistence` should serialize only explicitly supported component state.

Current important component data includes

```text
C_Position.world_position
C_CurrentChunk.coord
```

Do not serialize arbitrary GodotObject internals.

Do not serialize

 `script`
 resource implementation metadata
 runtime-only references
 GECS world references
 transient systems
 renderer state
 Gaea generator state

If a new persistent component is introduced, explicitly decide whether it belongs in the entity serialization contract.

---

# Streaming Invariants

These invariants must remain true.

## Required set

For radius 1

```text
required_chunks.size() == 9
```

The coordinates must correspond to

```text
center.x ± 1
center.y ± 1
```

---

## Renderer

At stable state

```text
renderer._rendered_chunks.size() == 9
```

Every rendered chunk must be required

```text
streamer.is_required(coord) == true
```

---

## RAM

At stable state

```text
database.get_loaded_chunks().size() == 9
```

Every required chunk must exist in RAM.

---

## GECS residents

For a chunk that has been unloaded

```text
_residents_in_chunk(coord).is_empty()
```

For a chunk restored from disk

```text
_residents_in_chunk(coord).size()
```

must match the persisted resident count.

---

# Generation Race Rules

Gaea generation is asynchronous.

A chunk can become unnecessary while Gaea is still generating it.

Therefore

```text
generation_started(coord)
        ↓
chunk becomes no longer required
        ↓
generation finishes
        ↓
chunk must NOT become active again
```

The completed implementation handles this by checking whether the chunk is still required before renderingretaining it.

Abandoned generated chunks must not inflate

 RAM resident count
 renderer resident count
 active chunk set

They may be persisted if that is part of the existing world-generationpersistence contract.

Do not remove this protection.

---

# Existing Tests

## Test A — Real streaming integration

Primary test

```text
gaea_streaming_test.gd
```

This test exercises

```text
Gaea
  ↓
WorldManager
  ↓
ChunkStreamer
  ↓
WorldDatabase
  ↓
WorldPersistence
  ↓
GaeaChunkRenderer
  ↓
GECS
  ↓
ChunkEntityLifecycle
  ↓
ChunkEntityPersistence
```

It covers

1. Initial 3×3 streaming.
2. Rapid movement across multiple chunks.
3. Async Gaea generation.
4. Abandoned generation.
5. RAM residency.
6. renderer residency.
7. required coordinate validation.
8. entity removal on unload.
9. entity persistence on unload.
10. entity restoration on reload.
11. serialized position preservation.
12. Player exclusion from chunk residency.
13. disk restoration without new Gaea generation.

Relevant test helpers include

```text
_residents_in_chunk()
_find_entity_by_name()
_entity_path()
```

The test intentionally verifies entity removal at `(5, 0)`, where `(0, 0)` is genuinely outside the streaming radius. Do not move this assertion to `(1, 0)` `(0, 0)` is still required at that position.

---

## Test B — Entity persistence isolation

Primary scene

```text
chunk_entity_persistence_test.tscn
```

Primary script

```text
chunk_entity_persistence_test.gd
```

Expected result

```text
=== CHUNK ENTITY PERSISTENCE TEST PASS ===
1313 checks
```

The test should remain independently runnable without requiring the full world scene.

---

## Test C — WorldManager integration

The lower-level Gaea integration test verifies

 Gaea generation.
 RAM cache hits.
 disk restoration.
 terrain preservation.
 metadata preservation.
 renderer material reconstruction.
 streaming unload.
 no generation on RAMdisk hits.

The test explicitly verifies that disk restoration preserves both terrain and Gaea metadata.

---

# Validation Procedure

Before considering a change complete

## Step 1 — Run the real streaming test

Expected

```text
=== REAL STREAMING TEST PASS ===
```

No

```text
[FAIL]
Generation failed
```

No stale rendered chunks.

---

## Step 2 — Run entity persistence test

Expected

```text
=== CHUNK ENTITY PERSISTENCE TEST PASS ===
```

Expected

```text
1313 checks
```

---

## Step 3 — Check disk artifact

Inspect

```text
entities0_0.json
```

It should contain minimal serialized component state.

It must not contain

```text
script
resource_
```

or other runtime implementation properties.

---

# Agent Workflow

When modifying this system, follow this order.

## 1. Inspect before editing

Search for

```text
GaeaWorldManager
GaeaChunkStreamer
WorldDatabase
WorldPersistence
ChunkData
ChunkEntityLifecycle
ChunkEntityPersistence
C_ChunkResident
C_CurrentChunk
C_Position
S_ChunkStreaming
```

Do not assume ownership from class names alone.

---

## 2. Identify the lifecycle boundary

Determine whether the change belongs to

```text
generation
streaming
RAM
disk persistence
rendering
GECS
entity lifecycle
serialization
```

Avoid mixing responsibilities.

---

## 3. Preserve existing invariants

Before changing code, identify which tests assert

```text
9 required chunks
9 rendered chunks
9 RAM chunks
no stale chunks
no unnecessary Gaea generation
entity removed on unload
entity restored on reload
Player survives streaming
```

Do not weaken or delete an assertion simply because it fails.

First determine whether

```text
implementation is wrong
```

or

```text
test expectation is wrong
```

The previous streaming assertion failure was caused by the latter `(0,0)` remained inside the radius at player position `(1,0)`.

---

## 4. Prefer minimal changes

Do not redesign the streaming architecture for a local bug.

Prefer

```text
smallest change
+
existing lifecycle
+
existing signals
+
existing persistence APIs
```

Avoid introducing duplicate managers or parallel persistence paths.

---

## 5. Add a regression test

Every bug fix should add or improve an assertion that would fail if the bug returns.

---

# Do Not

Do not

 make `GaeaChunkStreamer` serialize entities.
 make `GaeaChunkRenderer` own entity lifecycle.
 make the Player a `C_ChunkResident` entity.
 trigger Gaea generation for diskRAM hits.
 keep unloaded chunk residents in GECS.
 restore chunk residents twice.
 serialize arbitrary Godot object properties.
 remove race-condition checks around asynchronous Gaea generation.
 assume a chunk is unloaded merely because the player moved.
 change a test expectation without checking the actual required-chunk set.
 delete failing tests just to obtain a green run.

---

# Expected Ownership

 Responsibility                   Owner                         
 -------------------------------  ----------------------------- 
 Procedural terrain generation    `GaeaGenerator`               
 Required active chunks           `GaeaChunkStreamer`           
 Chunk lifecycle coordination     `GaeaWorldManager`            
 RAM chunk cache                  `WorldDatabase`               
 Terrain persistence              `WorldPersistence`            
 Chunk rendering                  `GaeaChunkRenderer`           
 Entity simulation                GECS                          
 Chunk-resident entity detection  `ChunkEntityLifecycle`        
 Entity serialization             `ChunkEntityPersistence`      
 Player movementchunk state      GECS Playercomponents        
 Integration tests                dedicated test scenesscripts 

---

# Definition of Done

A future change affecting this subsystem is complete only when

 [ ] Architecture ownership remains intact.
 [ ] Existing streaming invariants still hold.
 [ ] RAMdiskGaea priority remains correct.
 [ ] Chunk unload does not leave stale rendered chunks.
 [ ] Chunk unload removes chunk residents from GECS.
 [ ] Chunk residents are persisted before removal.
 [ ] Chunk reload restores persisted residents.
 [ ] Restored component state matches serialized state.
 [ ] Player remains independent from chunk-resident lifecycle.
 [ ] Async abandoned generation cannot reappear in the active world.
 [ ] Existing tests pass.
 [ ] A regression test exists for any new bug fixed.
 [ ] No runtime-only Godot properties leak into entity persistence.
 [ ] Documentation is updated if the architecture or lifecycle changes.

---

# Current Task State

## Completed

 [x] Inspect Gaea chunk lifecycle.
 [x] Inspect GECS lifecycle and entitycomponent APIs.
 [x] Define chunk-resident entity contract.
 [x] Implement `ChunkEntityPersistence`.
 [x] Implement `ChunkEntityLifecycle`.
 [x] Integrate entity lifecycle into `GaeaWorldManager`.
 [x] Persist residents on chunk unload.
 [x] Remove residents from GECS after persistence.
 [x] Restore residents on chunk load.
 [x] Exclude Player from chunk-resident persistence.
 [x] Fix entity serialization to exclude runtime Godot properties.
 [x] Add standalone persistence test scene.
 [x] Add streaming lifecycle assertions.
 [x] Validate disk artifact.
 [x] Update `AGENTS.md`.
 [x] Validate real streaming lifecycle end-to-end.

## Current Status

No known open item in the Gaea ↔ GECS chunk lifecycle integration.

Future work should be treated as incremental development on top of the completed integration, not as a request to reimplement it.

## If Asked To Continue

The next agent must first inspect the repository and determine the requested change.

Do not assume that GECS integration is unfinished.

The baseline implementation described in this document is already working and tested.

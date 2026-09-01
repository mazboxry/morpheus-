# Morpheus MVP: fixed game specification

This document is the implementation contract for the first playable vertical
slice. It prioritizes a short, easily understood play loop and hand-authored
art expansion over system breadth.

## 1. One play session

1. Boot, title, configuration, and tutorial are root-level screens.
2. The player starts a stage, then presses **Roll** once.
3. Four physical dice are thrown. Each stopped die summons one allied monster
   at its stopped position.
4. Allies automatically march and fight enemies until one castle is destroyed.
5. The player may use the master skill once during the march.
6. A non-final victory goes to Stage Clear; defeat goes to Game Over; a final
   victory goes to Game Clear. Game Over and Game Clear return to Title.

There is no reroll, manual unit placement, deck editing, inventory, or
time-limit in this MVP.

## 2. Global Game state

`Game` owns only this coarse state enum:

`BOOT`, `TITLE`, `CONFIG`, `TUTORIAL`, `MAIN_GAME`, `STAGE_CLEAR`,
`GAME_OVER`, and `GAME_CLEAR`.

Every enum member has one root modal scene path in `Game.ROOT_MODAL_SCENES`.
`Game` emits `root_modal_requested` instead of implementing combat, spawning,
audio, or UI itself. A modal navigator is responsible for showing the requested
root scene. A root scene returns the next global transition by calling a small
`Game` API (`open_title`, `open_config`, `open_tutorial`, `start_main_game`,
`finish_stage`, or `lose_game`).

The top root modal is the global state. Nested modals are local detail state;
they do **not** add members to `Game.State`. A modal navigator must record a
unique instance id, scene path, payload, and pause policy for each pushed modal,
so recursive instances of the same scene are still distinct stack entries.

## 3. MainGame local state

`MainGame` owns the following local FSM and has no need to write Game's enum
until it completes:

`DICE_ROLL` -> `MARCH_START` -> `MARCH_MAIN` -> `MARCH_END`.

* **DICE_ROLL:** enable the one Roll button, launch dice physics, wait for all
  results, then resolve the special summon rule.
* **MARCH_START:** spawn the resolved allies and fixed/stage-configured enemy
  side; play a short start cue.
* **MARCH_MAIN:** autonomous movement/combat is active and the master-skill
  button may be used once.
* **MARCH_END:** freeze battle input, decide winning castle, then call
  `Game.finish_stage(stage.is_final_stage)` or `Game.lose_game()`.

## 4. Dice and summoning

The MVP has four identical `DiceDefinition` resources. The standard die faces
are exactly `[1, 1, 1, 2, 2, 3]`: ☆1 is 50%, ☆2 is 33.3%, and ☆3 is 16.7%.
The resolved number is monster rarity, not damage. Each rarity uses its own
monster scene and visual identity. The dice resource is data-only so a later
dice-set system can replace faces and change the number of dice without
rewriting battle flow.

If all four dice resolve to ☆1, roll one independent 10% special-summon check.
On success, sacrifice only the four allies created by this roll and summon one
powerful special ally at the centroid of their positions. On failure, leave the
four ☆1 allies unchanged. This is automatic, has no player confirmation, and
must play a brief distinct effect.

## 5. Combat and master skill

Each monster scene implements at least `IDLE`, `WALK`, `ATTACK`, `DAMAGE`, and
`DEAD` animation states. Units show an HP bar above their head. Buff/debuff
icons appear there only while active.

Monster definitions may carry movement/attack hooks and timed status effects:
poison, paralysis, burn, curse/slow, regeneration, one-time attack increase,
and movement/attack speed increase. Effects own their duration, stacking rule,
and icon; the unit only applies their resulting modifiers.

The only MVP master skill is **Fortune MAX**. It can be activated once in
`MARCH_MAIN` with no penalty. For a short configurable duration, chance-based
effects (critical attacks, status application, and eligible special attacks)
use maximum luck. The underlying luck-market design is intentionally not needed
for MVP: use a normalized `luck` value and make Fortune MAX set it to `1.0`.
Later, a bounded random-walk market can supply the normal value without changing
the skill API.

## 6. Stages and art-production contract

Every hand-authored stage starts from `scenes/stages/stage_template.tscn`. It
must retain `Battlefield`, `PlayerSpawnZone`, `EnemySpawnZone`, `PlayerCastle`,
`EnemyCastle`, `StageArt`, and `Obstacles`. Designers can freely add terrain,
navigation, scenery, enemy setup, and obstacle layouts under the appropriate
nodes. A stage decides whether enemies are fixed, dice-configured, or generated,
and whether it is final via its stage configuration.

This contract makes adding maps and monster assets a data/scene-authoring task;
the global flow and battle lifecycle stay unchanged.

## 7. Ownership boundaries

* `Game`: root flow API and current stage id only.
* Modal navigator: modal stack, input blocking, and pause policy.
* MainGame: local match FSM.
* Dice controller: physical throw, face reading, stopped positions.
* Spawn manager: instantiate/remove units.
* Battle manager: target acquisition, combat start/end, castle result.
* Status/master-skill managers: effect lifetime and probability modifiers.
* Stage scene: anchors, art, obstacles, enemy configuration, final-stage flag.

No manager accesses another manager's internal state; they use signals or narrow
request APIs. `Game` must not become a service locator or a unit registry.

# Character Action BP

Reusable Godot 4 editor plugin for authoring lightweight blueprint-style action branches by character state.

The plugin is intentionally framework-neutral. It does not require a specific player controller, state machine base class, or action interface.

## Install

Copy this folder into any Godot 4 project:

```text
addons/character_action_bp
```

Then enable `Character Action BP` in `Project > Project Settings > Plugins`.

## Runtime Flow

1. Add `CharacterActionRunner` under a character, controller, or state machine node.
2. Assign a `CharacterActionBlueprint` resource.
3. Add branches with a `source_state`, optional conditions, and one or more actions.
4. Call `evaluate()` manually, or set the runner evaluation mode to process/physics.

Branches run top to bottom. The first matching branch executes.

## State Resolution

`CharacterActionBlueprint` can read state in several common ways:

- `actor_state_method`: calls a method such as `get_state_name()`.
- `actor_state_property`: reads a property path on the actor.
- `state_machine_property`: reads an actor property that points to a state machine.
- `state_machine_current_state_property`: reads the current state object from the state machine.
- `state_object_name_property`: reads a name field from the current state object.
- If no explicit name field exists, the plugin falls back to the current state's script global class name.

## Actions

A branch can execute any combination of:

- `action_script`: script with `apply(actor)` or `execute(actor, state_machine, context)`.
- `action_method`: method called on the actor. Put method arguments in `action_arguments["args"]`.
- `target_state_script`: script instantiated and passed to the state machine method, default `change_state`.
- `target_state_name`: state name passed to `change_state_by_name` on the state machine or actor.

The default method names are editable on the blueprint or branch resources.

## Conditions

Conditions are resources attached to a branch through the Inspector.

- `CharacterPropertyCondition`: compares an actor property path, such as `is_grounded` or `velocity:y`.
- `CharacterMethodCondition`: calls an actor method and compares the return value.
- `CharacterContextFlagCondition`: compares a value from the evaluation context dictionary.

## Example

```gdscript
var context := {"input": "jump"}
$CharacterActionRunner.evaluate(context)
```

Example branch:

- Source State: `Idle`
- Condition: `CharacterContextFlagCondition`, key `input`, expected `jump`
- Actor Method: `jump`
- Target State Name: `Jumping`

 Task: Implement Contextual Action Selection Menu

Goal: Replace the static action button bar with a dynamic menu that appears when the player intends to act.

Implementation:

Modify Combat:mousepressed for the player's turn:

Clicking the player ship during the Movement Phase still selects it for movement (shows valid move hexes).

Clicking the player ship during the Action Phase (or maybe adding a dedicated "Actions" button to the minimal HUD or Ship Info Window) opens a small, contextual action menu near the player ship.

Create Combat:drawActionMenu(): Renders a simple menu listing available actions (Fire Cannons, Evade, Repair, End Turn).

Grey out actions the player cannot afford (based on CP).

Update Combat:mousepressed to handle clicks within this action menu. Selecting an action transitions to the "Confirmation" step (Task 4).

Acceptance Criteria:

The static action button bar is gone.

Clicking the player ship in the Action Phase brings up a contextual menu of actions.

Unaffordable actions are clearly indicated (greyed out).

Selecting an available action proceeds to the next step.
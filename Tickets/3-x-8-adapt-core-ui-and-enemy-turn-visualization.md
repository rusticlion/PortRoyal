Adapt Core UI & Enemy Turn Visualization

Description: Ensure the existing minimal HUD, contextual windows, and result overlays function correctly with the new SP system and turn structure. Streamline enemy turn visuals for the new phases.

Tasks:

Update Combat:drawMinimalPlayerStatus to include the currentSP / maxSP display.

Verify that the Ship Info Window (Task UI_Task_2), Action Menu (UI_Task_3), Confirmation Window (UI_Task_4), and Result Overlay (UI_Task_5) still function correctly within the new phase structure. Adjust triggers if necessary.

Refine Combat:processEnemyTurn visualization:

Do not show AI planning details.

During Maneuver Resolution, show the enemy ship moving/rotating simultaneously with the player.

During Action Resolution, use the Result Overlay (Task UI_Task_5) to show the outcome of the enemy's action immediately.

Acceptance Criteria:

Player HUD correctly displays SP.

Existing contextual UI elements (info window, menus, overlays) work as intended in the new turn structure.

Enemy turns resolve visually showing simultaneous movement and clear action results without unnecessary intermediate steps.

Notes: Primarily integration and refinement. Depends on most other 3.X tickets.
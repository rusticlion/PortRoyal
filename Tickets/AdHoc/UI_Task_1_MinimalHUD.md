 Core Tasks:

Task: Implement Minimalist Core Combat HUD

Goal: Redesign the always-on-screen UI to show only the absolute essentials, freeing up screen real estate.

Implementation:

Modify Combat:drawUI.

Keep:

Top Bar: Turn Indicator (Player/Enemy), Phase Indicator (Move/Action), Turn Count. (Keep this compact).

Player Ship Status (Minimal): Small corner display (e.g., bottom-left) showing only current HP/Max HP and current CP/Max CP. Use icons if possible.

Enemy Ship Status (Minimal): Small corner display (e.g., top-right or bottom-right) showing only current HP/Max HP.

Remove (from always-on display):

Static sidebars with full ship details.

Static action button bar at the bottom.

Static action feedback panel.

Acceptance Criteria:

The combat screen has significantly more open space.

Only essential turn/phase info and minimal player/enemy HP/CP are constantly visible.

Static sidebars and action/feedback panels are removed.
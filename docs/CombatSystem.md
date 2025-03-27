# Combat System Documentation

## Overview

The combat system implements naval battles on a 10x10 hex grid. Ships of different classes occupy different numbers of hexes and have different movement speeds. The system includes movement mechanics, combat actions, and dice roll mechanics based on the Forged in the Dark system.

## Hex Grid System

The combat grid uses a "pointy-top" hex coordinate system with the following properties:

- Grid size: 10x10 hexes
- Coordinate system: uses axial coordinates (q,r) where:
  - q increases from west to east
  - r increases from northwest to southeast
  - (0,0) is the top-left hex

## Ship Classes on the Hex Grid

Ship classes have different sizes and shapes on the hex grid:

1. **Sloop (1-Hex Ship)**
   - Occupies 1 hex
   - Speed: 3 hexes per turn
   - Shape: Single hex

2. **Brigantine (2-Hex Ship)**
   - Occupies 2 hexes in a line
   - Speed: 2 hexes per turn
   - Shape: 2 hexes in a row

3. **Galleon (4-Hex Ship)**
   - Occupies 4 hexes in a kite shape
   - Speed: 1 hex per turn
   - Shape: 1 hex bow, 2 hex midship, 1 hex stern

## Combat Flow

1. **Battle Initialization**
   - Player and enemy ships are placed on opposite sides of the hex grid
   - Turn order is established (player first)

2. **Movement Phase**
   - The player can move their ship up to its maximum speed
   - Movement is done one hex at a time to adjacent hexes
   - Ships cannot move through occupied hexes

3. **Attack Phase** (not yet implemented)
   - After movement, ships can attack if in range
   - Attack success is based on dice rolls from the Forged in the Dark system

4. **End of Turn**
   - Turn passes to the enemy
   - The process repeats until one ship is defeated or retreats

## Game State Integration

Combat state is stored in the gameState object under the combat property with the following structure:

```lua
gameState.combat = {
    grid = {},  -- 2D array representing the hex grid
    playerShip = {
        class = "sloop",  -- Ship class (sloop, brigantine, galleon)
        size = 1,         -- Number of hexes occupied
        position = {5, 5}, -- {q, r} coordinates on grid
        orientation = 0,   -- Direction ship is facing (0-5, for 60° increments)
        movesRemaining = 3 -- Based on ship speed
    },
    enemyShip = {
        class = "sloop",
        size = 1,
        position = {2, 2},
        orientation = 3,
        movesRemaining = 3
    },
    turn = "player", -- Whose turn is it (player or enemy)
    phase = "movement", -- Current phase (movement, attack, etc.)
}
```

## Controls

- **Mouse Hover**: Highlights hexes on the grid
- **Click on Player Ship**: Selects the ship and shows valid movement hexes
- **Click on Valid Movement Hex**: Moves the ship to that hex
- **ESC Key**: Exits combat mode
- **C Key**: Debug key to start a test battle

## Triggering Combat

Naval battles can be triggered in two ways:

1. **Random Encounters**: When sailing between zones, there's a 20% chance of encountering an enemy ship
2. **Debug Mode**: Press 'C' key to start a test battle

## Combat Actions

The combat system includes three core actions:

1. **Fire Cannons**: Attack enemy ships
   - Uses the ship's firepower attribute to determine number of dice
   - Each success deals 1 point of damage
   - Damage is applied to the enemy ship's durability

2. **Evade**: Attempt to dodge enemy attacks
   - Uses the ship's class to determine number of dice (sloops get more dice)
   - Each success adds to the ship's evasion rating
   - Evasion rating reduces damage from attacks

3. **Repair**: Fix damage to the ship
   - Base 1 die for repairs
   - Surgeon crew role adds additional dice
   - Each success restores 5 HP to the ship
   - Cannot exceed ship's maximum durability

## Dice Mechanics

The combat system uses a dice pool mechanic based on Forged in the Dark:

- Actions roll a number of six-sided dice (d6) based on ship stats, crew, and modifiers
- Results are categorized:
  - 6: Full success
  - 4-5: Partial success
  - 1-3: Failure
- Outcome is determined by the highest die result, not the sum:
  - If any die shows 6, it's a success
  - If multiple dice show 6, it's a critical success
  - If the highest die is 4-5, it's a partial success
  - If no die shows 4+, it's a failure
- Each outcome level has different effects:
  - Critical Success: Maximum effect (e.g., 3 damage, 15 HP repair)
  - Success: Strong effect (e.g., 2 damage, 10 HP repair)
  - Partial Success: Minimal effect (e.g., 1 damage, 5 HP repair)
  - Failure: No effect

### Modifiers

The system supports modifiers that add or remove dice from action rolls:

- Positive modifiers add dice to the roll (e.g., "+1 die from Point Blank Range")
- Negative modifiers remove dice (e.g., "-2 dice from Target Evading")
- If the total dice count is reduced to 0 or negative, you roll 2 dice and take the worst (lowest) result
- Modifiers can be temporary (one-time use) or persistent (lasting until cleared)

### Action Types with Modifiers

1. **Fire Cannons**:
   - Base dice from ship's firepower attribute
   - +1 die for Point Blank Range (adjacent hex)
   - Negative dice equal to target's evade score

2. **Evade**:
   - Base dice from ship's class (sloop=3, brigantine=2, galleon=1)
   - Result sets ship's evade score until next turn
   - Evade score reduces attacker's dice when ship is targeted

3. **Repair**:
   - Base 1 die
   - Surgeon crew member adds dice equal to their skill level

## Game Flow

1. **Combat Initialization**:
   - Player and enemy ships are placed on the grid
   - Ships are given initial stats based on their class
   - Crew points are allocated based on crew size for the player and ship class for enemies

2. **Turn Structure**:
   - Each turn consists of a movement phase and an action phase
   - During movement phase, players can move their ship based on speed
   - During action phase, players can perform multiple actions based on crew points

3. **Movement Phase**:
   - Player selects their ship and can move to valid hexes
   - Movement is limited by the ship's speed stat
   - Cannot move through occupied hexes

4. **Action Phase**:
   - Player spends crew points to perform actions
   - Actions have different costs:
     - Fire Cannons: 1 CP
     - Evade: 1 CP
     - Repair: 2 CP
   - Multiple actions can be performed as long as crew points are available
   - Action results are calculated using dice rolls
   - Enemy AI takes its turn after the player

5. **End of Turn**:
   - Crew points are replenished for the next turn
   - Movement points are reset

6. **Combat Resolution**:
   - Combat ends when one ship is destroyed (0 durability)
   - Player can also retreat from battle

## Crew Point System

The crew point system connects ship crew size to combat actions:

- Each ship has a maximum number of crew points equal to its crew size
- The player's ship CP is based on the number of crew members
- Enemy ships' CP is based on their class (sloop=2, brigantine=4, galleon=6)
- Crew points are spent to perform actions during the action phase
- This creates an action economy where players must decide which actions are most important
- Larger ships with more crew can perform more actions each turn
- Creates a strategic layer where ship size and crew complement affect combat capability

## Future Enhancements

1. **Ship Orientation**: Implement proper ship orientation and rotation
2. **Wind Effects**: Integrate with the wind system for movement modifiers
3. **Boarding**: Add boarding mechanics for crew-vs-crew combat
4. **Visual Improvements**: Add proper ship sprites and battle animations
5. **Advanced Actions**: Ram, board, special abilities
6. **Crew Integration**: Deeper crew role impacts on combat
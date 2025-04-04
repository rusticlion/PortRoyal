Pirate's Wager: Blood for Gold – Comprehensive Design Document
1. Game Concept Overview
Setting: A pixel-art pirate adventure set in the 17th-century Caribbean, 
centered on Port Royal, culminating in the historical 1692 earthquake as a 
dramatic endgame event.
Core Gameplay: Players captain a pirate ship, juggling tactical naval 
combat and exploration at sea with crew management, investments, and 
faction relationships in Port Royal.
Unique Selling Points:
Dual gameplay loops: tactical combat/exploration at sea and strategic 
management in port.
Dice-based mechanics inspired by Forged in the Dark, emphasizing risk and 
reward.
Hex-grid naval battles for tactical depth.
A 72-week campaign with the earthquake striking randomly between weeks 
60-72, blending urgency with replayability.
A secret ending where players can break a curse and prevent the 
earthquake.
2. Visual Style
Art Direction: Retro pixel art with a limited tile set, layers, and color 
palettes.
Resolution: 800x600 or smaller for a classic aesthetic.
Sea Tiles: Hex-based grid with animated waves indicating wind direction.
Port Phase: Side-view screens for locations (e.g., tavern, shipyard) with 
detailed pixel art and subtle animations (e.g., flickering lanterns, 
swaying palms).
Aesthetic Goals: A gritty yet charming pirate-era Caribbean, balancing 
immersion with clarity in low resolution.
3. Core Gameplay Loops
3.1 At Sea
Exploration:
The Caribbean is split into 10-15 zones (e.g., calm waters, pirate 
territory, naval routes), each with distinct risks and rewards.
Moving between zones or taking major actions (e.g., combat, exploration) 
costs 1 week; movement within a zone (hex-to-hex) is free.
Combat:
Tactical hex-grid battles on a 10x10 hex grid, with ships sized 1-4 hexes 
based on class.
Wind influences movement and combat, varying by sea region (e.g., calm, 
stormy, trade winds).
Actions: Two per turn—one for movement, one for combat/utility:
Fire Cannons: Attack enemies.
Evade: Dodge incoming fire.
Repair: Mend hull damage.
Ram: Deal high-risk hull damage to foes.
Board: Initiate boarding (shifts to side-view combat).
Dice Mechanics: Roll 1-5 d6s based on crew skills, ship stats, and 
context:
6: Success.
4-5: Partial success (e.g., hit with a drawback).
1-3: Failure (e.g., miss or mishap).
Chase Mechanics: If a ship exits the grid, a dice roll decides escape or 
pursuit.
Boarding Combat:
*   Initiated via "Board" action in naval combat.
*   Transitions to side-view, turn-based combat screen with party formation (Front/Back ranks).
*   Crew use `boardingActions` based on their Role and Competencies (MeleeDice, RangedDice, InfluenceDice).
*   Resolution follows FitD principles (Position/Effect -> Dice Pool -> Roll -> Outcome/Consequences). Consequences include HP damage, gaining Conditions, tactical shifts. **(Updated Boarding summary)**

3.2 In Port Royal
*   **Port Phase Structure:** Players manage limited time (weeks) by choosing between repeatable **Activities** (lower risk/reward, immediate outcomes like trade, rumors, recruiting, reducing Heat) and attempting strategic **Claims** (higher risk/reward, persistent benefits/complications like establishing networks, securing assets, gaining influence). **(Added Activity/Claim distinction)**
*   **Claims (Investments):**
    *   Stake resources (Gold, Crew Time, Items, Rep) to establish/upgrade persistent assets (Tavern Influence, Smuggling Ring, Dock Control).
    *   Dice Rolls (FitD): Determine outcome (Crit/Success/Partial/Failure). Modifiers from Crew Competencies, Reputation, Heat, Pirate Code.
    *   Success: Full benefits (passive income, new options, Tier increase).
    *   Partial Success: Benefits with complications (rival attention, Faction Heat, extra cost).
    *   Failure: Lose some resources, gain minor insight or temporary condition ("Fail Forward").
*   **Activities:**
    *   Repeatable actions (Gamble, Gather Rumors, Recruit, Smuggle Cargo, Lay Low, Repair).
    *   Lower cost (Gold, 1 week time).
    *   Dice Rolls (FitD): Determine immediate outcome. Consequences usually temporary setbacks or minor Heat gain.
*   Crew Management: Recruit, train, manage crew (see 5.1). Assign crew to Claims (takes them off ship). Manage crew Conditions gained from hardship.
*   Faction Relationships: Build or strain ties (Pirates, Merchants, Navy, Locals) via actions at sea and in port. Influences Claim/Activity success, prices, available opportunities. (See 5.3).
*   **Pirate Code:** Make defining choices during events, shaping your Captaincy style and affecting Crew/Factions (See 5.6).
*   Earthquake Prep Options: Undertake special Claims/Activities late-game (Fortify Investments, Stockpile Supplies, Evacuation Plans).

4. Ship Classes
Players can command three distinct ship classes, each with unique 
characteristics that influence exploration and combat. These classes are 
defined by their size and shape on the hex grid, affecting their speed, 
firepower, durability, and crew capacity.

4.1 Sloop (1-Hex Ship) – "The Swift Sting"
Description: A small, agile vessel favored by daring pirates and 
smugglers. Ideal for hit-and-run tactics and quick escapes.
Hex Size and Shape: 1 hex, compact and highly maneuverable.
Stats:
Speed: 3 hexes per turn (4 with favorable wind)
Firepower: 2 cannons (1 die per attack)
Durability: 10 HP
Crew Capacity: 4 members
Tactical Role: Excels at evasion and precision strikes. Best for players 
who prefer speed and cunning over brute force.
Flavor: A sleek, low-profile ship with patched sails, built for stealth 
and speed.
Customization: Options include adding a harpoon for boarding or extra 
sails for increased speed.
4.2 Brigantine (2-Hex Ship) – "The Rogue's Balance"
Description: A versatile, mid-sized ship that balances speed and strength. 
Suitable for a wide range of pirate activities.
Hex Size and Shape: 2 hexes in a straight line, sleek and narrow.
Stats:
Speed: 2 hexes per turn (Movement Phase)
Firepower Dice: 3 dice per 'Fire Cannons' action. (Aligned with Design Doc) (Actual cannons: 6)
Durability: 20 HP
Crew Capacity: 8 members (Max 8 CP per turn) (Added CP link)
Tactical Role: A jack-of-all-trades ship, capable of raiding, boarding, or 
engaging in sustained combat.
Flavor: A weathered vessel with a history of battles, its deck adorned 
with trophies from past raids.
Customization: Can be outfitted with additional cannons or a reinforced 
hull for durability.
4.3 Galleon (4-Hex Ship – Kite Shape) – "The Crimson Titan"
Description: A massive, heavily armed ship designed for dominance. Its 
kite shape provides a broad profile for devastating broadsides.
Hex Size and Shape: 4 hexes in a kite arrangement (1 hex bow, 2 hexes 
midship, 1 hex stern), wide and imposing.
Stats:
Speed: 1 hex per turn (Movement Phase)
Firepower Dice: 6 dice per 'Fire Cannons' action. (Aligned with Design Doc) (Actual cannons: 12)
Durability: 40 HP
Crew Capacity: 12 members (Max 12 CP per turn) (Added CP link)
Tactical Role: A slow but powerful ship that excels in head-on combat and 
intimidation. Requires careful positioning due to its size.
Flavor: An ornate, battle-scarred behemoth, its deck laden with gold and 
gunpowder.
Customization: Options include reinforced plating for extra durability or 
enhanced rigging to improve maneuverability.
4.4 Ship Classes and the Hex Grid
Sloop (1-hex): Highly agile, able to dart through tight spaces and evade 
larger ships. Its small size makes it a difficult target.
Brigantine (2-hex): Balanced maneuverability, able to pivot and reposition 
effectively while maintaining a clear broadside arc.
Galleon (4-hex, kite shape): Slow to turn, requiring strategic use of wind 
and positioning. Its wide midsection allows for powerful broadsides from 
multiple angles but makes navigation in confined areas challenging.
4.5 Progression and Balance
Sloop: High-risk, high-reward gameplay focused on speed and precision.
Brigantine: Versatile and adaptable, suitable for a range of strategies.
Galleon: Emphasizes raw power and resilience, ideal for players who prefer 
overwhelming force.
Upgrades: Players can enhance speed, firepower, or durability within each 
class to suit their playstyle.
5. Mechanics Deep Dive
5.1 Crew System
*   Crew Roles: Navigator, Gunner, Surgeon, Swashbuckler, Quartermaster, Carpenter etc. Defines core function and potential unique `boardingActions`.
*   **Character Sheet:**
    *   `Role`: Defines specialty.
    *   **Competencies:** `MeleeDice`, `RangedDice`, `TechnicalDice`, `InfluenceDice` (Base dice pool, e.g., 0-3, for relevant actions).
    *   `Health`: Max HP. Reaching 0 = Injury/Death status.
    *   `Conditions`: Temporary negative states affecting stats/actions (e.g., "Injured Arm" -1 MeleeDice, "Shaken" -1 InfluenceDice). Gained via consequences, cleared by Port Activities/time.
    *   `LoyaltyFactors`: Narrative list of +/- factors influencing behavior (e.g., "Paid well", "Disagrees with Code"). Net sentiment impacts willingness/rolls.
    *   `Boon/Bane`: One positive/negative trait (e.g., "Sea Legs", "Greedy"). Adds flavor and minor mechanical effects.
    *   `Experience/Level`: Gain XP, level up to improve Competencies, gain Traits or `boardingActions`.
    *   `BoardingActions`: List of specific actions usable in boarding combat.
    *   `Status`: Active, Injured, Disgruntled, Loyal, Captured, Dead.
    *   `CodeAlignment`: Notes agreement/disagreement with Captain's Pirate Code points.
*   Recruitment: Found in Taverns (Activity roll?) or via quests. Costs Gold. Check `codeAlignment`?
*   Advancement: Gain XP, level up via Training Activities or successful missions.

5.2 Item System
Types:
Resources: Bulk goods (e.g., rum, timber) tracked numerically.
Treasures: Unique items (e.g., maps, jewels) taking inventory slots.
Equipment: Gear for crew/ship (e.g., cannons, sails).
Inventory: Ship hold has 10 slots, expandable in port.
Staking: Items/crew committed to actions; failure risks partial loss.
5.3 Reputation System
*   Factions: Pirates, Merchants, Navy, Locals. Scale: -3 to +3.
*   Shifts: Actions at sea (raiding, trading) and in port (Claims, Activities, Quests) adjust Rep. Pirate Code choices significantly impact Rep. **(Added Pirate Code link)**
*   Impact: Affects access, prices, Claim/Activity modifiers & availability, Quest availability, Faction Heat generation. High/Low Rep unlocks unique opportunities/dangers.

5.4 Passage of Time
*   Timeline: 72 weeks...
*   At Sea: Zone movement costs time... Naval combat itself doesn't consume weeks, but the actions leading to it or resolving it might. Boarding actions occur within the naval combat turn structure. **(Clarified combat time)**
*   In Port: **Activities** typically cost 1 week. **Claims** cost 1-3+ weeks. Recruiting, Training, Repairing cost time.
*   Hints: NPC rumors and tremors...

5.5 Economic Systems
*   Trade Routes: Buy low, sell high (Market Activity). Prices influenced by Merchant Rep, potentially zone events/supply.
*   Smuggling: Buy/sell Contraband (Smuggle Activity). Higher risk/reward, uses FitD roll, generates Heat, influenced by Pirate/Local Rep & Navy Heat.
*   Claim Income: Successful Claims generate passive Gold or Resources over time.
*   Missions: Faction quests offer rewards (Gold, Items, Rep).
*   Raiding: Loot from defeated ships (Gold, Cargo, potentially Crew/Items).

**5.6 Pirate Code** **(New Section)**
*   **Establishing the Code:** Through specific narrative events and dilemmas, player chooses between opposing stances (e.g., Mercy vs No Quarter, Fair Shares vs Captain's Cut, Deception vs Honesty). Choices are recorded in `gameState.pirateCode`.
*   **Defining Captaincy:** The collection of Code choices shapes the player's reputation and perceived Captaincy style (e.g., Dread Pirate, Honorable Privateer, Cunning Smuggler).
*   **Impact - Factions:** Code choices heavily influence Faction Reputation gains/losses. Some Factions favor specific codes.
*   **Impact - Crew:** Crew members react based on their own `codeAlignment` traits, affecting their `loyaltyFactors`. Consistent alignment builds loyalty; contradiction breeds discontent. May affect recruitment options.
*   **Impact - Gameplay:** Unlocks/blocks specific Claim opportunities, dialogue options, quest solutions, or Activity modifiers. May influence event outcomes.

6. Port Phase Details
*   Presentation: Side-view screens...
*   Interactions: Click to access Activities (Tavern, Shipyard, Market) or strategic Claims screen. Occasional mini-events.
*   Purpose: Hub for managing crew (recruitment, condition recovery), ship (repairs), resources (trade/smuggling), strategy (Claims, Faction management), and reflecting on Pirate Code choices. **(Updated Purpose)**

7. Combat System
*   **Naval Combat:**
    *   Hex Grid: 10x10...
    *   Maneuvering: Simultaneous resolution using SP for Movement + Rotation planning.
    *   Actions: Planned after maneuvering, executed using CP. Targeting restricted by Firing Arcs.
    *   Dice Pools (FitD): Based on ship, crew (Competencies), context. Resolve with consequences.
*   **Boarding Combat:**
    *   Triggered by 'Board' action.
    *   Side-view, turn-based, party formation.
    *   Crew use `boardingActions` tied to their Competencies (MeleeDice, RangedDice etc.).
    *   **Resolution (FitD):** Determine Position/Effect -> Assemble Dice Pool -> Roll -> Interpret Outcome (Crit/Success/Partial/Failure) -> Apply Effect & Consequences (HP Damage, Conditions, etc.). **(Clarified FitD resolution)**

8. Modular Systems
*   Ship Customization: Hulls, sails, cannons... Specific upgrades might align with Pirate Code styles. **(Added Code link)**
*   Crew Roles and Traits: Combinatorial depth based on Competencies, Roles, Traits, Conditions.
*   Claims: Strategic port assets offering stacking perks and interactions.

9. Narrative and Supernatural Elements
*   Cursed Prophecy...
*   Secret Ending...
*   Low Fantasy...
*   **Pirate Code Events:** Key narrative moments will present Code choices.

10. Difficulty and Progression
*   Scaling Enemies...
*   Event Escalation...
*   Advancement via: Ship Upgrades, successful Claims (increasing Tier?), Crew Leveling. **(Added Claims/Tier)**
*   Win/Loss Conditions...

11. Strategic Paths
*   Merchant Focus: Wealth via trade and Claims, possibly aligning Code towards 'Honesty' or 'Fairness' for Merchant rep.
*   Combat Focus: Raiding, crew dominance, possibly aligning Code towards 'Ruthlessness' or 'Pirate Brotherhood' for Pirate rep.
*   Balanced Approach: Mix raiding and Claims, navigating Faction demands and Code choices carefully.
*   **Captaincy Style:** The chosen Pirate Code will heavily influence the available strategies and narrative outcomes. **(Emphasized Code impact)**

12. Project Name
*   Working Title: Pirate's Wager: Blood for Gold

13. Next Steps
*   Implement UI Clarity / Simultaneous Maneuvering / Firing Arcs sprint.
*   Implement Port Phase Dynamics / Economy sprint (Claims, Activities, Factions, Trade/Smuggle).
*   Implement revised Crew System & Boarding Combat sprint.
*   Define specific Claims, Activities, Code Events, and Traits.
*   Playtest extensively to balance combat, economy, and FitD consequences.
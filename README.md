Legacy b41 version: access [Last commit from B41](https://github.com/LeandroTheDev/project_factions/tree/25b168e77add44a12f5f35f02ec0fd80618451be)

B42: currently

# Official Server
The aionthera project have a official server running this project that you can test it:

``IP``: projectzomboid.aionthera.org

``Ports``: 16261

``Country``: Brazil
# Factions

Singleplayer Compatibility: No, factions are a multiplayer concept

Forked from [SSR: Safehouse](https://steamcommunity.com/sharedfiles/filedetails/?id=1178772929&searchtext=Safehouse) to create a complete new system to safehouse claim

- UI to show the safehouse informations
- Faction safehouse claim system, multiple safehouses per faction gated by points earned from zombie kills (requires the java class override below, since b42 hardcodes one safehouse per player)
- Configurable zombie kills to earn points

Requires the safehouse limit patch in the folder [Server Configuration](https://github.com/LeandroTheDev/project_factions/tree/main/Server%20Configuration) placed in the main project zomboid dedicated server folder, otherwise the vanilla one-safehouse-per-player limit still applies

# Factions Economy
Add a new shop system, forked from [Server Points](https://steamcommunity.com/sharedfiles/filedetails/?id=2823055977&searchtext=Server+Points), and a Global Trade system, includes Loot Boxes and farm economy system by exploring and local farming vegetables/fruits.

- Shop UI
- Trade UI (Reworking...)
- Lootboxes
- Economy currency that can be returned to get points for the shop and trade
- Sell vegetables/fruits
- > I recommend changing vanilla sandbox ``Farming Speed`` to ``50`` and ``Farming Abundance`` to ``0.1`` to make vegetables balanced
- Scrap Weapons to earn the stackable scrap (bigger the scrap the more economy currency you will earn)
- [Random Hordes](https://github.com/LeandroTheDev/random_hordes) currency give on horde survival
- Safehouse Passive Currency Give
- Upgrade Safehouse
- Scoreboard for the most rich players

# Factions Plus
Add new features and adjustments for playing in any anarchy/infinite server.

- Reduced seed drop by crops
- Reduced water need for fully crop
- Disable rotten crops mechanic
- > I recommend changing vanilla sandbox ``Plant Resilience`` to ``Very High`` to not lose water when player is offline or busy in crop final stage
- Connections/Disconnections/Death player messages events (Multiplayer only)
- Weekly turn off and on water and electric
- Reset world start age making food and items (prevent respawning rotten foods or broken equipment)
- Vehicle Claim system (compatible with factions economy)
- MOTD command forked from [SSR: News](https://steamcommunity.com/sharedfiles/filedetails/?id=1178773471)

# Safehouse Plus
Respawn mechanics forked from [Keep Inventory](https://steamcommunity.com/sharedfiles/filedetails/?id=2879960829), and create door key system

- Create key in Safehouse
- Respawn Keep Inventory

#

### Questions
- Can i use in my server? yes
- Can i reupload this to workshop? yes
- Can i modify this project? yes
- Can i share this project? yes
- Can i steal this project? only if the name is changed
- Can i charge for this project? only if the name is changed

### Submodules
External very useful mods to make the factions better
- [Random Airdrops 2](https://github.com/LeandroTheDev/random_airdrops_2), add random airdrops to the server
- [RA Smoke Flares](https://github.com/LeandroTheDev/ra_smoke_flares), add smoke flares to call any airdrop
- [Random Hordes](https://github.com/LeandroTheDev/random_hordes), add random hordes to the server
- [Factions Weapons - TODO](https://github.com/LeandroTheDev/factions_weapons), overhaul the weapons to make it more immersive and fun to play with
- [Factions Clothes - TODO](), add a set of military and factions friendly clothes to give more options for factions teams

- > To download the submodules you can use ``git submodule init``, ``git submodule update`` in your terminal
- > To get the latest submodules commit: `git submodule update --remote``

### Using the project in the Server
- Install git in your operational system (Or you can simple clone the repository and the submodules)
- In your terminal type: git clone --recurse-submodules https://github.com/LeandroTheDev/project_factions
- > Or if you already cloned without submodules: ``git submodule update --init --recursive``
- To update the modules to latest version:
```
git submodule foreach git fetch
git submodule foreach git checkout main
git submodule foreach git pull
```
- Copy all mods from the new folder created, and paste on your project zomboid mods folder
- > You can also upload to workshop to automatically users download this project
- Now you can open the game, enable the mods and change the sandbox configurations
- > Some mods require special configurations in Lua, after starting the server take a look in the Lua folder, you can view templates in [Server Configuration](https://github.com/LeandroTheDev/project_factions/tree/main/Server%20Configuration) folder
- > Also some mods needs modifications in the java class to work propertly, consider checking the [Server Configuration](https://github.com/LeandroTheDev/project_factions/tree/main/Server%20Configuration) folder

Load Order:
- Factions
- Factions Economy
- Factions Plus
- Safehouse Plus
- Random Hordes
- Random Airdrops 2
- RA Smoke Flares
- Factions Weapons
- Factions Clothes

FTM License
Legacy b41 version: access [Last commit from B41](https://github.com/LeandroTheDev/project_factions/tree/25b168e77add44a12f5f35f02ec0fd80618451be)

B42: currently
# Factions (Reworking...) do not use it
Singleplayer Compatibility: No, theres is no reason to add a capture system in singleplayer

Forked from [SSR: Safehouse](https://steamcommunity.com/sharedfiles/filedetails/?id=1178772929&searchtext=Safehouse) to create a complete new system to safehouse claim and capture

- UI to show the safehouse informations
- Capture safehouse system
- Multiple Safehouses (Need server configuration)
- Chat alert for actions (capturing, losing, captured, lost)
- Configurable time to enable safehouse capture invasion, also timezone
- Configurable zombie kills to earn points
- Configurable player construction health while in capture mode
- Players can only try to capture safehouse one time per game day

Consider downloading the safehouse limit remover in the folder [Server Configuration](https://github.com/LeandroTheDev/project_factions/tree/main/Server%20Configuration) and place it in the main project zomboid dedicated server folder

# Factions Economy
Add a new shop system, forked from [Server Points](https://steamcommunity.com/sharedfiles/filedetails/?id=2823055977&searchtext=Server+Points), and a Global Trade system, includes Loot Boxes and farm economy system by exploring and local farming vegetables/fruits.

- Shop UI
- Trade UI (Reworking...)
- Lootboxes
- Economy currency that can be returned to get points for the shop and trade
- Sell vegetables/fruits
- > I recommend changing vanilla sandbox ``Farming Speed`` to ``50`` and ``Farming Abundance`` to ``0.1`` to make vegetables balanced
- Scrap Weapons to earn the stackable scrap (bigger the scrap the more economy currency you will earn)
- Safehouse Passive Currency Give (Reworking...)
- Upgrade Safehouse (Reworking...)

# Factions Plus
Add new features and adjustments for playing in any anarchy/infinite server.

- Reduced seed drop by crops
- Reduced water need for fully crop
- Disable rotten crops mechanic
- > I recommend changing vanilla sandbox ``Plant Resilience`` to ``Very High`` to not lose water when player is offline or busy in crop final stage
- Connections/Disconnections/Death player messages events (Multiplayer only)
- Weekly turn off and on water and electric
- Reset world start age making food and itens not spawn as rotten or broken

# Safehouse Plus
Singleplayer Compatibility: Yes

Add several new mechanics to safehouses, with the upgrader you can increase the house level to gain more Points in the Server, you can easily create keys for your safehouse, and new
respawn mechanics forked from [Keep Inventory](https://steamcommunity.com/sharedfiles/filedetails/?id=2879960829)

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
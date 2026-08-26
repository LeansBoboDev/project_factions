#!/bin/sh
echo "Auto build script"

if [ -z "$PROJECT_ZOMBOID_MODS_FOLDER" ]; then
    read -p "Please enter the path to the Project zomboid mods folder: " PROJECT_ZOMBOID_MODS_FOLDER
    export PROJECT_ZOMBOID_MODS_FOLDER
fi

copy_mod() {
    mod_name="$1"
    mod_path="./$mod_name"
    dest_path="$PROJECT_ZOMBOID_MODS_FOLDER/$mod_name"

    if [ -d "$mod_path" ]; then
        echo "Removing existing mod at: $dest_path"
        rm -rf "$dest_path"
        echo "Copying: $mod_name"
        cp -r "$mod_path" "$PROJECT_ZOMBOID_MODS_FOLDER"
    else
        echo "Warning: '$mod_path' not found, skipping."
    fi
}

copy_module() {
    mod_name="$1"
    mod_path="./$mod_name/$mod_name"
    dest_path="$PROJECT_ZOMBOID_MODS_FOLDER/$mod_name"

    if [ -d "$mod_path" ]; then
        echo "Removing existing mod at: $dest_path"
        rm -rf "$dest_path"
        echo "Copying: $mod_name"
        cp -r "$mod_path" "$PROJECT_ZOMBOID_MODS_FOLDER"
    else
        echo "Warning: '$mod_path' not found, skipping."
    fi
}

echo "Copying server config files to Zomboid/Lua/"
cp -rv "./Server Configuration/Lua/42/"* "/home/leans/Zomboid/Lua/"

copy_mod "Factions"
copy_mod "Factions Economy"
copy_mod "Factions Plus"
copy_module "RA Smoke Flares"
copy_module  "Random Airdrops 2"
copy_mod "Safehouse Plus"
copy_module "Random Hordes"
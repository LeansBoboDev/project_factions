Place this folder inside your project zomboid dedicated server and overwrite

## java/ class overrides

Three recompiled, patched replacements for vanilla server classes:

- `java/zombie/iso/areas/SafeHouse.class`
- `java/zombie/network/packets/safehouse/SafehouseClaimPacket.class`
- `java/zombie/network/anticheats/AntiCheatSafeHouseNotMember.class` *(added in 42.20)*

Together they remove the vanilla "one safehouse per player" block and add a
server-side `OnSafehouseClaimed` Lua event so the Factions mod can enforce its
own points-based limit instead (see `Factions/42/media/lua/server/safehouse.lua`).
The dedicated server's classpath loads this `java/` folder before the game's
own jar, so these overwrite the vanilla classes at runtime without touching
`projectzomboid.jar` itself.

The matching `.java` sources (with the exact diff already applied) sit next to
each `.class` file, and `build.sh` (in this folder's root) recompiles them.

### When you need to redo this (game updates)

A PZ update can change these three classes and break the override (server fails
to start, throws `NoSuchMethodError`/`IncompatibleClassChangeError` on load, or
the safehouse limit silently comes back). When that happens:

1. Decompile the new `projectzomboid.jar` with [CFR](https://www.benf.org/other/cfr/)
   (`java -jar cfr.jar projectzomboid.jar --outputdir out`) to get fresh vanilla
   sources for:
   - `zombie/iso/areas/SafeHouse.java`
   - `zombie/network/packets/safehouse/SafehouseClaimPacket.java`
   - `zombie/network/anticheats/AntiCheatSafeHouseNotMember.java`
2. Diff those fresh vanilla files against the patched ones already in this
   `java/` folder to see exactly what our patch changed (each file has a
   comment block at the top listing the intent):
   - `SafeHouse.java`: in `canBeSafehouse(...)`, the `if` block that adds
     `IGUI_Safehouse_AlreadyHaveSafehouse` to `reason` when
     `SafeHouse.hasSafehouse(player) != null` is deleted entirely. A
     `removeSafeHouseAndSync(SafeHouse)` static method is added (copy it in,
     right after `removeSafeHouse`). The final `return reason;` in
     `canBeSafehouse` needs a `(String)` cast (`reason` is declared as
     `Object` by the decompiler) — add it if javac complains about that line.
     In `allowSafeHouse(...)`, the same "already has a safehouse" check is
     also removed (`allowed = true` instead of `allowed = SafeHouse.hasSafehouse(player) == null`) for consistency, though nothing currently calls this method.
   - `SafehouseClaimPacket.java`: add `import zombie.Lua.LuaEventManager;`,
     and in `processServer(...)`, right after `safehouse.setTitle(this.getTitle());`,
     insert:
     ```java
     LuaEventManager.triggerEvent("OnSafehouseClaimed", safehouse, this.getPlayer());
     if (!SafeHouse.getSafehouseList().contains(safehouse)) {
         return;
     }
     ```
     before the existing `INetworkPacket.sendToAll(PacketTypes.PacketType.SafehouseSync, safehouse);` line.
   - `AntiCheatSafeHouseNotMember.java`: in `validate(...)`, the vanilla block
     that returns `"player already has safehouse"` when
     `SafeHouse.hasSafehouse(player) != null` is removed entirely. The method
     should fall through to `return result;` without that check.
3. Apply the same two edits to the freshly decompiled files, replace the
   `.java` files in this folder with them.
4. Run `./build.sh "<path to the new projectzomboid.jar>"` — it
   auto-detects the required `--release` version from the jar itself and
   recompiles both `.class` files in place.
5. Copy this whole `Server Configuration/42` folder into the dedicated
   server install (overwrite), restart, and confirm a faction can claim a
   second safehouse and that going over the faction's points budget rejects
   the claim (server log / chat should show the rollback).

If CFR ever fails to produce compilable output (decompilers occasionally
produce code javac rejects, as happened once with the `Object reason` typing
above), fix only the specific line javac complains about — don't rewrite
surrounding logic, since the goal is to stay behaviourally identical to
vanilla except for the two intentional changes above.

/*
 * Decompiled with CFR 0.152.
 *
 * PATCH: removed the SafeHouse.hasSafehouse() check so players who already
 * own a safehouse are not blocked from claiming a second one. The Factions
 * mod enforces its own points-based limit via OnSafehouseClaimed instead.
 */
package zombie.network.anticheats;

import zombie.characters.Capability;
import zombie.core.raknet.UdpConnection;
import zombie.debug.DebugType;
import zombie.network.anticheats.AbstractAntiCheat;
import zombie.network.packets.INetworkPacket;

public class AntiCheatSafeHouseNotMember
extends AbstractAntiCheat {
    @Override
    public String validate(UdpConnection connection, INetworkPacket packet) {
        String result = super.validate(connection, packet);
        if (connection.getRole().hasCapability(Capability.CanSetupSafehouses)) {
            return result;
        }
        if (!(packet instanceof IAntiCheat)) {
            DebugType.Multiplayer.error("Invalid packet-type=%s for anti-cheat=%s", packet.getClass().getSimpleName(), this.getClass().getSimpleName());
            return "";
        }
        IAntiCheat field = (IAntiCheat)((Object)packet);
        if (!connection.hasPlayer(field.getUsername())) {
            return "player not found";
        }
        // PATCHED: removed hasSafehouse check — Factions enforces its own limit
        return result;
    }

    public static interface IAntiCheat {
        public String getUsername();
    }
}

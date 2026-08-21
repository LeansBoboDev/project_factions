/*
 * Patched for project_factions (b42): fires a server-side "OnSafehouseClaimed" Lua
 * event right after a safehouse is created, so a mod can validate/charge for it
 * (e.g. faction points) and roll the claim back via SafeHouse.removeSafeHouseAndSync
 * before it gets synced to clients. Needed because Events.OnSafehousesChanged never
 * fires on a dedicated server (SafeHouse only triggers it when GameClient.client).
 * Based on the CFR 0.152 decompile of zombie.network.packets.safehouse.SafehouseClaimPacket.
 */
package zombie.network.packets.safehouse;

import zombie.Lua.LuaEventManager;
import zombie.characters.Capability;
import zombie.characters.IsoPlayer;
import zombie.core.network.ByteBufferReader;
import zombie.core.network.ByteBufferWriter;
import zombie.core.raknet.UdpConnection;
import zombie.debug.DebugType;
import zombie.iso.IsoGridSquare;
import zombie.iso.areas.SafeHouse;
import zombie.network.IConnection;
import zombie.network.JSONField;
import zombie.network.PacketSetting;
import zombie.network.PacketTypes;
import zombie.network.anticheats.AntiCheat;
import zombie.network.anticheats.AntiCheatSafeHouseNotMember;
import zombie.network.chat.ChatServer;
import zombie.network.fields.SafeHouseTitle;
import zombie.network.fields.Square;
import zombie.network.packets.INetworkPacket;

@PacketSetting(ordering=0, priority=1, reliability=2, requiredCapability=Capability.LoginOnServer, handlingType=1, anticheats={AntiCheat.SafeHousePlayer})
public class SafehouseClaimPacket
extends SafeHouseTitle
implements INetworkPacket,
AntiCheatSafeHouseNotMember.IAntiCheat {
    @JSONField
    private final Square square = new Square();

    @Override
    public void setData(Object ... values2) {
        super.set((IsoPlayer)values2[1], (String)values2[2]);
        this.square.set((IsoGridSquare)values2[0]);
    }

    @Override
    public void parse(ByteBufferReader b, IConnection connection) {
        super.parse(b, connection);
        this.square.parse(b, connection);
    }

    @Override
    public void write(ByteBufferWriter b) {
        super.write(b);
        this.square.write(b);
    }

    @Override
    public boolean isConsistent(IConnection connection) {
        if (!super.isConsistent(connection)) {
            return false;
        }
        if (!this.square.isConsistent(connection)) {
            DebugType.Multiplayer.error("square is not found");
            return false;
        }
        if (SafeHouse.getSafeHouse(this.square.getSquare()) != null) {
            DebugType.Multiplayer.error("safehouse is already claimed");
            return false;
        }
        if (this.square.getSquare().getBuilding() == null) {
            DebugType.Multiplayer.error("building not found");
            return false;
        }
        return true;
    }

    @Override
    public void processServer(PacketTypes.PacketType packetType, UdpConnection connection) {
        String reason = SafeHouse.canBeSafehouse(this.square.getSquare(), this.getPlayer());
        if (!"".equals(reason)) {
            DebugType.Multiplayer.error("can't be safehouse: %s", reason);
            return;
        }
        SafeHouse safehouse = SafeHouse.addSafeHouse(this.square.getSquare(), this.getPlayer());
        safehouse.setTitle(this.getTitle());
        LuaEventManager.triggerEvent("OnSafehouseClaimed", safehouse, this.getPlayer());
        if (!SafeHouse.getSafehouseList().contains(safehouse)) {
            return;
        }
        INetworkPacket.sendToAll(PacketTypes.PacketType.SafehouseSync, safehouse);
        ChatServer.getInstance().createSafehouseChat(safehouse.getId());
        ChatServer.getInstance().syncSafehouseChatMembers(safehouse.getId(), safehouse.getOwner(), safehouse.getPlayers());
    }
}

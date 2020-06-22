local Player = FindMetaTable("Player")

-- items
function Player:PS_GetItems()
    return self.PS_Items or {}
end

function Player:PS_HasItem(item_id)
    return self.PS_Items and self.PS_Items[item_id] ~= nil
end

function Player:PS_HasItemEquipped(item_id)
    return self:PS_HasItem(item_id) and self.PS_Items[item_id].Equipped
end

function Player:PS_BuyMarketplaceItem(announce_id)
    net.Start("PS_BuyMarketplaceItem")
    net.WriteInt(announce_id, 32)
    net.SendToServer()
end

function Player:PS_BuyItem(item_id)
    local item = PS.Items[item_id]
    local category = PS:FindCategoryByName(item.Category)

    if not category.CanHaveMultiples and self:PS_HasItem(item_id) then
        return false
    elseif not self:PS_HasPoints(PS.Config.CalculateBuyPrice(self, item)) then
        return false
    end

    net.Start("PS_BuyItem")
    net.WriteString(item_id)
    net.SendToServer()
end

function Player:PS_SellItem(item_id)
    if not self:PS_HasItem(item_id) then return false end
    net.Start("PS_SellItem")
    net.WriteString(item_id)
    net.SendToServer()
end

function Player:PS_EquipItem(item_id)
    if not self:PS_HasItem(item_id) then return false end
    net.Start("PS_EquipItem")
    net.WriteString(item_id)
    net.SendToServer()
end

function Player:PS_HolsterItem(item_id)
    if not self:PS_HasItem(item_id) then return false end
    net.Start("PS_HolsterItem")
    net.WriteString(item_id)
    net.SendToServer()
end

-- points
function Player:PS_GetPoints()
    return self.PS_Points or 0
end

function Player:PS_HasPoints(points)
    return self:PS_GetPoints() >= points
end

-- clientside models
function Player:PS_AddClientsideModel(item_id)
    if not PS.Items[item_id] then return false end
    local ITEM = PS.Items[item_id]

    if not PS.ClientsideModels[self] then
        PS.ClientsideModels[self] = {}
    end

    PS.ClientsideModels[self][item_id] = ClientsideModel(ITEM.Model, RENDERGROUP_OPAQUE)
    PS.ClientsideModels[self][item_id]:SetNoDraw(true)
end

function Player:PS_RemoveClientsideModel(item_id)
    if not PS.Items[item_id] or not PS.ClientsideModels[self] or not PS.ClientsideModels[self][item_id] then return false end
    PS.ClientsideModels[self][item_id] = nil
end
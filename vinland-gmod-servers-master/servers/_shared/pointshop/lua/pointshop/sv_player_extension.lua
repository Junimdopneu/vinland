PS_ITEM_EQUIP = 1
PS_ITEM_HOLSTER = 2
PS_ITEM_MODIFY = 3
local Player = FindMetaTable("Player")

-- public functions
function Player:PS_PlayerSpawn()
    if not self.PS_Items then return end

    for item_id, item in pairs(self.PS_Items) do
        local ITEM = PS.Items[item_id]

        if item.Equipped and not ITEM.SupressEquip then
            if self:PS_CanEquipItem(ITEM) then
                local CATEGORY = PS:FindCategoryByName(ITEM.Category)

                if ITEM.OnEquip then
                    ITEM:OnEquip(self, item.Modifiers)
                elseif CATEGORY.OnEquip then
                    CATEGORY:OnEquip(self, item.Modifiers, ITEM)
                end
            else
                PS:SetPlayerItemEquipped(self, item_id, false)
            end
        end
    end
end

function Player:PS_PlayerDeath()
    if not self.PS_Items then return end

    for item_id, item in pairs(self.PS_Items) do
        if item.Equipped then
            local ITEM = PS.Items[item_id]

            if ITEM then
                local CATEGORY = PS:FindCategoryByName(ITEM.Category)

                if ITEM.OnHolster then
                    ITEM:OnHolster(self, item.Modifiers)
                elseif CATEGORY.OnHolster then
                    CATEGORY:OnHolster(self, item.Modifiers, ITEM)
                end
            end
        end
    end
end

function Player:PS_PlayerInitialSpawn()
    -- Send stuff
    timer.Simple(1, function()
        if IsValid(self) then
            self:PS_LoadData()
            self:PS_SendClientsideModels()
        end
    end)

    if PS.Config.NotifyOnJoin then
        if PS.Config.ShopKey ~= "" then
            timer.Simple(5, function()
                -- Give them time to load up
                if not IsValid(self) then return end
                self:PS_Notify("Aperte " .. PS.Config.ShopKey .. " para abrir a loja!")
            end)
        end

        if PS.Config.ShopChatCommand ~= "" then
            timer.Simple(5, function()
                -- Give them time to load up
                if not IsValid(self) then return end
                self:PS_Notify("Escreva " .. PS.Config.ShopChatCommand .. " no chat para abrir a loja!")
            end)
        end

        timer.Simple(10, function()
            -- Give them time to load up
            if not IsValid(self) then return end
            self:PS_Notify("Você tem " .. self:PS_GetPoints() .. " " .. PS.Config.PointsName .. " para gastar!")
        end)
    end
end

function Player:PS_PlayerDisconnected()
    PS.ClientsideModels[self] = nil

    if timer.Exists("PS_PointsOverTime_" .. self:UniqueID()) then
        timer.Remove("PS_PointsOverTime_" .. self:UniqueID())
    end
end

function Player:PS_LoadData()
    PS:GetPlayerPoints(self, function(points)
        self.PS_Points = points
        self:PS_SendPoints()
    end)

    PS:GetPlayerItems(self, function(items)
        self.PS_Items = items
        self:PS_SendItems()
    end)
end

-- points
function Player:PS_GivePoints(points)
    self.PS_Points = self.PS_Points + points
    PS:GivePlayerPoints(self, points)
    self:PS_SendPoints()
end

function Player:PS_TakePoints(points)
    self.PS_Points = self.PS_Points - points >= 0 and self.PS_Points - points or 0
    PS:TakePlayerPoints(self, points)
    self:PS_SendPoints()
end

function Player:PS_SetPoints(points)
    self.PS_Points = points
    PS:SetPlayerPoints(self, points)
    self:PS_SendPoints()
end

function Player:PS_GetPoints()
    return self.PS_Points and self.PS_Points or 0
end

function Player:PS_HasPoints(points)
    return self.PS_Points >= points
end

function Player:PS_IsElegibleForDouble()
    return string.match(string.lower(self:GetName()), "lory") or self:PS_HasItemEquipped("doublepoints")
end

-- give/take items
function Player:PS_GiveItem(item_id)
    if not PS.Items[item_id] then return false end

    local defaultProps = {
        Modifiers = {},
        Equipped = false
    }

    if PS:FindCategoryByName(PS.Items[item_id].Category).CanHaveMultiples then
        if not self.PS_Items[item_id] then
            self.PS_Items[item_id] = {}
        end

        table.insert(self.PS_Items[item_id], defaultProps)
    else
        self.PS_Items[item_id] = defaultProps
    end

    PS:GivePlayerItem(self, item_id)
    self:PS_SendItems()

    return true
end

function Player:PS_TakeItem(item_id)
    if not PS.Items[item_id] then return false end
    if not self:PS_HasItem(item_id) then return false end

    if PS:FindCategoryByName(PS.Items[item_id].Category).CanHaveMultiples then
        table.remove(self.PS_Items[item_id])

        if #self.PS_Items[item_id] == 0 then
            self.PS_Items[item_id] = nil
        end
    else
        self.PS_Items[item_id] = nil
    end

    PS:TakePlayerItem(self, item_id)
    self:PS_SendItems()

    return true
end

-- buy/sell items
function Player:PS_BuyMarketplaceItem(announce_id)
    PS.DataProvider:GetBuyableAnnounces(function(announces)
        for k, announce in ipairs(announces) do
            if tonumber(announce.id) == announce_id then
                local points = tonumber(announce.price)
                local ITEM = PS.Items[announce.item_id]
                if not self:PS_HasPoints(points) or not self:PS_CanEquipItem(ITEM) then return end

                local allowed, message

                if (type(ITEM.CanPlayerBuy) == "function") then
                    allowed, message = ITEM:CanPlayerBuy(self)
                elseif (type(ITEM.CanPlayerBuy) == "boolean") then
                    allowed = ITEM.CanPlayerBuy
                end

                if not allowed then
                    self:PS_Notify(message or "Você não pode comprar isso!")

                    return
                end

                PS.DataProvider:SetAnnounceBuyer(announce.id, self:SteamID64())
                PS.DataProvider:GivePoints(announce.seller_sid64, points)
                self:PS_TakePoints(points)
                self:PS_Notify("Comprou ", ITEM.Name, " por ", points, " ", PS.Config.PointsName)
                local CATEGORY = PS:FindCategoryByName(ITEM.Category)

                if ITEM.OnBuy then
                    ITEM:OnBuy(self)
                elseif CATEGORY.OnBuy then
                    CATEGORY:OnBuy(self, ITEM)
                end

                hook.Call("PS_ItemPurchased", nil, self, announce.item_id)

                self:PS_GiveItem(announce.item_id)

                if not ITEM.SupressEquip then
                    self:PS_EquipItem(announce.item_id)
                end
                return
            end
        end

        self:PS_Notify("Anuncio não encontrado!")
    end)
end

function Player:PS_BuyItem(item_id)
    local ITEM = PS.Items[item_id]
    if not ITEM then return false end
    local points = PS.Config.CalculateBuyPrice(self, ITEM)
    if not self:PS_HasPoints(points) or not self:PS_CanEquipItem(ITEM) then return false end
    local allowed, message

    if (type(ITEM.CanPlayerBuy) == "function") then
        allowed, message = ITEM:CanPlayerBuy(self)
    elseif (type(ITEM.CanPlayerBuy) == "boolean") then
        allowed = ITEM.CanPlayerBuy
    end

    if not allowed then
        self:PS_Notify(message or "Você não pode comprar isso!")

        return false
    end

    self:PS_TakePoints(points)
    self:PS_Notify("Comprou ", ITEM.Name, " por ", points, " ", PS.Config.PointsName)
    local CATEGORY = PS:FindCategoryByName(ITEM.Category)

    if ITEM.OnBuy then
        ITEM:OnBuy(self)
    elseif CATEGORY.OnBuy then
        CATEGORY:OnBuy(self, ITEM)
    end

    hook.Call("PS_ItemPurchased", nil, self, item_id)

    if ITEM.SingleUse then
        self:PS_Notify("Item de uso unico!")

        return
    end

    self:PS_GiveItem(item_id)

    if not ITEM.SupressEquip then
        self:PS_EquipItem(item_id)
    end
end

function Player:PS_SellItem(item_id)
    if not PS.Items[item_id] then return false end
    if not self:PS_HasItem(item_id) then return false end
    local ITEM = PS.Items[item_id]

    -- should exist but we'll check anyway
    if ITEM.CanPlayerSell then
        local allowed, message

        if (type(ITEM.CanPlayerSell) == "function") then
            allowed, message = ITEM:CanPlayerSell(self)
        elseif (type(ITEM.CanPlayerSell) == "boolean") then
            allowed = ITEM.CanPlayerSell
        end

        if not allowed then
            self:PS_Notify(message or "Você não pode vender este item!")

            return false
        end
    end

    local points = PS.Config.CalculateSellPrice(self, ITEM)
    self:PS_GivePoints(points)
    local CATEGORY = PS:FindCategoryByName(ITEM.Category)

    if ITEM.OnHolster then
        ITEM:OnHolster(self)
    elseif CATEGORY.OnHolster then
        CATEGORY:OnHolster(self, nil, ITEM)
    end

    if ITEM.OnSell then
        ITEM:OnSell(self)
    elseif CATEGORY.OnSell then
        CATEGORY:OnSell(self, ITEM)
    end

    hook.Call("PS_ItemSold", nil, self, item_id)
    self:PS_Notify("Vendeu ", ITEM.Name, " por ", points, " ", PS.Config.PointsName)

    return self:PS_TakeItem(item_id)
end

function Player:PS_HasItem(item_id)
    return self.PS_Items and self.PS_Items[item_id] or false
end

function Player:PS_HasItemEquipped(item_id)
    if not self:PS_HasItem(item_id) then return false end

    return self.PS_Items and self.PS_Items[item_id].Equipped or false
end

function Player:PS_NumItemsEquippedFromCategory(cat_name)
    local count = 0

    for item_id, item in pairs(self.PS_Items) do
        local ITEM = PS.Items[item_id]

        if ITEM and ITEM.Category == cat_name and item.Equipped then
            count = count + 1
        end
    end

    return count
end

-- equip/hoster items
function Player:PS_EquipItem(item_id)
    local ITEM = PS.Items[item_id]
    if not ITEM or not self:PS_HasItem(item_id) or not self:PS_CanEquipItem(ITEM) then return false end

    if type(ITEM.CanPlayerEquip) == "function" then
        allowed = ITEM:CanPlayerEquip(self)

        if isstring(allowed) then
            self:PS_Notify(allowed)
            return
        end
    elseif type(ITEM.CanPlayerEquip) == "boolean" then
        allowed = ITEM.CanPlayerEquip
    end

    if not allowed then
        self:PS_Notify("Você não pode equipar este item!")

        return false
    end

    local cat_name = ITEM.Category
    local CATEGORY = PS:FindCategoryByName(cat_name)

    if CATEGORY and CATEGORY.AllowedEquipped > -1 and self:PS_NumItemsEquippedFromCategory(cat_name) + 1 > CATEGORY.AllowedEquipped then
        self:PS_Notify("Somente " .. CATEGORY.AllowedEquipped .. " item" .. (CATEGORY.AllowedEquipped == 1 and "" or "s") .. " podem ser equipados desta categoria!")

        return false
    end

    self.PS_Items[item_id].Equipped = true

    if ITEM.OnEquip then
        ITEM:OnEquip(self, self.PS_Items[item_id].Modifiers)
    elseif CATEGORY.OnEquip then
        CATEGORY:OnEquip(self, self.PS_Items[item_id].Modifiers, ITEM)
    end

    if not ITEM.SupressEquip then
        self:PS_Notify(ITEM.EquipNotify or "Equipado ", ITEM.Name, ".")
    end

    hook.Call("PS_ItemUpdated", nil, self, item_id, PS_ITEM_EQUIP)
    PS:SetPlayerItemEquipped(self, item_id, true)
    self:PS_SendItems()
end

function Player:PS_HolsterItem(item_id)
    if not PS.Items[item_id] then return false end
    if not self:PS_HasItem(item_id) then return false end
    local ITEM = PS.Items[item_id]

    if type(ITEM.CanPlayerHolster) == "function" then
        allowed = ITEM:CanPlayerHolster(self)
    elseif type(ITEM.CanPlayerHolster) == "boolean" then
        allowed = ITEM.CanPlayerHolster
    end

    if not allowed then
        self:PS_Notify("Você não pode desequipar este item!")

        return false
    end

    local CATEGORY = PS:FindCategoryByName(ITEM.Category)
    self.PS_Items[item_id].Equipped = false

    if ITEM.OnHolster then
        ITEM:OnHolster(self)
    elseif CATEGORY.OnHolster then
        CATEGORY:OnHolster(self, nil, ITEM)
    end

    if not ITEM.SupressEquip then
        self:PS_Notify("Desequipou ", ITEM.Name, ".")
    end

    hook.Call("PS_ItemUpdated", nil, self, item_id, PS_ITEM_HOLSTER)
    PS:SetPlayerItemEquipped(self, item_id, false)
    self:PS_SendItems()
end

function Player:PS_ModifyItem(item_id, modifications)
    if not PS.Items[item_id] or not self:PS_HasItem(item_id) or not istable(modifications) then return false end
    local ITEM = PS.Items[item_id]
    self.PS_Items[item_id].Modifiers = modifications
    local CATEGORY = PS:FindCategoryByName(ITEM.Category)

    if ITEM.OnModify then
        ITEM:OnModify(self, self.PS_Items[item_id].Modifiers)
    elseif CATEGORY.OnModify then
        CATEGORY:OnModify(self, self.PS_Items[item_id].Modifiers, ITEM)
    end

    hook.Call("PS_ItemUpdated", nil, self, item_id, PS_ITEM_MODIFY, modifications)
    PS:SetPlayerItemModifiers(self, item_id, modifications)
    self:PS_SendItems()
end

function Player:PS_CanEquipItem(ITEM)
    if ITEM.AdminOnly and not self:IsAdmin() then
        self:PS_Notify("Este item é só para administradores!")

        return false
    end

    if ITEM.AllowedUserGroups and #ITEM.AllowedUserGroups > 0 and not table.HasValue(ITEM.AllowedUserGroups, self:GetUserGroup()) then
        self:PS_Notify("Você precisa ser vip para usar isso!")

        return false
    end

    local CATEGORY = PS:FindCategoryByName(ITEM.Category)

    if CATEGORY.AllowedUserGroups and #CATEGORY.AllowedUserGroups > 0 and not table.HasValue(CATEGORY.AllowedUserGroups, self:GetUserGroup()) then
        self:PS_Notify("Você precisa ser vip para usar isso!")

        return false
    end

    return true
end

-- clientside Models
function Player:PS_AddClientsideModel(item_id)
    if not PS.Items[item_id] then return false end
    if not self:PS_HasItem(item_id) then return false end
    net.Start("PS_AddClientsideModel")
    net.WriteEntity(self)
    net.WriteString(item_id)
    net.Broadcast()

    if not PS.ClientsideModels[self] then
        PS.ClientsideModels[self] = {}
    end

    PS.ClientsideModels[self][item_id] = item_id
end

function Player:PS_RemoveClientsideModel(item_id)
    if not PS.Items[item_id] then return false end
    if not self:PS_HasItem(item_id) then return false end
    if not PS.ClientsideModels[self] or not PS.ClientsideModels[self][item_id] then return false end
    net.Start("PS_RemoveClientsideModel")
    net.WriteEntity(self)
    net.WriteString(item_id)
    net.Broadcast()
    PS.ClientsideModels[self][item_id] = nil
end

-- send stuff
function Player:PS_SendPoints()
    net.Start("PS_Points")
    net.WriteInt(self.PS_Points, 32)
    net.Send(self)
end

function Player:PS_SendItems()
    net.Start("PS_Items")
    net.WriteTable(self.PS_Items)
    net.Send(self)
end

function Player:PS_SendClientsideModels()
    net.Start("PS_SendClientsideModels")
    net.WriteTable(PS.ClientsideModels)
    net.Send(self)
end

-- notifications
function Player:PS_Notify(...)
    local str = table.concat({...}, "")
    net.Start("PS_SendNotification")
    net.WriteString(str)
    net.Send(self)
end
PS.ShopMenu = nil
PS.ClientsideModels = {}
PS.Cache = {}
PS.HoverModel = nil
PS.HoverModelClientsideModel = nil
local invalidplayeritems = {}

-- menu stuff
function PS:ToggleMenu()
    if not PS.ShopMenu or not PS.ShopMenu:IsValid() then
        PS.ShopMenu = vgui.Create("DPointShopMenu")
    else
        PS.ShopMenu:Close()
    end
end

function PS:SetHoverItem(item_id)
    local ITEM = PS.Items[item_id]

    if ITEM.Model then
        self.HoverModel = item_id
        self.HoverModelClientsideModel = ClientsideModel(ITEM.Model, RENDERGROUP_OPAQUE)
        self.HoverModelClientsideModel:SetNoDraw(true)
    end
end

function PS:RemoveHoverItem(item_id)
    self.HoverModel = nil
    self.HoverModelClientsideModel = nil
end

-- modification stuff
function PS:ShowColorChooser(item, modifications)
    if not modifications then
        modifications = {}
    end

    local chooser = vgui.Create("DPointShopColorChooser")
    chooser:SetColor(modifications.color)

    chooser.OnChoose = function(color)
        modifications.color = color
        self:SendModifications(item.ID, modifications)
    end
end

function PS:ShowBodygroupChooser(item, modifications)
    if not modifications then
        modifications = {}
    end

    local chooser = vgui.Create("DPointShopBodygroupChooser")
    chooser:SetData(item, modifications)

    chooser.OnChoose = function(group, skin)
        modifications.group = group
        modifications.skin = skin
        self:SendModifications(item.ID, modifications)
    end
end

function PS:SendModifications(item_id, modifications)
    net.Start("PS_ModifyItem")
    net.WriteString(item_id)
    net.WriteTable(modifications)
    net.SendToServer()
end

function PS:GetImageMaterial(id, callback)
    if self.Cache[id] ~= nil then
        callback(self.Cache[id])
    else
        if not file.Exists("image_cache", "DATA") then
            file.CreateDir("image_cache")
        end

        if file.Exists("image_cache/" .. id .. ".png", "DATA") then
            self.Cache[id] = Material("data/image_cache/" .. id .. ".png", "noclamp smooth")
            callback(self.Cache[id])
        else
            self.Cache[id] = false

            http.Fetch("https://i.imgur.com/" .. id .. ".png", function(body)
                file.Write("image_cache/" .. id .. ".png", body)
                self.Cache[id] = Material("data/image_cache/" .. id .. ".png", "noclamp smooth")
                callback(self.Cache[id])
            end, function()
                callback(false)
            end)
        end
    end
end

-- net hooks
net.Receive("PS_OpenCase", function()
    local hasItem = net.ReadBool()
    local items = net.ReadTable()
    local unbox = vgui.Create("DPointShopUnbox")
    unbox:SetData(items, hasItem)
end)

net.Receive("PS_Items", function(length)
    local items = net.ReadTable()
    LocalPlayer().PS_Items = items
end)

net.Receive("PS_Points", function(length)
    local points = net.ReadInt(32)
    LocalPlayer().PS_Points = PS:ValidatePoints(points)
end)

net.Receive("PS_PlayersData", function(length)
    local data = net.ReadTable()

    for k, v in ipairs(data) do
        v.ply.PS_Points = v.points
        v.ply.PS_Items = v.items
    end
end)

net.Receive("PS_ItemsData", function(length)
    local data = net.ReadTable()
    PS.ItemsData = data
end)

net.Receive("PS_MarketplaceItems", function(length)
    local data = net.ReadTable()
    PS.MarketplaceItems = data
end)

net.Receive("PS_AddClientsideModel", function(length)
    local ply = net.ReadEntity()
    local item_id = net.ReadString()

    if not IsValid(ply) then
        if not invalidplayeritems[ply] then
            invalidplayeritems[ply] = {}
        end

        table.insert(invalidplayeritems[ply], item_id)

        return
    end

    ply:PS_AddClientsideModel(item_id)
end)

net.Receive("PS_RemoveClientsideModel", function(length)
    local ply = net.ReadEntity()
    local item_id = net.ReadString()
    if not ply or not IsValid(ply) or not ply:IsPlayer() then return end
    ply:PS_RemoveClientsideModel(item_id)
end)

net.Receive("PS_SendClientsideModels", function(length)
    local itms = net.ReadTable()

    for ply, items in pairs(itms) do
        -- skip if the player isn't valid yet and add them to the table to sort out later
        if not IsValid(ply) then
            invalidplayeritems[ply] = items
        else
            for _, item_id in pairs(items) do
                if PS.Items[item_id] then
                    ply:PS_AddClientsideModel(item_id)
                end
            end
        end
    end
end)

net.Receive("PS_SendNotification", function(length)
    local str = net.ReadString()
    notification.AddLegacy(str, NOTIFY_GENERIC, 5)
end)

-- hooks
hook.Add("OnPlayerChat", "PS_ToggleCommand", function(ply, text, team, dead)
    if ply == LocalPlayer() and string.lower(text) == PS.Config.ShopChatCommand then
        PS:ToggleMenu()
    end
end)

hook.Add("PlayerButtonDown", "PS_ToggleKey", function(ply, btn)
    if IsFirstTimePredicted() and ply == LocalPlayer() and btn == _G["KEY_" .. PS.Config.ShopKey] then
        PS:ToggleMenu()
    end
end)

hook.Add("Think", "PS_Think", function()
    for ply, items in pairs(invalidplayeritems) do
        if IsValid(ply) then
            for _, item_id in pairs(items) do
                if PS.Items[item_id] then
                    ply:PS_AddClientsideModel(item_id)
                end
            end

            invalidplayeritems[ply] = nil
        end
    end
end)

hook.Add("PostPlayerDraw", "PS_PostPlayerDraw", function(ply)
    if not ply:Alive() then return end
    if ply == LocalPlayer() and GetViewEntity():GetClass() == "player" and (GetConVar("thirdperson") and GetConVar("thirdperson"):GetInt() == 0) then return end
    if not PS.ClientsideModels[ply] then return end

    for item_id, model in pairs(PS.ClientsideModels[ply]) do
        if PS.Items[item_id] then
            local ITEM = PS.Items[item_id]

            if ITEM.Attachment or ITEM.Bone then
                local pos = Vector()
                local ang = Angle()

                if ITEM.Attachment then
                    local attach_id = ply:LookupAttachment(ITEM.Attachment)
                    if not attach_id then return end
                    local attach = ply:GetAttachment(attach_id)
                    if not attach then return end
                    pos = attach.Pos
                    ang = attach.Ang
                else
                    local bone_id = ply:LookupBone(ITEM.Bone)
                    if not bone_id then return end
                    pos, ang = ply:GetBonePosition(bone_id)
                end

                model, pos, ang = ITEM:ModifyClientsideModel(ply, model, pos, ang)
                model:SetPos(pos)
                model:SetAngles(ang)
                model:SetRenderOrigin(pos)
                model:SetRenderAngles(ang)
                model:SetupBones()
                model:DrawModel()
                model:SetRenderOrigin()
                model:SetRenderAngles()
            else
                PS.ClientsideModels[ply][item_id] = nil
            end
        else
            PS.ClientsideModels[ply][item_id] = nil
        end
    end
end)
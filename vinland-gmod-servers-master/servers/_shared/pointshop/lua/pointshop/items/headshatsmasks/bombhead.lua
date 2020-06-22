ITEM.Name = "Bomb Head"
ITEM.Price = 1000
ITEM.Model = "models/Combine_Helicopter/helicopter_bomb01.mdl"
ITEM.Attachment = "eyes"

function ITEM:ModifyClientsideModel(ply, model, pos, ang)
    model:SetModelScale(0.5, 0)
    pos = pos + (ang:Forward() * -2)
    ang:RotateAroundAxis(ang:Right(), 90)

    return model, pos, ang
end
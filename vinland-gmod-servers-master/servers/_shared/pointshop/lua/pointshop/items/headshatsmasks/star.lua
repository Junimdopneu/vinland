ITEM.Name = "Star"
ITEM.Price = 10000
ITEM.Model = "models/balloons/balloon_star.mdl"
ITEM.Bone = "ValveBiped.Bip01_Head1"

function ITEM:ModifyClientsideModel(ply, model, pos, ang)
    local Size = Vector(0.25, 0.25, 0.25)
    local mat = Matrix()
    mat:Scale(Size)
    model:EnableMatrix("RenderMultiply", mat)

    model:SetMaterial("models/weapons/v_slam/new light2")

    local MAngle = Angle(0, 0, 270)
    local MPos = Vector(13, 0, 0)

    pos = pos + (ang:Forward() * MPos.x) + (ang:Up() * MPos.z) + (ang:Right() * MPos.y)
    ang:RotateAroundAxis(ang:Forward(), MAngle.p)
    ang:RotateAroundAxis(ang:Up(), MAngle.y)
    ang:RotateAroundAxis(ang:Right(), MAngle.r)

    model.ModelDrawingAngle = model.ModelDrawingAngle or Angle(0, 0, 0)
    model.ModelDrawingAngle.p = (CurTime() * 0 * 90)
    model.ModelDrawingAngle.y = (CurTime() * 1 * 90)
    model.ModelDrawingAngle.r = (CurTime() * 0 * 90)

    ang:RotateAroundAxis(ang:Forward(), model.ModelDrawingAngle.p)
    ang:RotateAroundAxis(ang:Up(), model.ModelDrawingAngle.y)
    ang:RotateAroundAxis(ang:Right(), model.ModelDrawingAngle.r)

    return model, pos, ang
end

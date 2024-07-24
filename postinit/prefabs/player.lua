local AddPlayerPostInit = AddPlayerPostInit
GLOBAL.setfenv(1, GLOBAL)

local fn = function(inst)
    inst:AddComponent("displaypoisonouscircle")

    if not TheWorld.ismastersim then
        return
    end

    inst:AddComponent("envenom")
end

AddPlayerPostInit(fn)

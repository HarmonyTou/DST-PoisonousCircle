local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

local fn = function(inst)
    inst:AddComponent("poisonouscircle")

    if not inst.ismastersim then
        return
    end
end

AddPrefabPostInit("world", fn)

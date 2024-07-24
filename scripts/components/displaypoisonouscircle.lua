return Class(function(self, inst)

    local _world = TheWorld

    local function OnChangeCircleState(inst)
        local circlestate = _world.components.poisonouscircle:GetCircleState()
        if circlestate:value() then
            inst:StartUpdatingComponent(self)
        else
            inst:StopUpdatingComponent(self)
        end
    end

    local function OnStartPoisonousCircle(inst)
        inst:StartUpdatingComponent(self)
    end

    local function OnStopPoisonousCircle(inst)
        inst:StopUpdatingComponent(self)
    end

    inst:ListenForEvent("circlestate", OnChangeCircleState, _world)
    inst:ListenForEvent("startpoisonouscircle", OnStartPoisonousCircle, _world)
    inst:ListenForEvent("stoppoisonouscircle", OnStopPoisonousCircle, _world)

    function self:OnUpdate(dt)
        local x, y, r = _world.components.poisonouscircle:GetScreenPos()
        PostProcessor:SetUniformVariable(UniformVariables.CIR_PC, x, y, r, 0)
    end

end)

return Class(function(self, inst)

    self.inst = inst

    local _world = TheWorld
    local _poisonouscircle = _world.components.poisonouscircle
    local _frequency = 1
    local _last_time = 0

    local OnDeath = function(inst)
        inst:StopUpdatingComponent(self)
    end

    local OnRespawnFromGhost = function(inst)
        _last_time = 0
        local circlestate = _world.components.poisonouscircle:GetCircleState()
        if circlestate:value() then
            inst:StartUpdatingComponent(self)
        end
    end

    local function IsInPoisonousCircle(inst)
        local pos = _poisonouscircle:GetBigPos()
        local x, y, z = inst.Transform:GetWorldPosition()
        if VecUtil_Dist(x, z, pos.x, pos.y) >= pos.r then
            return true
        end
    end

    local function CanEnvenom(inst)
        -- 判断一下玩家是鬼魂状态
        if inst:IsValid() and (inst.components.health == nil or inst.components.health:IsDead()) then
            inst:StopUpdatingComponent(self)
            return false
        end
        return true
    end

    local StartPoisonousCircle = function(inst)
        _last_time = 0
        inst:StartUpdatingComponent(self)
    end

    local StopPoisonousCircle = function(inst)
        _last_time = 0
        inst:StopUpdatingComponent(self)
    end

    inst:ListenForEvent("death", OnDeath)
    inst:ListenForEvent("respawnfromghost", OnRespawnFromGhost)
    inst:ListenForEvent("startpoisonouscircle", StartPoisonousCircle, _world)
    inst:ListenForEvent("stoppoisonouscircle", StopPoisonousCircle, _world)

    function self:OnUpdate(dt)
        if _last_time >= _frequency then
            _last_time = 0
            if IsInPoisonousCircle(inst) and CanEnvenom(inst) then
                if _poisonouscircle ~= nil then
                    local current = _poisonouscircle:GetCurrent()
                    local damage = current and current.damage or 1
                    inst.components.health:DoDelta(-damage)
                end
            end
        else
            _last_time = _last_time + dt
        end
    end

end)

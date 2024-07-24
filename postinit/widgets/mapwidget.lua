local AddClassPostConstruct = AddClassPostConstruct
GLOBAL.setfenv(1, GLOBAL)

local fn = function(self)

    self.poisonouscircle = TheWorld.components.poisonouscircle

    -- 图片ui添加shader
    self.img.inst.ImageWidget:SetEffect(resolvefilepath("shaders/ui_round.ksh")) --resolvefilepath 官方使用时不会加这个 mod得加

    self.SetBigCircle = function(self, is_r)
        local bigcir = self.poisonouscircle:GetBigScreenPos()
        self.img:SetEffectParams(bigcir.x, bigcir.y, bigcir.r * (is_r and 1 or 1), 0) --1/self.minimap:GetZoom()
    end

    self.SetSmallCircle = function(self, is_r)
        local smallcir = self.poisonouscircle:GetSmallScreenPos()
        self.img:SetEffectParams2(smallcir.x, smallcir.y, smallcir.r * (is_r and 1 or 1), smallcir.b)
    end

    -- 初始化
    self:SetBigCircle()
    self:SetSmallCircle()

    -- 持续变化
    local _OnUpdate = self.OnUpdate
    self.OnUpdate = function(self, dt)
        if not self.shown then return end
        local is_shrink = self.poisonouscircle.GetIsShrink()
        if is_shrink:value() then --缩圈中
            self:SetBigCircle()
            self:SetSmallCircle()
        elseif TheInput:IsControlPressed(CONTROL_ROTATE_LEFT) or TheInput:IsControlPressed(CONTROL_ROTATE_RIGHT) then --检查是否按下旋转了
            self:SetBigCircle()
            self:SetSmallCircle()
        end

        _OnUpdate(self, dt)
    end

    -- 跟着一起进行偏移
    local _minimap__index = getmetatable(self.minimap).__index
    if _minimap__index ~= nil then
        local Offset = _minimap__index.Offset
        _minimap__index.Offset = function(t, dx, dy)
            Offset(t, dx, dy)
            self:SetBigCircle()
            self:SetSmallCircle()
        end
    end

    -- 重新设置安全区了 手动更新一下
    TheWorld:ListenForEvent("onminimapshrink", function()
        self:SetBigCircle()
        self:SetSmallCircle()
    end)
end

AddClassPostConstruct("widgets/mapwidget", fn)

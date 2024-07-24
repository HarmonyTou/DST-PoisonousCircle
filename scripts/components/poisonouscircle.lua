return Class(function(self, inst)

    --------------------------------------------------------------------------
    --[[ Member variables ]]
    --------------------------------------------------------------------------

    self.inst = inst

    local _world = TheWorld
    local _map = _world.Map
    local _ismastersim = _world.ismastersim
    local _minimap = _world.minimap and _world.minimap.MiniMap or nil
    local _net = TheNet
    local _isdedicated = _net:IsDedicated()
    local _sim = TheSim

    -- 网络变量的关联 省了写value和set 而是正常的赋值和调用
    local contact_net = {
        __index = function(t, k) --对表(t)读取不存在的值(k)时。 t是被添加元表的表, 即setmetatable函数的第一个参数
            local p = rawget(t, "_")[k]
            if p ~= nil then
                return p:value()
            end
            return getmetatable(t)[k]
        end,
        __newindex = function(t, k, v) --对表(t)给不存在的值(k)进行赋值(v)时。
            local p = rawget(t, "_")[k]
            if p == nil then
                rawset(t, k, v)
            else
                p:set(v)
            end
        end,
    }

    local data = {
        -- 不活跃时间    活跃缩圈时间  秒伤  小圆是大圆的倍数
        -- {inactive_time= 300, active_time= 300, damage=1, mag = .6},
        -- {inactive_time= 200, active_time= 100, damage=1, mag = .4},
        -- {inactive_time= 150, active_time= 90, damage=2, mag = .5},
        -- {inactive_time= 120, active_time= 60, damage=3, mag = .5},
        -- {inactive_time= 120, active_time= 40, damage=4, mag = .5},
        -- {inactive_time= 90, active_time= 30, damage=5, mag = 0},
        {inactive_time= 10, active_time= 10, damage=1, mag = .7},
        {inactive_time= 10, active_time= 10, damage=1, mag = 0.4},
        {inactive_time= 10, active_time= 10, damage=1, mag = 0.5},
        {inactive_time= 10, active_time= 10, damage=1, mag = 0.5},
        {inactive_time= 10, active_time= 10, damage=1, mag = 0.5},
        {inactive_time= 10, active_time= 10, damage=1, mag = 0},
    }

    local _total_time
    local _speed
    local _distance
    local _big_circle
    local _small_circle
    local _nodes
    local _sin
    local _cos

    local FIRST_TIME = 5 --最开始等待刷新安全区

    local _circlestate = net_bool(inst.GUID, "minimap._circlestate", "circlestate")
    local _isshrink = net_bool(inst.GUID, "minimap._isshrink", "onminimapshrink")
    local _number = net_smallbyte(inst.GUID, "minimap._number")
    local _next_shrinking_time = net_float(inst.GUID, "minimap._next_shrinking_time")
    local _damage = net_float(inst.GUID, "minimap._damage")

    -- 大圈的位置和半径
    local _big_circle_pos_x = net_float(inst.GUID, "minimap._big_circle_pos_x")  -- 范围[-32767..32767] 这个也是够用的 地图大小是有限制的
    local _big_circle_pos_y = net_float(inst.GUID, "minimap._big_circle_pos_y")
    local _big_circle_pos_r = net_float(inst.GUID, "minimap._big_circle_pos_r") -- 范围[0..65535] 半径大概可到 16383块地皮哎 完全够用

    -- 小圈的位置和半径
    local _small_circle_pos_x = net_float(inst.GUID, "minimap._small_circle_pos_x")
    local _small_circle_pos_y = net_float(inst.GUID, "minimap._small_circle_pos_y")
    local _small_circle_pos_r = net_float(inst.GUID, "minimap._small_circle_pos_r")

    local _current = {}
    _current._ = {state = _isshrink, time = _next_shrinking_time, damage = _damage, n = _number}
    setmetatable(_current, contact_net)

    -- 大圈的WorldPos参数
    local _big_circle_pos = {}
    _big_circle_pos._ = {x = _big_circle_pos_x, y = _big_circle_pos_y, r = _big_circle_pos_r}
    setmetatable(_big_circle_pos, contact_net)

    -- 小圈的WorldPos参数
    local _small_circle_pos = {}
    _small_circle_pos._ = {x = _small_circle_pos_x, y = _small_circle_pos_y, r = _small_circle_pos_r}
    setmetatable(_small_circle_pos, contact_net)

    -- ScreenPos -> WidgetPos 从左下角到中间的坐标变换 x-w/2
    -- WidgetPos -> MapPos MapPos也是位于中间的 公式就是 x*(2/w) 原理没有搞懂
    -- local function ScreenPosToMapPos(x, y)
    --     local w, h = _sim:GetScreenSize()
    --     return 2 * x / w - 1, 2 * y / h - 1
    -- end

    -- MapPos -> WidgetPos 公式就是 x*(w/2) 原理没有搞懂
    -- WidgetPos -> ScreenPos 公式就是 x+w/2
    local function MapPosToScreenPos(x, y)
        local w, h = _sim:GetScreenSize()
        return (x + 1) * w / 2, (y + 1) * h / 2
    end

    --客户端数据
    if not _isdedicated then
        -- 大小圆圈的ScreenPos坐标和半径
        _big_circle = {x = 0, y = 0, r = 0} --大圈shader映射参数
        _small_circle = {x = 0, y = 0, r = 0, b = 3.0} --小圈shader映射参数 b是边界大小 border
    end

    if _ismastersim then
        inst:DoTaskInTime(0,function()
            local w, h = _map:GetSize()
            _big_circle_pos.r = w * 4 * 2 --没改地图大小是没有问题的 够用。
        end)

        _circlestate:set(false)
    end

    ------------------------- [[ 服务器端执行 ]] -------------------------
    -- 设置大圈的世界信息
    local function SetBigWorldPos(x, y, r)
        -- print("设置大圆:",x,y,r)
        if not _ismastersim then return end
        if checknumber(x) then
            _big_circle_pos.x = x
        end
        if checknumber(y) then
            _big_circle_pos.y = y
        end
        if checknumber(r) and r >= 0 then --不能负数
            _big_circle_pos.r = r
        end
    end

    -- 设置小圈的世界信息
    local function SetSmallWorldPos(x, y, r)
        -- print("设置小圆:",x,y,r)
        if not _ismastersim then return end
        if checknumber(x) then
            _small_circle_pos.x = x
        end
        if checknumber(y) then
            _small_circle_pos.y = y
        end
        if checknumber(r) and r >= 0 then --不能负数 要不判断一下是否大于大圆的半径？
            _small_circle_pos.r = r
        end
    end

    -- 找到安全区
    local function FindSecurity(r1, r2)
        -- print("半径", r1, r2)
        local big_r = r1
        local small_r = r2 --比大圆半径小就行
        local big_r_sq = big_r * big_r
        local small_r_sq = small_r * small_r
        -- A方案
        -- 从陆地的各个节点 选择出范围内可以作为小圆圆心的节点 再随机一个作为圆心。
        local __nodes = _nodes or _world.topology.nodes --初始时 全部节点都要遍历一次
        local nodes = {}
        local x, y = 0, 0
        for k, node in pairs(__nodes) do
            local dissq = DistXYSq(_big_circle_pos, node) --是节点中心
            if big_r_sq >= dissq + small_r_sq then
                table.insert(nodes, {x = node.x, y = node.y}) --直接记录节点 和 记录新表 区别暂时未知阿
            end
        end

        -- 更新可用节点列表
        _nodes = nodes

        -- print("A方案",#nodes)
        if false and #nodes > 0 then
            local n = nodes[math.random(#nodes)]
            x, y = n.x, n.y
        else
            -- B方案
            -- 如果是自定义类型的地图（海战类型） 可能没有合适的节点 此时应该从地图中随机一个 忽略掉在安全区在海洋的情况了。
            -- 因为小圆是被大圆内含或内切的 那么小圆的圆心坐标可以的区域是一个与大圆的同心圆 其半径是大圆半径-小圆半径
            -- 那么可以随机向量法来确定小圆圆心 即同心圆圆心为原点 随机一个角度 随机0~1的半径长度
            local r = big_r - small_r
            local angle = math.random() * 2 * PI
            r = math.sqrt(math.random()) * r
            x = r * math.cos(angle) + _big_circle_pos.x
            y = r * math.sin(angle) + _big_circle_pos.y
        end
        -- 可能可以对小圆圆心坐标进行规整化 抛去小数点 会不会更好嘞 待测试
        return x, y
    end

    -- 下一个安全区
    local function NextSecurityZone()
        if not _ismastersim then return end
        -- 第一个圈 从各个节点中随机一个; 遍历全部节点 找到全部在半径内的节点
        -- 下一个圈 节点表>0 随机一个半径内的节点; 否则 遍历当前半径内的合适位置

        local map_width, map_height = _map:GetSize() --是地皮数量
        -- print("世界大小", map_width, map_height)
        -- 设置为下一波
        _current.n = _current.n + 1
        -- 获取下一次的信息
        local t = data[_current.n]

        if t then
            local x, y = _small_circle_pos.x, _small_circle_pos.y --初始时 值为0
            local bigr = _small_circle_pos.r > 0 and _small_circle_pos.r or (map_width * 4 * math.sqrt(2)) / 2 --初始时 值为0 故选择地图外接圆
            local smallr = _small_circle_pos.r > 0 and t.mag * bigr or (map_width - OCEAN_WATERFALL_MAX_DIST) * 2 * t.mag-- 预设的值
            -- 先设置大圆的数据 找小圆要用到
            SetBigWorldPos(x, y, bigr)

            if smallr > 0 then --0的话 是最后的了 就往中间缩
                -- 初始时 保证小圆要在地图范内含或内切。 选择地图的内接圆, 地图因为有边缘锯齿不规则 所以再往里缩到保证可以形成完整正方形 所以为 (map_width-OCEAN_WATERFALL_MAX_DIST)*4
                x, y = FindSecurity(_small_circle_pos.r > 0 and bigr or (map_width - OCEAN_WATERFALL_MAX_DIST) * 2, smallr)
            end

            -- 设置小圈的信息
            SetSmallWorldPos(x, y, smallr)

            -- 更新下次基础信息
            self:Shrink(t.active_time, t.inactive_time, t.damage)
        else
            -- print("毒圈已经刷完了")
            self:Stop()
            -- print("大圈", _big_circle_pos.r, _big_circle_pos.x, _big_circle_pos.y)
            -- print("小圈", _small_circle_pos.r, _small_circle_pos.x, _small_circle_pos.y)
        end
    end

    -- 开始收缩
    local function StartShrink()
        if _ismastersim then
            -- print("缩圈了")
            _world:PushEvent("onstartshrink")
            _current.state = true
        end
    end

    ------------------------- [[ 客户端执行 ]] -------------------------
    function self:GetBigScreenPos()
        -- 求ScreenPos的半径
        local x, y = _minimap:WorldPosToMapPos(_big_circle_pos.x, _big_circle_pos.y, 0) --WorldPos坐标 转 MapPos坐标
        _big_circle.x, _big_circle.y = MapPosToScreenPos(x,y)
        x, y = _minimap:WorldPosToMapPos(_big_circle_pos.x + _big_circle_pos.r, _big_circle_pos.y, 0)
        x, y = MapPosToScreenPos(x,y)
        local dx, dy = _big_circle.x - x, _big_circle.y - y
        local r = math.sqrt(dx * dx + dy * dy)
        _big_circle.r = r
        return _big_circle
    end

    function self:GetSmallScreenPos()
        -- 求ScreenPos的半径
        local x, y = _minimap:WorldPosToMapPos(_small_circle_pos.x, _small_circle_pos.y, 0) --WorldPos坐标 转 MapPos坐标
        _small_circle.x, _small_circle.y = MapPosToScreenPos(x,y)
        x, y = _minimap:WorldPosToMapPos(_small_circle_pos.x + _small_circle_pos.r, _small_circle_pos.y, 0)
        x, y = MapPosToScreenPos(x,y)
        local dx,dy = _small_circle.x - x, _small_circle.y - y
        local r = math.sqrt(dx * dx + dy * dy)
        _small_circle.r = r
        return _small_circle
    end

    function self:GetScreenPos()
        -- 世界坐标转屏幕坐标 应该还要在旋转处理一下
        local x,y = _sim:GetScreenPos(0, 0, 0)
        local x1,y1 = _sim:GetScreenPos(0 + 8, 0,0)
        local r = VecUtil_Dist(x, y, x1, y1)
        return x, y, r
    end

    function self:Shrink(_time, __time, damage)
        -- 缩圈参数
        _total_time = _time or 0 --总收缩时间
        _speed = (_big_circle_pos.r - _small_circle_pos.r) / _total_time --计算收缩速度
        -- 两圆内切时 大圆圆心移动xy方向分量
        _distance = math.sqrt(DistXYSq(_big_circle_pos, _small_circle_pos)) --两圆初始距离平方
        if _big_circle_pos.x == _small_circle_pos.x and _big_circle_pos.y ~= _small_circle_pos.y then
            _cos = 0
            _sin = 1
        elseif _big_circle_pos.x ~= _small_circle_pos.x and _big_circle_pos.y == _small_circle_pos.y then
            _cos = 1
            _sin = 0
        elseif _big_circle_pos.x == _small_circle_pos.x and _big_circle_pos.y == _small_circle_pos.y then
            _cos = 0
            _sin = 0
        else
            local a = _small_circle_pos.x - _big_circle_pos.x
            local b = _small_circle_pos.y - _big_circle_pos.y
            _cos = a / _distance
            _sin = b / _distance
        end

        -- 设置毒圈其他参数
        _current.time = __time or 0
        _current.damage = damage or 0
    end

    function self:Start()
        local w, h = _map:GetSize()

        inst:StopUpdatingComponent(self)
        _circlestate:set(true)
        -- 初始时 圆心都在地图中心 (0,0) 半径要比地图大 就好
        _big_circle_pos.r = w * 4 * 2 --没改地图大小是没有问题的 够用。
        _current.n = 0
        _current.state = false
        -- 设置初始参数
        inst:DoTaskInTime(FIRST_TIME, function()
            _world:PushEvent("startpoisonouscircle")
            NextSecurityZone() --第一波
            inst:StartUpdatingComponent(self)
        end)
    end

    function self:Stop()
        _circlestate:set(false)
        _world:PushEvent("stoppoisonouscircle")
        inst:StopUpdatingComponent(self)
    end

    function self:GetCurrent()
        return _current
    end

    function self:GetCircleState()
        return _circlestate
    end

    function self:GetIsShrink()
        return _isshrink
    end

    function self:GetBigPos()
        return _big_circle_pos
    end

    function self:GetSmallPos()
        return _small_circle_pos
    end

    function self:OnUpdate(dt)
        if _ismastersim then
            if _current.state then
                local new_time = _total_time - dt
                if new_time <= 0 then
                    new_time = 0
                    dt = _total_time
                end
                _total_time = new_time
                -- 每帧半径缩小值
                local diffBigR = _speed * dt
                _big_circle_pos.r = _big_circle_pos.r - diffBigR
                --内切但没有重合时 每帧同时进行移动大圆的圆心 靠近小圆的圆心
                if _big_circle_pos.r > _small_circle_pos.r and _big_circle_pos.r <= _small_circle_pos.r + _distance then
                    _big_circle_pos.x = _big_circle_pos.x + _cos * diffBigR
                    _big_circle_pos.y = _big_circle_pos.y + _sin * diffBigR
                end
                -- print("", self.total_time, _big_circle_pos.x, _big_circle_pos.y, _big_circle_pos.r, diffBigR)
                if _total_time <= 0 then
                    -- 寻找下一个安全区
                    NextSecurityZone()
                    _current.state = false
                end
            else
                -- 检查 下次毒圈活跃
                _current.time = _current.time - dt
                if _current.time <= 0 then
                    -- 开始缩圈了
                    StartShrink()
                end
            end
        else
            inst:StopUpdatingComponent(self)
        end
    end

end)

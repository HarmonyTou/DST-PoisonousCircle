--[[

需求:
熔炉暴食mod那样的大厅界面
有小地图的显示，大地图的显示，以及掉血判定
再加一个裁判功能

]]

local modimport = modimport

local modules = {
    "assets",
    "postinit",
}

for i = 1, #modules do
    modimport("main/" .. modules[i])
end

local modimport = modimport

modimport("postinit/shadereffects")

local postinit = {
    components = {

    },
    prefabs = {
        "world",
        "player",
    },
    widgets = {
        "mapwidget",
    }
}

for k, v in pairs(postinit) do
    for i = 1, #v do
        modimport("postinit/" .. k .. "/" .. postinit[k][i])
    end
end

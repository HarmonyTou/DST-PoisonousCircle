local AddModShadersInit = AddModShadersInit
local AddModShadersSortAndEnable = AddModShadersSortAndEnable
GLOBAL.setfenv(1, GLOBAL)

local IsClient = TheNet:GetIsClient()
local IsClientHosted = TheNet:GetServerIsClientHosted()

if IsClient or IsClientHosted then
    local ShadersInitFn = function()
        PostProcessorEffects.POISONOUSCIRCLE = PostProcessor:AddPostProcessEffect(resolvefilepath("shaders/win_round.ksh"))
        UniformVariables.CIR_PC = PostProcessor:AddUniformVariable("CIR_PC", 4)
        UniformVariables.CIR_PC2 = PostProcessor:AddUniformVariable("CIR_PC2", 4)
        PostProcessor:SetUniformVariable(UniformVariables.CIR_PC, 0, 0, 5000*5000, 0) -- 毒圈 x,y,r,w w无用 半径调大一些 不然地图边缘地方能感知
        PostProcessor:SetUniformVariable(UniformVariables.CIR_PC2, 0, 0, 0, 0) --设置安全区
        PostProcessor:SetEffectUniformVariables(
            PostProcessorEffects.POISONOUSCIRCLE,
            UniformVariables.CIR_PC,
            UniformVariables.CIR_PC2
        )
    end

    AddModShadersInit(ShadersInitFn)

    local ShadersSortAndEnableFn = function()
        PostProcessor:SetPostProcessEffectAfter(PostProcessorEffects.POISONOUSCIRCLE, PostProcessorEffects.Lunacy)
        PostProcessor:EnablePostProcessEffect(PostProcessorEffects.POISONOUSCIRCLE, true) --启用滤镜 在未开始前 其实可以不用启用的
    end

    AddModShadersSortAndEnable(ShadersSortAndEnableFn)
end

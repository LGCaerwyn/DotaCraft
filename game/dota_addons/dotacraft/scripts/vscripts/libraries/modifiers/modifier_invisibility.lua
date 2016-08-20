modifier_invisibility = class({})

function modifier_invisibility:OnCreated(event)
    if IsServer() then
        self.fadeTime = event.fade_time or 1
    end
end

function modifier_invisibility:CheckState()
    local state = {}

    if IsServer() then
        state[MODIFIER_STATE_INVISIBLE] = self:CalculateInvisibilityLevel() == 1.0
    end

    return state
end

function modifier_invisibility:DeclareFunctions()
    return { MODIFIER_PROPERTY_INVISIBILITY_LEVEL, }
end

function modifier_invisibility:CalculateInvisibilityLevel()
    return math.min(self:GetElapsedTime() / self.fadeTime, 1.0)
end

function modifier_invisibility:GetModifierInvisibilityLevel(params)
    if IsClient() then
        return self:GetStackCount() / 100
    else
        local level = self:CalculateInvisibilityLevel()
        if level > 0.45 then -- Adjust visual past 45% because the transparency starts acting up
            level = 1
            self:SetStackCount(100)
        else
            self:SetStackCount(math.ceil(level * 100))
        end
        return level
    end
end

function modifier_invisibility:IsPurgable() return false end
function modifier_invisibility:IsHidden() return true end
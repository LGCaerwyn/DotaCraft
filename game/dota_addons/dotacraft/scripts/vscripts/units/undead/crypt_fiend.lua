function BurrowVisual ( keys )
    local caster = keys.caster
    local duration = keys.ability:GetSpecialValueFor("duration") - 0.1

    -- end any animation
    EndAnimation(caster)
    
    if not caster:FindModifierByName("modifier_crypt_fiend_burrow") then -- if not burrowed, burrow
        StartAnimation(caster, {duration=duration, activity=ACT_DOTA_CAST_ABILITY_4, rate=0.6, translate="stalker_exo"})
        ParticleManager:CreateParticle("particles/units/heroes/hero_nyx_assassin/nyx_assassin_burrow.vpcf", 1, caster)
    end
end

function Burrow ( keys )
    local caster = keys.caster
    local ability = keys.ability

    -- toggle state(purely visual)
    ability:ToggleAbility()
    
    if not caster:FindModifierByName("modifier_crypt_fiend_burrow") then -- if not burrowed, burrow     
        caster:AddNewModifier(caster, nil, "modifier_crypt_fiend_burrow_model", {})
        ability:ApplyDataDrivenModifier(caster, caster, "modifier_crypt_fiend_burrow", nil)
        caster:NotifyWearablesOfModelChange(false)

    else -- if burrowed, revert
        caster:RemoveModifierByName("modifier_crypt_fiend_burrow_model")
        caster:RemoveModifierByName("modifier_crypt_fiend_burrow")
        caster:NotifyWearablesOfModelChange(true)
        
        ParticleManager:CreateParticle("particles/units/heroes/hero_nyx_assassin/nyx_assassin_burrow_exit.vpcf", 1, caster)
        StartAnimation(caster, {duration=1, activity=ACT_DOTA_TELEPORT_END, rate=1})
    end

    caster:Stop()
end

-- on spell start call / autocast call
function Web(keys)
    local caster = keys.caster
    local target = keys.target
    local ability = keys.ability
    local duration = ability:GetSpecialValueFor("duration")
    
    -- Loses flying capability, modifier_flying_control will take care of adjusting the units height
    target:SetMoveCapability(DOTA_UNIT_CAP_MOVE_GROUND)
    ability:ApplyDataDrivenModifier(caster, target, "modifier_web", {duration=duration})
end

function Web_Destroy(event)
    local target = event.target
    target:SetMoveCapability(DOTA_UNIT_CAP_MOVE_FLY)
end

-- timer that's initialised on crypt fiend spawn
function Web_AutoCast(keys)
    local caster = keys.caster
    local ability = keys.ability
    local radius = ability:GetCastRange()+caster:GetHullRadius()

    Timers:CreateTimer(function()
        if not IsValidEntity(caster) or not caster:IsAlive() then return end
        
        if ability:IsCooldownReady() and ability:GetAutoCastState() then
            local units = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false)                   
            for k,unit in pairs(units) do
                if unit:HasFlyMovementCapability() then -- found unit to web
                    caster:CastAbilityOnTarget(unit, ability, caster:GetPlayerOwnerID())
                    break
                end
            end
        end
        
        return 0.2
    end)
end
function ApplyFaerieFire(event)
	local caster = event.caster
	local target = event.target
	local ability = event.ability
	local duration = ability:GetSpecialValueFor("duration")

	if target:IsHero() or target:IsConsideredHero() then
		duration = ability:GetSpecialValueFor("hero_duration")
	end

	ability:ApplyDataDrivenModifier(caster, target, "modifier_faerie_fire", {duration=duration})
	target.faerie_fire_team = caster:GetTeamNumber() --If the druid dies, keep giving the vision

	print("Apply faerie fire for "..duration)
end

function FaerieFireAutocast(event)
    local ability = event.ability
    local caster = event.caster
    local autocast_radius = ability:GetCastRange()
    local modifier_name = "modifier_faerie_fire"
    
    if caster.state == AI_STATE_IDLE or caster.state == AI_STATE_SLEEPING then return end

    if ability:GetAutoCastState() and ability:IsFullyCastable() and not caster:IsMoving() then
        local target
        local enemies = FindEnemiesInRadius(caster, autocast_radius)
        for k,unit in pairs(enemies) do
            if not IsCustomBuilding(unit) and not unit:IsWard() and not unit:HasModifier(modifier_name) then
                target = unit
                break
            end
        end

        if target then
            caster:CastAbilityOnTarget(target, ability, caster:GetPlayerOwnerID())
        end
    end
end

-- Make vision every second (this is to prevent the vision staying if the modifier is purged)
function FaerieFireVision( event )
	local caster = event.caster
	local target = event.target

	AddFOWViewer( target.faerie_fire_team, target:GetAbsOrigin(), 500, 0.75, true)
end

function CrowFormOn( event )
    local caster = event.caster
    local playerID = caster:GetPlayerOwnerID()
    caster:StartGesture(ACT_DOTA_CAST_ABILITY_4)

    -- Disable cyclone
    local cyclone = caster:FindAbilityByName("nightelf_cyclone")
    if cyclone then
        cyclone:SetHidden(true)
    end

    -- Disable faerie fire unless the player has mark of the talon researched
    if not Players:HasResearch(playerID, "nightelf_research_mark_of_the_talon") then
        local ff_ability = caster:FindAbilityByName("nightelf_faerie_fire")
        ff_ability:SetLevel(0)
    end
end

function CrowFormOff( event )
    local caster = event.caster
    local playerID = caster:GetPlayerOwnerID()
    caster:StartGesture(ACT_DOTA_IDLE_RARE)
    
    -- Enable cyclone if the research is valid
    if Players:GetCurrentResearchRank(playerID, "nightelf_research_druid_of_the_talon_training") >= 1 then
        local cyclone = caster:FindAbilityByName("nightelf_cyclone")
        if cyclone then
            cyclone:SetHidden(false)
        end
    else
        CheckAbilityRequirements( caster, playerID )
    end

    -- Enable faerie fire
    local ff_ability = caster:FindAbilityByName("nightelf_faerie_fire")
    ff_ability:SetLevel(1)
end

function CrowFormStart( event )
    local caster = event.caster
    local model = event.model
    local ability = event.ability
    caster:Stop()
    caster:SetModelScale(0.8)

    -- Sets the new model
    caster:AddNewModifier(caster, nil, "modifier_druid_crow_model", {})
    if not caster:HasModifier("modifier_flying_control") then
        caster:AddNewModifier(caster,nil,"modifier_flying_control",{})
    end

    -- Add weapon/armor upgrade benefits
    caster:ApplyRankUpgrades()

    -- Swap sub_ability
    local sub_ability_name = event.sub_ability_name
    local main_ability_name = ability:GetAbilityName()

    caster:SwapAbilities(main_ability_name, sub_ability_name, false, true)
end

-- Reverts back to the original model, swaps abilities, removes modifier passed
function CrowFormEnd( event )
    local caster = event.caster
    local ability = event.ability
    local modifier = event.remove_modifier_name

    caster:RemoveGesture(ACT_DOTA_IDLE_RARE)
    caster:Stop()
    caster:SetModelScale(0.7)

    -- Reverts model
    caster:RemoveModifierByName("modifier_druid_crow_model")

    -- Remove abilities and modifiers from weapon/armor upgrades
    for i=0,15 do
        local ability = caster:GetAbilityByIndex(i)
        if ability then
            local ability_name = ability:GetAbilityName()
            if ( string.match(ability_name, "nightelf_strength_of_the_wild") or string.match(ability_name, "nightelf_reinforced_hides") ) then
                caster:RemoveAbility(ability:GetAbilityName())
            end
        end
    end

    caster:RemoveModifierByName("modifier_strength_of_the_wild")
    caster:RemoveModifierByName("modifier_druids_mountain_giant_damage")
    caster:RemoveModifierByName("modifier_reinforced_hides")

    -- Swap the sub_ability back to normal
    local main_ability_name = event.main_ability_name
    local sub_ability_name = ability:GetAbilityName()

    caster:SwapAbilities(sub_ability_name, main_ability_name, false, true)

    -- Remove modifier
    caster:RemoveModifierByName("modifier_crow_form")
end
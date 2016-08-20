--[[
    Replaces the building to the upgraded unit name
]]--
function UpgradeBuilding( event )
    local caster = event.caster
    local new_unit = event.UnitName
    local position = caster:GetAbsOrigin()
    local playerID = caster:GetPlayerOwnerID()
    local player = PlayerResource:GetPlayer(playerID)
    local currentHealthPercentage = caster:GetHealthPercent() * 0.01

    -- Keep the gridnav blockers, hull radius and orientation
    local blockers = caster.blockers
    local hull_radius = caster:GetHullRadius()
    local flag = caster.flag
    local flag_type = caster.flag_type
    local angle = caster:GetAngles()
    local bApplyBlight = caster:HasModifier("modifier_grid_blight")

    -- New building
    local building = BuildingHelper:UpgradeBuilding(caster, new_unit)
    building:SetHullRadius(hull_radius)

    -- Keep the rally flag reference if there is one
    building.flag = flag

    -- If the building to ugprade is selected, change the selection to the new one
    if PlayerResource:IsUnitSelected(playerID, caster) then
        PlayerResource:AddToSelection(playerID, building)
    end

     -- Add to the Food Limit if possible
    local old_food = GetFoodProduced(caster)
    local new_food = GetFoodProduced(building)
    if new_food ~= old_food then
        Players:ModifyFoodLimit(playerID, new_food - old_food)
    end

    -- Add roots to ancient
    local ancient_roots = building:FindAbilityByName("nightelf_uproot")
    if ancient_roots then
        ancient_roots:ApplyDataDrivenModifier(building, building, "modifier_rooted_ancient", {})
    end

    -- Keep blight
    if bApplyBlight then
        building:AddNewModifier(building, nil, "modifier_grid_blight", {})
    end
    
    -- If the upgraded building is a city center, update the city_center_level if required
    if IsCityCenter(building) then
        local level = building:GetLevel()
        local city_center_level = Players:GetCityLevel(playerID)
        PlayerResource:SetDefaultSelectionEntity(playerID, building)
        if level > city_center_level then
            Players:SetCityCenterLevel( playerID, level )
        end
    end

    -- Update the references to the new building
    local entangled_gold_mine = caster.entangled_gold_mine
    if IsValidAlive(entangled_gold_mine) then
        entangled_gold_mine.city_center = building
        building.entangled_gold_mine = caster.entangled_gold_mine
        building:SwapAbilities("nightelf_entangle_gold_mine", "nightelf_entangle_gold_mine_passive", false, true)
    end

    -- Remove the old building from the structures list and add the new building to the structures list
    Players:UpgradeStructure( playerID, caster, building )
        
    -- Remove old building entity
    caster:RemoveSelf()

    local newRelativeHP = math.max(building:GetMaxHealth() * currentHealthPercentage, 1)
    building:SetHealth(newRelativeHP)

    -- Update the abilities of the units and structures
    local playerUnits = Players:GetUnits(playerID)
    for k,unit in pairs(playerUnits) do
        CheckAbilityRequirements( unit, playerID )
    end

    local playerStructures = Players:GetStructures(playerID)
    for k,structure in pairs(playerStructures) do
        CheckAbilityRequirements( structure, playerID )
    end
end

--[[
    Disable any queue-able ability that the building could have, because the caster will be removed when the channel ends
    A modifier from the ability can also be passed here to attach particle effects
]]--
function StartUpgrade( event )  
    local caster = event.caster
    local ability = event.ability
    local modifier_name = event.ModifierName
    local lumberCost = event.ability:GetSpecialValueFor("lumber_cost")
    local playerID = caster:GetPlayerOwnerID()

    if lumberCost and lumberCost > Players:GetLumber(playerID) then
        return
    end

    -- Iterate through abilities marking those to disable
    local abilities = {}
    for i=0,15 do
        local abil = caster:GetAbilityByIndex(i)
        if abil then
            local ability_name = abil:GetName()

            -- Abilities to hide include the strings train_ and research_, the rest remain available
            if string.match(ability_name, "train_") or string.match(ability_name, "research_") then
                table.insert(abilities, abil)
            end
        end
    end

    -- Keep the references to enable if the upgrade gets canceled
    caster.disabled_abilities = abilities

    -- Units can't attack while upgrading
    caster.original_attack = caster:GetAttackCapability()
    caster:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK)

    for k,disable_ability in pairs(abilities) do
        disable_ability:SetHidden(true)     
    end

    -- Pass a modifier with particle(s) of choice to show that the building is upgrading. Remove it on CancelUpgrade
    if modifier_name then
        ability:ApplyDataDrivenModifier(caster, caster, modifier_name, {})
        caster.upgrade_modifier = modifier_name
    end

    FireGameEvent( 'ability_values_force_check', { player_ID = playerID })
end

-- Resets any change done in StartUpgrade
function CancelUpgrade( event )
    local caster = event.caster
    local abilities = caster.disabled_abilities
    local playerID = caster:GetPlayerOwnerID()

    -- Give the unit their original attack capability
    caster:SetAttackCapability(caster.original_attack)

    for k,ability in pairs(abilities) do
        ability:SetHidden(false)        
    end

    local upgrade_modifier = caster.upgrade_modifier
    if upgrade_modifier and caster:HasModifier(upgrade_modifier) then
        caster:RemoveModifierByName(upgrade_modifier)
    end

    FireGameEvent( 'ability_values_force_check', { player_ID = playerID })
end

-- Forces an ability to level 0
function SetLevel0( event )
    local ability = event.ability
    if ability:GetLevel() == 1 then
        ability:SetLevel(0) 
    end
end

-- Hides an ability
function HideAbility( event )
    local ability = event.ability
    ability:SetHidden(true)
end
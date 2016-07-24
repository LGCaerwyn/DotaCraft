function Root( event )
    BuildingHelper:AddBuilding(event)

    local ability = event.ability
    local caster = event.caster
    local playerID = caster:GetPlayerOwnerID()
    local teamNumber = caster:GetTeamNumber()
    local ancient_name = caster:GetUnitName()
    local construction_size = BuildingHelper:GetConstructionSize(ancient_name)
    
    -- Callbacks
    event:OnPreConstruction(function(vPos) end)

    -- Position for a building was confirmed and valid
    event:OnBuildingPosChosen(function(vPos)
        -- Enemy unit check
        local target_type = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
        local flags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS
        local enemies = FindUnitsInRadius(teamNumber, vPos, nil, construction_size, DOTA_UNIT_TARGET_TEAM_ENEMY, target_type, flags, FIND_ANY_ORDER, false)

        if #enemies > 0 then
            SendErrorMessage(caster:GetPlayerOwnerID(), "#error_invalid_build_position")
            return false
        end

        return true
    end)

    event:OnConstructionFailed(function()
        SendErrorMessage(playerID, "#error_invalid_build_position")
    end)

    event:OnConstructionCancelled(function(work) end)

    event:OnConstructionStarted(function(unit)
        RootStart(unit)
    end)

    event:OnConstructionCompleted(function(unit) end)
end

function RootStart( unit )
    local ancient_name = unit:GetUnitName()
    local construction_size = BuildingHelper:GetConstructionSize(ancient_name)
    local pathing_size = BuildingHelper:GetBlockPathingSize(ancient_name)

    BuildingHelper:RemoveBuilder(unit)

    local position = unit:GetAbsOrigin()
    BuildingHelper:SnapToGrid(construction_size, position)
    unit:MoveToPosition(Vector(position.x, position.y-1, position.z)) --Look forward

    local gridNavBlockers = BuildingHelper:BlockGridSquares(construction_size, pathing_size, position)
    unit.blockers = gridNavBlockers

    unit:SetAbsOrigin(position)
    unit:SetAngles(0,-90,0)
    unit:StartGesture(ACT_DOTA_CAST_ABILITY_5) --Treant protector overgrowth
    unit:RemoveModifierByName("modifier_uprooted")
    unit:SwapAbilities("nightelf_uproot", "nightelf_root", true, false)
    unit:FindAbilityByName("nightelf_root"):SetLevel(1)

    -- Apply rooted particles
    local uproot_ability = unit:FindAbilityByName("nightelf_uproot")
    uproot_ability:ApplyDataDrivenModifier(unit, unit, "modifier_rooted_ancient", {})

    BuildingHelper:AddModifierBuilding(unit)
    Queue:Init(unit)

    local cast_time = 2--ability:GetCastPoint()
    Timers:CreateTimer(cast_time, function()
        if IsValidAlive(unit) then
            RootEnd(unit)
        end
    end)
end

function RootEnd( unit )
    unit:SetArmorType("fortified")
    unit:SetHullRadius(unit.collision_size)

    -- Show all train and research abilities
    for i=0,15 do
        local ability = unit:GetAbilityByIndex(i)
        if ability then
            if ability:IsHidden() and ( string.match(ability:GetAbilityName(), "train_") or string.match(ability:GetAbilityName(), "research_")) then
                ability:SetHidden(false)
            elseif ability:GetAbilityName() == "nightelf_eat_tree" then
                ability:SetHidden(true)
            end
        end
    end

    -- Look for a gold mine to entangle if its a tree of Life/Ages/Eternity
    local unitName = unit:GetUnitName()
    if (unitName == "nightelf_tree_of_life" or unitName == "nightelf_tree_of_ages" or unitName == "nightelf_tree_of_eternity") then
        AutoEntangle({caster = unit})

    -- Tower
    elseif unitName == "nightelf_ancient_protector" then

        unit:RemoveModifierByName("modifier_uprooted_ancient_protector")
        caster:SetAttackCapability(DOTA_UNIT_CAP_RANGED_ATTACK)
    
    -- Shop
    elseif unitName == "nightelf_ancient_of_wonders" then
        TeachAbility(unit, "ability_shop")        
    end
end

function AutoEntangle( event )
    local caster = event.caster
    -- If it's uprooted or already has an entangled mine, skip
    if not IsCustomBuilding(caster) or IsUprooted(caster) or IsValidAlive(caster.entangled_gold_mine) then
        return
    end

    local free_mine_in_range = FindGoldMineForEntangling(caster)
    if free_mine_in_range then
        EntangleGoldMine({caster = caster, target = free_mine_in_range})
    end
end

function FindGoldMineForEntangling( unit )
    local radius = 900+unit:GetHullRadius()
    local units = FindUnitsInRadius(unit:GetTeamNumber(), unit:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_BUILDING, DOTA_UNIT_TARGET_FLAG_INVULNERABLE, 0, false)
    for k,gold_mine in pairs(units) do
        if not gold_mine.building_on_top then
            return gold_mine
        end
    end
end

-- Initial cast of the root ability
function UpRootStart( event )
    local caster = event.caster
    caster.collision_size = caster.collision_size or caster:GetHullRadius()

    -- Don't allow uprooting until the ancient has finished construction
    if caster:IsUnderConstruction() then
        caster:Stop()
        return
    end

    -- Remove building properties
    Queue:Remove(caster)
    BuildingHelper:RemoveBuilding( caster, false )

    -- If the ancient had an entangled mine, remove the effect, which will trigger ShowGoldMine
    if IsValidEntity(caster.entangled_gold_mine) then
        caster.entangled_gold_mine:RemoveModifierByName("modifier_entangled_mine")
    end
end

-- Finished uprooting, the ancient is now a mobile unit
function UpRoot( event )
    local caster = event.caster
    local ability = event.ability
    local unitName = caster:GetUnitName()

    caster:SetHullRadius(32)
    caster:RemoveModifierByName("modifier_building")
    ability:ApplyDataDrivenModifier(caster,caster,"modifier_uprooted",{})

    -- Tower: Reduce its damage by 20, (1.5 BAT) and make it melee (128 range)
    if unitName == "nightelf_ancient_protector" then

        event.ability:ApplyDataDrivenModifier(caster, caster, "modifier_uprooted_ancient_protector", {})
        caster:SetAttackCapability(DOTA_UNIT_CAP_MELEE_ATTACK)
    
    -- Shop: Disable shopping while uprooted
    elseif unitName == "nightelf_ancient_of_wonders" then
        caster:RemoveAbility("ability_shop")
        caster:RemoveModifierByName("modifier_shop")
    end

    caster:RemoveModifierByName("modifier_building")

    caster:SetArmorType("heavy")

    -- Set the builder abilities
    BuildingHelper:InitializeBuilder(caster)
    if not caster:HasAbility("nightelf_root") then
        caster:AddAbility("nightelf_root")
    end
    caster:FindAbilityByName("nightelf_root"):SetLevel(1)
    caster:SwapAbilities("nightelf_uproot", "nightelf_root", false, true)

    Players:ClearPlayerFlags( caster:GetPlayerOwnerID() )

    -- Hide all train and research abilities, show eat tree
    for i=0,15 do
        local ability = caster:GetAbilityByIndex(i)
        if ability then
            if ( string.match(ability:GetAbilityName(), "train_") or string.match(ability:GetAbilityName(), "research_")) then
                ability:SetHidden(true)
            elseif ability:GetAbilityName() == "nightelf_eat_tree" or ability:GetAbilityName() == "nightelf_entangle_gold_mine" then
                ability:SetHidden(false)
            end
        end
    end

    -- Remove the rooted particle
    caster:RemoveModifierByName("modifier_rooted_ancient")

    -- Cancel anything on the buildings queue
    for j=0,5 do
        local item = caster:GetItemInSlot(j)
        if item and IsValidEntity(item) then
            caster:CastAbilityImmediately(item, caster:GetPlayerOwnerID())
        end
    end
    -- Gotta remove one extra time for some reason
    local item = caster:GetItemInSlot(0)
    if item then
        caster:CastAbilityImmediately(item, caster:GetPlayerOwner():GetEntityIndex())
    end
end

-- Roots the tree next to a gold mine and starts the construction of a entangled mine
function EntangleGoldMine( event )
    local caster = event.caster
    local target = event.target

    if target:GetUnitName() ~= "gold_mine" or IsValidAlive(target.building_on_top) then
        print("Must target a valid free gold mine")
        return
    else
        if caster:HasModifier("modifier_uprooted") then
            -- Cast root close to the gold mine
            RootStart(caster)

        else
            print("Begining construction of a Entangled Gold Mine")

            -- Show passive indicating this ancient has a gold mine entangled
            caster:SwapAbilities("nightelf_entangle_gold_mine", "nightelf_entangle_gold_mine_passive", false, true)

            local player = caster:GetPlayerOwner()
            local hero = player:GetAssignedHero()
            local playerID = player:GetPlayerID()
            local mine_pos = target:GetAbsOrigin()

            -- Create and entangled gold mine building on top of the gold mine
            local building = CreateUnitByName("nightelf_entangled_gold_mine", mine_pos, false, hero, hero, hero:GetTeamNumber())
            building:SetOwner(hero)
            building:SetAbsOrigin(mine_pos)
            building:SetNeverMoveToClearSpace(true)
            building:SetControllableByPlayer(playerID, true)
            building.state = "building"
            building:AddNewModifier(building,nil,"modifier_building",{})
            building:SetForwardVector(target:GetForwardVector()) -- Keep orientation

            -- Hide the gold mine
            target:AddNoDraw()
            ApplyModifier(target, "modifier_unselectable")

            local entangle_ability = caster:FindAbilityByName("nightelf_entangle_gold_mine")
            local build_time = entangle_ability:GetSpecialValueFor("build_time")
            local hit_points = building:GetMaxHealth()

            -- Start building construction ---
            local initial_health = 0.10 * hit_points
            local time_completed = GameRules:GetGameTime()+build_time
            local update_health_interval = build_time / math.floor(hit_points-initial_health) -- health to add every tick
            building:SetHealth(initial_health)
            building.bUpdatingHealth = true

            -- Particle effect
            NightElfConstructionParticle({target=building})
            function building:IsUnderConstruction() return true end
            building.updateHealthTimer = Timers:CreateTimer(function()
                if not IsValidAlive(caster) then
                    building:ForceKill(true)
                    return
                end

                if IsValidAlive(building) then
                    local timesUp = GameRules:GetGameTime() >= time_completed
                    if not timesUp then
                        if building.bUpdatingHealth then
                              if building:GetHealth() < hit_points then
                                building:SetHealth(building:GetHealth() + 1)
                              else
                                building.bUpdatingHealth = false
                             end
                        end
                    else
                        -- Show the gold counter and initialize the mine builders list
                        building.counter_particle = ParticleManager:CreateParticle("particles/custom/gold_mine_counter.vpcf", PATTACH_CUSTOMORIGIN, building)
                        ParticleManager:SetParticleControl(building.counter_particle, 0, Vector(mine_pos.x,mine_pos.y,mine_pos.z+200))
                        ParticleManager:DestroyParticle(target.construction_particle, true)
                        target.construction_particle = nil

                        building.constructionCompleted = true
                        building.state = "complete"
                        function building:IsUnderConstruction() return false end
                        print("Finished Entangled Gold Mine process")
                        return
                    end
                else
                    -- Building destroyed
                    print("Entangled gold mine was destroyed during the construction process!")

                    return
                end
                return update_health_interval
             end)
             ---------------------------------

            target:SetCapacity(5)
            building.mine = target -- A reference to the mine that the entangled mine is associated with
            building.city_center = caster -- A reference to the city center that entangles this mine
            caster.entangled_gold_mine = building -- A reference to the entangled building of the city center
            target.building_on_top = building -- A reference to the building that entangles this gold mine
        end
    end
end

-- Triggers ShowGoldMine on the entangled mine OnOwnerDied
function RemoveEntangledMine( event )
    local caster = event.caster
    if IsValidEntity(caster.entangled_gold_mine) and caster.entangled_gold_mine == caster then
        caster.entangled_gold_mine:RemoveModifierByName("modifier_entangled_mine")
    end
end

-- Show the mine (when killed either through uprooting or attackers)
function ShowGoldMine( event )
    local building = event.caster
    local ability = event.ability
    local mine = building.mine
    local city_center = building.city_center

    print("Removing Entangled Gold Mine")
    mine:RemoveNoDraw()
    mine:RemoveModifierByName("modifier_unselectable")

    -- Eject all wisps 
    local wisps = mine:GetGatherers()
    for _,wisp in pairs(wisps) do
        FindClearSpaceForUnit(wisp, mine.entrance, true)
        wisp:CancelGather()
    end

    if building.counter_particle then
        ParticleManager:DestroyParticle(building.counter_particle, true)
    end
    
    RemoveConstructionEffect(building)

    -- Show an ability to re-entangle a gold mine on the city center if it is still rooted
    if IsValidAlive(city_center) then
        city_center:SwapAbilities("nightelf_entangle_gold_mine", "nightelf_entangle_gold_mine_passive", true, false)

        -- Remove the references
        city_center.entangled_gold_mine = nil
    end
    building:AddNoDraw()
    mine.building_on_top = nil
end

-- Orders a wisp to use its gather ability on this entangled gold mine
function LoadWisp( event )
    local caster = event.caster --The entangled gold mine
    local target = event.target

    if target:GetUnitName() ~= "nightelf_wisp" then
        print("Must target a wisp")
        return
    else
        local gather = target:GetGatherAbility()
        if gather and gather:IsFullyCastable() then
            ExecuteOrderFromTable({ UnitIndex = target:GetEntityIndex(), OrderType = DOTA_UNIT_ORDER_CAST_TARGET, TargetIndex = caster:GetEntityIndex(), AbilityIndex = gather:GetEntityIndex(), Queue = false}) 
        end
    end
end

-- Ejects the first wisp on the mine
function UnloadWisp( event )
    local caster = event.caster
    local mine = caster.mine

    local wisps = mine:GetGatherers()
    for _,wisp in pairs(wisps) do
        FindClearSpaceForUnit(wisp, mine.entrance, true)
        wisp:CancelGather()
        break
    end

    mine:SetCounter(TableCount(mine:GetGatherers()))
end


function UnloadAll( event )
    for i=1,5 do
        Timers:CreateTimer(0.03*i, function() 
            UnloadWisp(event)
        end)
    end
end



-- Applies natures blessing bonus with ancient protector exception
function NaturesBlessing( event )
    local building = event.caster
    local ability = event.ability

    if building:GetUnitName() == "nightelf_ancient_protector" then
        ability:ApplyDataDrivenModifier(building, building, "modifier_natures_blessing_tower", {})
    else
        ability:ApplyDataDrivenModifier(building, building, "modifier_natures_blessing_tree", {})
    end

end

-- Cuts down a tree
function EatTree( event )    
    local caster = event.caster
    local target = event.target
    local ability = event.ability

    caster:StartGesture(ACT_DOTA_ATTACK)
    
    Timers:CreateTimer(0.5, function()
        target:CutDown(caster:GetTeamNumber())
        local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_treant/treant_leech_seed.vpcf", PATTACH_CUSTOMORIGIN, caster)
        ParticleManager:SetParticleControl(particle, 0, target:GetAbsOrigin())
        ParticleManager:SetParticleControl(particle, 1, target:GetAbsOrigin())
        ParticleManager:SetParticleControl(particle, 3, target:GetAbsOrigin())
    end)

    Timers:CreateTimer(1, function()
        ability:ApplyDataDrivenModifier(caster, caster, "modifier_eat_tree", {})
    end)
end

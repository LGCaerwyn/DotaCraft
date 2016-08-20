-- Gets the summoning location for the new unit
function SummonLocation( event )
    local caster = event.caster
    local fv = caster:GetForwardVector()
    local origin = caster:GetAbsOrigin()
    
    -- Gets the vector facing 200 units away from the caster origin
    local front_position = origin + fv * 200

    local result = { }
    table.insert(result, front_position)

    return result
end

-- Set the units looking at the same point of the caster
function SetUnitsMoveForward( event )
    local caster = event.caster -- The Blood Mage
    local target = event.target -- The Phoenix
    local fv = caster:GetForwardVector()
    local origin = caster:GetAbsOrigin()
    
    target:SetForwardVector(fv)

    -- Keep reference to the phoenix
    caster.phoenix = target
    target:SetOwner(caster) --The Blood Mage has ownership over this, not the main hero
end

-- Kills the summoned units after a new spell start
function KillPhoenix( event )
    local caster = event.caster
    local phoenix = caster.phoenix
    local egg = caster.egg

    if IsValidEntity(phoenix) then phoenix:RemoveSelf() end
    if IsValidEntity(egg) then egg:RemoveSelf() end
end

-- Deal self damage over time, through magic immunity. This is needed because negative HP regen is not working.
function PhoenixDegen( event )
    local caster = event.caster
    local ability = event.ability
    local phoenix_damage_per_second = ability:GetLevelSpecialValueFor( "phoenix_damage_per_second", ability:GetLevel() - 1 )

    local phoenixHP = caster:GetHealth()

    caster:SetHealth(phoenixHP - phoenix_damage_per_second)

    -- On Health 0 spawn an Egg (same as OnDeath)
    if caster:GetHealth() == 0 then
        PhoenixEgg(event)
    end
end

-- Removes the phoenix and spawns the egg with a timer
function PhoenixEgg( event )
    local caster = event.caster --the phoenix
    local ability = event.ability
    local hero = caster:GetOwner()
    local phoenix_egg_duration = ability:GetLevelSpecialValueFor( "phoenix_egg_duration", ability:GetLevel() - 1 )

    -- Set the position, a bit floating over the ground
    local origin = caster:GetAbsOrigin()
    local position = Vector(origin.x, origin.y, origin.z+50)

    local egg = CreateUnitByName("human_phoenix_egg", origin, true, hero, hero, hero:GetTeamNumber())
    egg:SetAbsOrigin(position)

    -- Keep reference to the egg
    hero.egg = egg

    -- Apply modifiers for the summon properties
    egg:AddNewModifier(hero, ability, "modifier_kill", {duration = phoenix_egg_duration})

    -- Remove the phoenix
    caster:RemoveSelf()
end

-- Check if the egg died from an attacker other than the time-out
function PhoenixEggCheckReborn( event )
    local unit = event.unit --the egg
    local attacker = event.attacker
    local ability = event.ability
    local hero = unit:GetOwner()
    local player = hero:GetPlayerOwner()
    local playerID = hero:GetPlayerID()

    if unit == attacker then
        local phoenix = CreateUnitByName("human_phoenix", unit:GetAbsOrigin(), true, player, hero, hero:GetTeamNumber())
        phoenix:SetControllableByPlayer(playerID, true)

        -- Keep reference
        hero.egg = egg
    else
        local particleName = "particles/units/heroes/hero_phoenix/phoenix_supernova_death.vpcf"
        local particle = ParticleManager:CreateParticle(particleName, PATTACH_CUSTOMORIGIN, unit)
        ParticleManager:SetParticleControl(particle, 0, unit:GetAbsOrigin())
        ParticleManager:SetParticleControl(particle, 1, unit:GetAbsOrigin())
        ParticleManager:SetParticleControl(particle, 3, unit:GetAbsOrigin())
    end

    -- Remove the egg
    unit:RemoveSelf()
end
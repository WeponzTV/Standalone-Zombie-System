
-- Combined the base zombie and safezone code into standalone script package.
-- Fixed how zombies would be driving vehicles before getting out to wander.
-- Fixed how zombies would run at a player even though they're in a vehicle.
-- Upgraded the efficiency by replacing vDist and combining zombie while loops.
-- Fixed how zombies would get stuck against walls and objects while chasing.

-- By PatalJunior#3568
-- Major performance improvements
-- Better zombie logic for viewing and following player
-- Better code nomenclatures 


ClearArea(GetEntityCoords(PlayerPedId()), 1000, true, false, false, false)

local Shooting = false
local Running = false

local SafeZones = {
    {coords = vector3(450.5966,-998.9636,28.4284) , radius = 80.0},-- Mission Row
    {coords = vector3( 1853.6666, 3688.0222, 33.2777) , radius = 40.0},-- Sandy Shores
    {coords = vector3( -104.1444, 6469.3888, 30.6333) , radius = 60.0}-- Paleto Bay
}

AddRelationshipGroup('ZOMBIE')
SetRelationshipBetweenGroups(0, GetHashKey('ZOMBIE'), GetHashKey('PLAYER'))
SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GetHashKey('ZOMBIE'))

local function IsPlayerShooting()
    return Shooting
end

local function IsPlayerRunning()
    return Running
end

local PlayerPed = PlayerPedId() -- Assuming the ped doesn't change, save processing time

CreateThread(function()-- Will only work in it's own while loop
    while true do
        Wait(5) -- No need to to less wait than 5, since 5ms is 200FPS, and game maxes at 188FPS at most

        -- Peds
        SetPedDensityMultiplierThisFrame(3.0)
        SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)

        -- Vehicles
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(0.0)
        SetVehicleDensityMultiplierThisFrame(0.0)
    end
end)

CreateThread(function()-- Will only work in it's own while loop
    while true do
        Wait(5)

        if IsPedShooting(PlayerPed) then
	        Shooting = true
	        Wait(5000)
	        Shooting = false
	    end

	    if IsPedSprinting(PlayerPed) or IsPedRunning(PlayerPed) then
	        if Running == false then
	            Running = true
	        end
	    else
	        if Running == true then
	            Running = false
	        end
	    end
    end
end)


CreateThread(function()
	for _, zone in pairs(SafeZones) do
    	local Blip = AddBlipForRadius(zone.coords, zone.radius)
		SetBlipHighDetail(Blip, true)
    	SetBlipColour(Blip, 2)
    	SetBlipAlpha(Blip, 128)
	end

    while true do
        Wait(500)

    	for _, zone in pairs(SafeZones) do
	        local Zombie = -1
	        local Success = false
	        local Handler, Zombie = FindFirstPed()

	        repeat
	            if IsPedHuman(Zombie) and not IsPedAPlayer(Zombie) and not IsPedDeadOrDying(Zombie, true) then
	                local pedcoords = GetEntityCoords(Zombie)
	              	local zonecoords = zone.coords
	                local distance = #(zonecoords - pedcoords)

	                if distance <= zone.radius then
	                    DeleteEntity(Zombie)
	                end
	            end

	            Success, Zombie = FindNextPed(Handler)
	        until not (Success)

	        EndFindPed(Handler)
	    end


		for Zombie in EnumeratePeds() do
			Wait(100)
			if IsPedHuman(Zombie) and not IsPedAPlayer(Zombie) and not IsPedDeadOrDying(Zombie, true) then
				local PlayerCoords = GetEntityCoords(PlayerPed)
				local PedCoords = GetEntityCoords(Zombie)
				local Distance = #(PedCoords - PlayerCoords)
				local DistanceTarget
				local alertness = GetPedAlertness(Zombie)
				if alertness == 1 then
					print("heard")
					DistanceTarget = 130.0
				elseif alertness == 2 then
					print("knows")
					DistanceTarget = 150.0
				elseif alertness == 3 then
					print("full alert")
					DistanceTarget = 200.0
				else
					DistanceTarget = 20.0
				end

				if Distance <= DistanceTarget and not IsPedInAnyVehicle(PlayerPed, false) then
					TaskGoToEntity(Zombie, PlayerPed, -1, 0.0, 2.0, 1073741824, 0)
				end

				if Distance <= 1.3 then
					if not IsPedRagdoll(Zombie) and not IsPedGettingUp(Zombie) then
						local health = GetEntityHealth(PlayerPed)
						if health == 0 then
							ClearPedTasks(Zombie)
							TaskWanderStandard(Zombie, 10.0, 10)
						else
							RequestAnimSet('melee@unarmed@streamed_core_fps')
							while not HasAnimSetLoaded('melee@unarmed@streamed_core_fps') do
								Wait(10)
							end

							TaskPlayAnim(Zombie, 'melee@unarmed@streamed_core_fps', 'ground_attack_0_psycho', 8.0, 1.0, -1, 48, 0.001, false, false, false)

							ApplyDamageToPed(PlayerPed, 5, false)
						end
					end
				end
				
				if not NetworkGetEntityIsNetworked(Zombie) then
					DeleteEntity(Zombie)
				end
				
				Success, Zombie = FindNextPed(Handler)

			end
		end


   	end
end)


AddEventHandler("populationPedCreating", function(x, y, z) --Instead of setting every ped, we only set the peds that were just created
	Wait(500) -- Give the entity some time to be created
	local _, Zombie = GetClosestPed(x, y, z, 3.0, 1, 0) -- Get the entity handle

	if Zombie == 0 then
		CancelEvent()
	end

	ClearPedTasks(Zombie)
	ClearPedSecondaryTask(Zombie)
	ClearPedTasksImmediately(Zombie)
	TaskWanderStandard(Zombie, 10.0, 10)
	SetPedRelationshipGroupHash(Zombie, 'ZOMBIE')
	ApplyPedDamagePack(Zombie, 'BigHitByVehicle', 0.0, 1.0)
	SetEntityHealth(Zombie, 200)

	RequestAnimSet('move_m@drunk@verydrunk')
	while not HasAnimSetLoaded('move_m@drunk@verydrunk') do
		Wait(5)
	end
	SetPedMovementClipset(Zombie, 'move_m@drunk@verydrunk', 1.0)

	SetPedConfigFlag(Zombie, 100, false)

	SetPedRagdollBlockingFlags(Zombie, 1)
	SetPedHearingRange(Zombie,300.0)
	SetPedCanRagdollFromPlayerImpact(Zombie, false)
	SetPedSuffersCriticalHits(Zombie, true)
	SetPedEnableWeaponBlocking(Zombie, true)
	DisablePedPainAudio(Zombie, true)
	StopPedSpeaking(Zombie, true)
	SetPedDiesWhenInjured(Zombie, false)
	StopPedRingtone(Zombie)
	SetPedMute(Zombie)
	SetPedIsDrunk(Zombie, true)
	SetPedConfigFlag(Zombie, 166, false)
	SetPedConfigFlag(Zombie, 170, false)
	SetBlockingOfNonTemporaryEvents(Zombie, true)
	SetPedCanEvasiveDive(Zombie, false)
	RemoveAllPedWeapons(Zombie, true)

end)
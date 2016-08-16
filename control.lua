require("config")

jobs = {}

propagations = {}

-- Make sure that we have a tick available for the tick hook
for k,a_type in pairs(types) do
	a_type.tick = math.random(a_type.tick_min, a_type.tick_max)
end

function tick()
 	for k,a_type in pairs(types) do
		a_type.tick = a_type.tick - 1
		if a_type.tick <= 0 or a_type.tick == nil then
			try_propagate(a_type)
			-- Reset tick counter
			a_type.tick = math.random(a_type.tick_min, a_type.tick_max)
		end
		end
		handle_jobs()
		propagate()
end

function try_propagate(a_type)
		local surface = game.surfaces[a_type.surface]

	-- Validate the surface exists
	if surface ~= nil then

		local selected_chunks = {}
		for chunk in surface.get_chunks() do
			if math.random() <= a_type.selection_chance then
				table.insert(selected_chunks, chunk)
			end
		end

		-- If chunks have been selected to propogate the type,
		-- create the job 
		if #selected_chunks > 0 then
			local job = {}
			job.name = a_type.name
			job.chunks = selected_chunks

			local propagation = {}
			propagation.surface = a_type.surface
			propagation.tick_wait = 0
			propagation.per_tick = 0
			propagation.props = {}

			job.propagation = propagation

			table.insert(jobs, job)
		end
	end
end

function propagate()
	-- Iterate through all current propagations
	for i, propagation in ipairs(propagations) do
		propagation.tick_current = propagation.tick_current - 1
		-- If we are at the point of propagation
		if propagation.tick_current < 1 then
			-- Grab the surface
			local surface = game.surfaces[propagation.surface]
			-- Iterate through the 
			for i=1,propagation.per_tick do
				local prop = table.remove(propagation.props, 1)
				-- Propogate if all of the conditions are met
				if prop ~= nil and math.random() <= prop.chance and surface.can_place_entity{name=prop.name, position=prop.position} then
					surface.create_entity{name=prop.name, position=prop.position}
				end
			end
			propagation.tick_current = propagation.tick_wait

			-- Remove it if it has completed
			if #propagation.props == 0 then
				table.remove(propagations, i)
			end
		end
	end
end

function handle_jobs()
	local job = table.remove(jobs,1)

	if job ~= nil then
		local propagation = job.propagation
		-- Grab the surface
		local surface = game.surfaces[propagation.surface]

		local a_type = types[job.name]

		-- Process 10 chunks
		for i=1,10 do
			local chunk = table.remove(job.chunks, 1)

			-- If we have a chunk to process
			if chunk ~= nil then
				chunk.x = chunk.x * 32
				chunk.y = chunk.y * 32
				local entities = surface.find_entities_filtered{area={{chunk.x, chunk.y},{chunk.x + 31, chunk.y + 31}}, type=a_type.name}
				local entity_count = table.maxn(entities)

				-- Validate that entities were found
				if entity_count ~= 0 then
					local entity = entities[math.random(entity_count)]
					local prototype = game.entity_prototypes[entity.name]

					local max_place_distance = a_type.max_place_distance

					-- User per-entity variation overrides if available
					local override = a_type.overrides[entity.name]
					local disabled = false
					if override ~= nil then
						if override.max_place_distance ~= nil then max_place_distance = override.max_place_distance end
						if override.disabled ~= nil then disabled = override.disabled end
					end

					-- Calculate the placement position
					local position = {
						math.random(max_place_distance * 2) - max_place_distance + entity.position.x,
						math.random(max_place_distance * 2) - max_place_distance + entity.position.y
					}

					-- Grab the per-tile propogation chance
					local propagation_chance = a_type.propagation_chance[surface.get_tile(position[1], position[2]).name]

					-- Make sure we can handle non-vanilla flooring
					if propagation_chance == nil then
						propagation_chance = 0.05
					end

					-- Only propogate when the tile propogation chance has been specified
					if disabled == false and propagation_chance > 0 then
						local prop = {}
						prop.name = entity.name
						prop.chance = propagation_chance
						prop.position = position

						-- Add a propogation point
						table.insert(propagation.props, prop)
					end
				end
			else
				break
			end
		end

		-- If all chunks have been processed
		if #job.chunks == 0 then
			-- If we have propogation chances
			if #propagation.props > 0 then
				propagation.per_tick = math.floor(#propagation.props / (a_type.tick_min * 0.5) +.5)
				if propagation.per_tick < 1 then propagation.per_tick = 1 end

				propagation.tick_wait = math.floor((a_type.tick_min * 0.5) / #propagation.props) - 1
				if propagation.tick_wait < 1 then propagation.tick_wait = 1 end

				propagation.tick_current = propagation.tick_wait

				-- Add the propogation
				table.insert(propagations, propagation)
			end
		else
			-- Reinsert the job
			job.propagation = propagation
			table.insert(jobs, job)
		end
	end
end

script.on_event(defines.events.on_tick, tick)

script.on_event(defines.events.on_player_joined_game, function(event)
	math.randomseed(game.tick)
end)

Initialise = function()
	local h = fs.open('/System/shelOS.log', 'w')
	h.write('-- shelOS Log --\n')
	h.close()
end

log = function(msg, state)
	state = state or ''
	if state ~= '' then
		state = ' '..state
	end
	local h = fs.open('/System/shelOS.log', 'a')
	h.write('['..os.clock()..state..'] '..tostring(msg) .. '\n')
	h.close()
end

Errors = {}

e = function(msg)
	table.insert(Errors, 1, msg)
	log(msg, 'Error')
end

i = function(msg)
	log(msg, 'Info')
end

w = function(msg)
	log(msg, 'Warning')
end
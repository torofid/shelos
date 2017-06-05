--[[

This essentially allows the programs to run sandboxed. For example, os.shutdown doesn't shut the entire computer down. Instead, it simply stops the program.

]]

local errorHandler = function(program, apiName, name, value)
	if type(value) ~= 'function' then
		return value
	end
	return function(...)local response = {pcall(value, ...)}
				local ok = response[1]
				table.remove(response, 1)
				if ok then
					return unpack(response)
				else
					for i, err in ipairs(response) do
				    	Log.e('['..program.Title..'] Environment Error: '..apiName .. ' Error ('..name..'): /System/API/' .. err)
						error(apiName .. ' Error ('..name..'): /System/API/' .. err)
					end
						
				end
			end
end

function addErrorHandler(program, api, apiName)
	local newApi = {}
	for k, v in pairs(api) do
		newApi[k] = errorHandler(program, apiName, k, v)
	end
	return newApi
end

GetCleanEnvironment = function(self)
	local cleanEnv = {}
	for k, v in pairs(cleanEnvironment) do
		cleanEnv[k] = v
	end
	return cleanEnv
end

Initialise = function(self, program, shell, path, bedrock)
	local env = {}    -- the new instance
	local cleanEnv = self:GetCleanEnvironment()
	setmetatable( env, {__index = cleanEnv} )
	env._G = cleanEnv
	env.fs = addErrorHandler(program, self.FS(env, program, path, bedrock), 'FS API')
	env.io = addErrorHandler(program, self.IO(env, program, path, bedrock), 'IO API')
	env.os = addErrorHandler(program, self.OS(env, program, path, bedrock), 'OS API')
	env.loadfile = function( _sFile)
		local file = env.fs.open( _sFile, "r")
		if file then
			local func, err = loadstring( file.readAll(), env.fs.getName( _sFile) )
			file.close()
			return func, err
		end
		return nil, "File not found"
	end

	env.dofile = function( _sFile )
		local fnFile, e = env.loadfile( _sFile )
		if fnFile then
			setfenv( fnFile, getfenv(2) )
			return fnFile()
		else
			error( e, 2 )
		end
	end

	local tColourLookup = {}
	for n=1,16 do
		tColourLookup[ string.byte( "0123456789abcdef",n,n ) ] = 2^(n-1)
	end

	env.textutils.slowWrite = function( sText, nRate )
		nRate = nRate or 20
		if nRate < 0 then
			error( "rate must be positive" )
		end
		local nSleep = 1 / nRate
			
		sText = tostring( sText )
		local x,y = term.getCursorPos(x,y)
		local len = string.len( sText )
		
		for n=1,len do
			term.setCursorPos( x, y )
			env.os.sleep( nSleep )
			local nLines = write( string.sub( sText, 1, n ) )
			local newX, newY = term.getCursorPos()
			y = newY - nLines
		end
	end

	env.textutils.slowPrint = function( sText, nRate )
		env.textutils.slowWrite( sText, nRate)
		print()
	end

	env.paintutils.loadImage = function( sPath )
		local relPath = Bedrock.Helpers.RemoveFileName(path) .. sPath
		local tImage = {}
		if fs.exists( relPath ) then
			local file = io.open(relPath, "r" )
			local sLine = file:read()
			while sLine do
				local tLine = {}
				for x=1,sLine:len() do
					tLine[x] = tColourLookup[ string.byte(sLine,x,x) ] or 0
				end
				table.insert( tImage, tLine )
				sLine = file:read()
			end
			file:close()
			return tImage
		end
		return nil
	end

	env.shell = {}
	local shellEnv = {}
	setmetatable( shellEnv, { __index = env, fs = fs } )
	setfenv(self.Shell, shellEnv)
	self.Shell(env, program, shell, path, Helpers, os.run)
	env.shell = addErrorHandler(program, shellEnv, 'Shell')
	env.shelOS = addErrorHandler(program, self.shelOS(env, program, path), 'shelOS API')
	env.sleep = env.os.sleep
	env.term = program.Term
	return env
end

IO = function(env, program, path)
	local relPath = Bedrock.Helpers.RemoveFileName(path)
	return {
		input = io.input,
		output = io.output,
		type = io.type,
		close = io.close,
		write = io.write,
		flush = io.flush,
		lines = io.lines,
		read = io.read,
		open = function(_path, mode)
			return io.open(relPath .. _path, mode)
		end
	}
end

shelOS = function(env, program, path)
	local h = fs.open('/System/.version', 'r')
	local version = h.readAll()
	h.close()

	local tAPIsLoading = {}
	return {
		-- TODO: clean up these, lots won't be relevant anymore
		System = System,
		SetBuffer = function(b) program.Buffer = b end,
		ToolBarColour = nil,
		ToolBarColor = nil,
		ToolBarTextColor = colours.black,
		ToolBarTextColour = colours.black,
		OpenFile = System.OpenFile,
		GetIcon = System.GetIcon,
		Settings = Settings,
		Version = version,
		Restart = function(f)System.Restart(f, true)end,
		Reboot = function(f)System.Restart(f, true)end,
		Shutdown = function(f)System.Shutdown(f, false, true)end,
		KillSystem = function()os.reboot()end,
		Clipboard = System.Clipboard,
		FS = fs,
		OSRun = os.run,
		Shell = shell,
		ProgramLocation = program.Path,
		SetTitle = function(title)
			if title and type(title) == 'string' then
				program.Title = title
			end
		end,
		CanClose = function()end,
		Close = function()
			program:Close(true)
		end,
		Run = function(path, ...)
			local args = {...}
			if fs.isDir(path) and fs.exists(path..'/startup') then
				Program:Initialise(shell, path..'/startup', Bedrock.Helpers.RemoveExtension(fs.getName(path)), args)
			elseif not fs.isDir(path) then
				Program:Initialise(shell, path, Bedrock.Helpers.RemoveExtension(fs.getName(path)), args)
			end
		end,
		LoadAPI = function(_sPath, global)
			local sName = Bedrock.Helpers.RemoveExtension(fs.getName( _sPath))
			if tAPIsLoading[sName] == true then
				env.printError( "API "..sName.." is already being loaded" )
				return false
			end
			tAPIsLoading[sName] = true
				
			local tEnv = {}
			setmetatable( tEnv, { __index = env } )
			if not global == false then
				tEnv.fs = fs
			end
			local fnAPI, err = loadfile( _sPath)
			if fnAPI then
				setfenv( fnAPI, tEnv )
				fnAPI()
			else
				printError( err )
		        tAPIsLoading[sName] = nil
				return false
			end
			
			local tAPI = {}
			for k,v in pairs( tEnv ) do
				tAPI[k] =  v
			end
			
			env[sName] = tAPI
			tAPIsLoading[sName] = nil
			return true
		end,
		LoadFile = function( _sFile)
			local file = fs.open( _sFile, "r")
			if file then
				local func, err = loadstring( file.readAll(), fs.getName( _sFile) )
				file.close()
				return func, err
			end
			return nil, "File not found"
		end,
		LoadString = loadstring,
		IO = io,
		DoesRunAtStartup = function()
			if not System.Settings.StartupProgram then
				return false
			end
			return Bedrock.Helpers.TidyPath('/Programs/'..System.Settings.StartupProgram..'/startup') == Bedrock.Helpers.TidyPath(path)
		end,
		RequestRunAtStartup = function()
			if System.Settings.StartupProgram and Bedrock.Helpers.TidyPath('/Programs/'..System.Settings.StartupProgram..'/startup') == Bedrock.Helpers.TidyPath(path) then
				return
			end
			local settings = Settings:GetValues()
			local onBlacklist = false
			local h = fs.open('/System/.StartupBlacklist.settings', 'r')
			if h then
				local blacklist = textutils.unserialize(h.readAll())
				h.close()
				for i, v in ipairs(blacklist) do
					if v == Bedrock.Helpers.TidyPath(path) then
						onBlacklist = true
						return
					end
				end
			end

			if not settings['StartupProgram'] or not Bedrock.Helpers.TidyPath('/Programs/'..settings['StartupProgram']..'/startup') == Bedrock.Helpers.TidyPath(path) then
				System.Bedrock:DisplayAlertWindow("Run at startup?", "Would you like run "..Bedrock.Helpers.RemoveExtension(fs.getName(Bedrock.Helpers.RemoveFileName(path))).." when you turn your computer on?", {"Yes", "No", "Never Ask"}, function(value)
					if value == 'Yes' then
						Settings:SetValue('StartupProgram', fs.getName(Bedrock.Helpers.RemoveFileName(path)))
					elseif value == 'Never Ask' then
						local h = fs.open('/System/.StartupBlacklist.settings', 'r')
						local blacklist = {}
						if h then
							blacklist = textutils.unserialize(h.readAll())
							h.close()
						end
						table.insert(blacklist, Bedrock.Helpers.TidyPath(path))
						local h = fs.open('/System/.StartupBlacklist.settings', 'w')
						if h then
							h.write(textutils.serialize(blacklist))
							h.close()
						end	
					end
				end)
			end
		end,
		Log = {
			i = function(msg)Log.i('['..program.Title..'] '..tostring(msg))end,
			w = function(msg)Log.w('['..program.Title..'] '..tostring(msg))end,
			e = function(msg)Log.e('['..program.Title..'] '..tostring(msg))end,
		},
		Indexer = Indexer
	}
end

FS = function(env, program, path, bedrock)
	local relPath = bedrock.Helpers.RemoveFileName(path)
	local list = {}
	for k, f in pairs(fs) do
		if k ~= 'open' and k ~= 'combine' and k ~= 'copy' and k ~= 'move' and k ~= 'delete' and k ~= 'makeDir' then
			list[k] = function(_path)
				return fs[k](relPath .. _path)
			end
		elseif k == 'delete' or k == 'makeDir' then
			list[k] = function(_path)
				return fs[k](relPath .. _path)
			end
		elseif k == 'copy' or k == 'move' then
			list[k] = function(_path, _path2)
				return fs[k](relPath .. _path, relPath .. _path2)
			end
		elseif k == 'combine' then
			list[k] = function(_path, _path2)
				return fs[k](_path, _path2)
			end
		elseif k == 'open' then
			list[k] = function(_path, mode)
				return fs[k](relPath .. _path, mode)
			end
		end
	end
	return list
end

OS = function(env, program, path)
	local tAPIsLoading = {}
	_os = {

		version = os.version,

		getComputerID = os.getComputerID,

		getComputerLabel = os.getComputerLabel,

		setComputerLabel = os.setComputerLabel,

		run = function( _tEnv, _sPath, ... )
		    local tArgs = { ... }
		    local fnFile, err = loadfile( Bedrock.Helpers.RemoveFileName(path) .. '/' .. _sPath )
		    if fnFile then
		        local tEnv = _tEnv
		        --setmetatable( tEnv, { __index = function(t,k) return _G[k] end } )
				setmetatable( tEnv, { __index = env} )
		        setfenv( fnFile, tEnv )
		        local ok, err = pcall( function()
		        	fnFile( unpack( tArgs ) )
		        end )
		        if not ok then
		        	if err and err ~= "" then
			        	printError( err )
			        end
		        	return false
		        end
		        return true
		    end
		    if err and err ~= "" then
				printError( err )
			end
		    return false
		end,

		loadAPI = function(_sPath)
			local _fs = env.fs

			local sName = _fs.getName( _sPath)
			if tAPIsLoading[sName] == true then
				env.printError( "API "..sName.." is already being loaded" )
				return false
			end
			tAPIsLoading[sName] = true
				
			local tEnv = {}
			setmetatable( tEnv, { __index = env } )
			tEnv.fs = _fs
			local fnAPI, err = env.loadfile( _sPath)
			if fnAPI then
				setfenv( fnAPI, tEnv )
				fnAPI()
			else
				printError( err )
		        tAPIsLoading[sName] = nil
				return false
			end
			
			local tAPI = {}
			for k,v in pairs( tEnv ) do
				tAPI[k] =  v
			end
			
			env[sName] = tAPI

			tAPIsLoading[sName] = nil
			return true
		end,

		unloadAPI = function ( _sName )
			if _sName ~= "_G" and type(env[_sName]) == "table" then
				env[_sName] = nil
			end
		end,

		pullEvent = function(target)
			local eventData = nil
			local wait = true
			while wait do
				eventData = { coroutine.yield(target) }
				if eventData[1] == "terminate" then
					error( "Terminated", 0 )
				elseif target == nil or eventData[1] == target then
					wait = false
				end
			end
			return unpack( eventData )
		end,

		pullEventRaw = function(target)
			local eventData = nil
			local wait = true
			while wait do
				eventData = { coroutine.yield(target) }
				if target == nil or eventData[1] == target then
					wait = false
				end
			end
			return unpack( eventData )
		end,

		queueEvent = function(...)
			program:QueueEvent(...)
		end,

		clock = function()
			return os.clock()
		end,

		startTimer = function(time)
			local timer = os.startTimer(time)
			table.insert(program.Timers, timer)
			return timer
		end,

		time = function()
			return os.time()
		end,

		sleep = function(time)
		    local timer = _os.startTimer( time )
			repeat
				local sEvent, param = _os.pullEvent( "timer" )
			until param == timer
		end,

		day = function()
			return os.day()
		end,

		setAlarm = os.setAlarm,

		shutdown = function()
			program:Close()
		end,

		reboot = function()
			program:Restart()
		end
	}
	return _os
end

Shell = function(env, program, nativeShell, appPath, Helpers, osrun)
	
	local parentShell = nil--nativeShell

	local bExit = false
	local sDir = (parentShell and parentShell.dir()) or ""
	local sPath = (parentShell and parentShell.path()) or ".:/rom/programs"
	local tAliases = {
		ls = "list",
		dir = "list",
		cp = "copy",
		mv = "move",
		rm = "delete",
		preview = "edit"
	}
	local tProgramStack = {fs.getName(appPath)}

	-- Colours
	local promptColour, textColour, bgColour
	if env.term.isColour() then
		promptColour = colours.yellow
		textColour = colours.white
		bgColour = colours.black
	else
		promptColour = colours.white
		textColour = colours.white
		bgColour = colours.black
	end


	local function _run( _sCommand, ... )
		local sPath = nativeShell.resolveProgram(_sCommand)
		if sPath == nil or sPath:sub(1,3) ~= 'rom' then
			sPath = nativeShell.resolveProgram(Bedrock.Helpers.RemoveFileName(appPath) .. '/' ..  _sCommand )
		end

		if sPath ~= nil then
			tProgramStack[#tProgramStack + 1] = sPath
	   		local result = osrun( env, sPath, ... )
			tProgramStack[#tProgramStack] = nil
			return result
	   	else
	    	env.printError( "No such program" )
	    	return false
	    end
	end

	local function runLine( _sLine )
		local tWords = {}
		for match in string.gmatch( _sLine, "[^ \t]+" ) do
			table.insert( tWords, match )
		end

		local sCommand = tWords[1]
		if sCommand then
			return _run( sCommand, unpack( tWords, 2 ) )
		end
		return false
	end

	function run( ... )
		return runLine( table.concat( { ... }, " " ) )
	end

	function exit()
	    bExit = true
	end

	function dir()
		return sDir
	end

	function setDir( _sDir )
		sDir = _sDir
	end

	function path()
		return sPath
	end

	function setPath( _sPath )
		sPath = _sPath
	end

	function resolve( _sPath)
		local sStartChar = string.sub( _sPath, 1, 1 )
		if sStartChar == "/" or sStartChar == "\\" then
			return env.fs.combine( "", _sPath)
		else
			return env.fs.combine( sDir, _sPath)
		end
	end

	resolveProgram = nativeShell.resolveProgram

	programs = nativeShell.programs

	-- function programs( _bIncludeHidden )
	-- 	local tItems = {}

	--     local function addFolder(_fPath)
	--     	for i, f in ipairs(fs.list(_fPath, true)) do
	--     		if not fs.isDir( fs.combine( _fPath, f), true) then
	-- 				if (_bIncludeHidden or string.sub( f, 1, 1 ) ~= ".") then
	-- 					tItems[ f ] = true
	-- 				end
	-- 			end
	--     	end
	--     end

	--     addFolder('/rom/programs/')
	--     addFolder('/rom/programs/color/')
	--     addFolder('/rom/programs/computer/')
	--     if http then
	--     	addFolder('/rom/programs/http/')
	--     end
	--     if turtle then
	--     	addFolder('/rom/programs/turtle/')
	--     end
	--     addFolder(Bedrock.Helpers.RemoveFileName(appPath))

	-- 	-- Sort and return
	-- 	local tItemList = {}
	-- 	for sItem, b in pairs( tItems ) do
	-- 		table.insert( tItemList, sItem )
	-- 	end
	-- 	table.sort( tItemList )
	-- 	return tItemList
	-- end

	function getRunningProgram()
		if #tProgramStack > 0 then
			return tProgramStack[#tProgramStack]
		end
		return nil
	end

	setAlias = nativeShell.setAlias
	clearAlias = nativeShell.clearAlias
	aliases = nativeShell.aliases
end
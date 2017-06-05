local round = function(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

local _w, _h = term.getSize()

Screen = {
	Width = _w,
	Height = _h
}

colours.transparent = 0
colors.transparent = 0

DrawCharacters = function (x, y, characters, textColour, bgColour)
	WriteStringToBuffer(x, y, characters, textColour, bgColour)
end

DrawBlankArea = function (x, y, w, h, colour)
	DrawArea (x, y, w, h, " ", 1, colour)
end

DrawArea = function (x, y, w, h, character, textColour, bgColour)
	--width must be greater than 1, otherwise we get a stack overflow
	if w < 0 then
		w = w * -1
	elseif w == 0 then
		w = 1
	end

	for ix = 1, w do
		local currX = x + ix - 1
		for iy = 1, h do
			local currY = y + iy - 1
			WriteToBuffer(currX, currY, character, textColour, bgColour)
		end
	end
end

DrawImage = function(_x,_y,tImage, w, h)
	if tImage then
		for y = 1, h do
			if not tImage[y] then
				break
			end
			for x = 1, w do
				if not tImage[y][x] then
					break
				end
				local bgColour = tImage[y][x]
	            local textColour = tImage.textcol[y][x] or colours.white
	            local char = tImage.text[y][x]
	            WriteToBuffer(x+_x-1, y+_y-1, char, textColour, bgColour)
			end
		end
	elseif w and h then
		DrawBlankArea(_x, _y, w, h, colours.lightGrey)
	end
end

--using .nft
LoadImage = function(path, global)
	local image = {
		text = {},
		textcol = {}
	}
	if fs.exists(path) then
		local _io = io
		if shelOS then
			_io = shelOS.IO
		end
        local file = _io.open(path, "r")
        local sLine = file:read()
        local num = 1
        while sLine do  
            table.insert(image, num, {})
            table.insert(image.text, num, {})
            table.insert(image.textcol, num, {})
                                        
            --As we're no longer 1-1, we keep track of what index to write to
            local writeIndex = 1
            --Tells us if we've hit a 30 or 31 (BG and FG respectively)- next char specifies the curr colour
            local bgNext, fgNext = false, false
            --The current background and foreground colours
            local currBG, currFG = nil,nil
            for i=1,#sLine do
                    local nextChar = string.sub(sLine, i, i)
                    if nextChar:byte() == 30 then
                            bgNext = true
                    elseif nextChar:byte() == 31 then
                            fgNext = true
                    elseif bgNext then
                            currBG = GetColour(nextChar)
		                    if currBG == nil then
		                    	currBG = colours.transparent
		                    end
                            bgNext = false
                    elseif fgNext then
                            currFG = GetColour(nextChar)
		                    if currFG == nil or currFG == colours.transparent then
		                    	currFG = colours.white
		                    end
                            fgNext = false
                    else
                            if nextChar ~= " " and currFG == nil then
                                    currFG = colours.white
                            end
                            image[num][writeIndex] = currBG
                            image.textcol[num][writeIndex] = currFG
                            image.text[num][writeIndex] = nextChar
                            writeIndex = writeIndex + 1
                    end
            end
            num = num+1
            sLine = file:read()
        end
        file:close()
    else
    	return nil
	end
 	return image
end

DrawCharactersCenter = function(x, y, w, h, characters, textColour,bgColour)
	w = w or Screen.Width
	h = h or Screen.Height
	x = x or 0
	y = y or 0
	x = math.floor((w - #characters) / 2) + x
	y = math.floor(h / 2) + y

	DrawCharacters(x, y, characters, textColour, bgColour)
end

GetColour = function(hex)
	if hex == ' ' then
		return colours.transparent
	end
    local value = tonumber(hex, 16)
    if not value then return nil end
    value = math.pow(2,value)
    return value
end

Clear = function (_colour)
	_colour = _colour or colours.black
	--[[
ClearBuffer()
]]--
	DrawBlankArea(1, 1, Screen.Width, Screen.Height, _colour)
end

Buffer = {}
BackBuffer = {}

DrawBuffer = function()
	for y,row in pairs(Buffer) do
		for x,pixel in pairs(row) do
			local shouldDraw = true
			local hasBackBuffer = true
			if BackBuffer[y] == nil or BackBuffer[y][x] == nil or #BackBuffer[y][x] ~= 3 then
				hasBackBuffer = false
			end
			if hasBackBuffer and BackBuffer[y][x][1] == Buffer[y][x][1] and BackBuffer[y][x][2] == Buffer[y][x][2] and BackBuffer[y][x][3] == Buffer[y][x][3] then
				shouldDraw = false
			end
			if shouldDraw then
				term.setBackgroundColour(pixel[3])
				term.setTextColour(pixel[2])
				term.setCursorPos(x, y)
				term.write(pixel[1])
			end
		end
	end
	BackBuffer = Buffer
	Buffer = {}
end

ClearBuffer = function()
	Buffer = {}
end

WriteStringToBuffer = function (x, y, characters, textColour,bgColour)
	for i = 1, #characters do
			local character = characters:sub(i,i)
			WriteToBuffer(x + i - 1, y, character, textColour, bgColour)
	end
end

WriteToBuffer = function(x, y, character, textColour,bgColour)
	x = round(x)
	y = round(y)
	if bgColour == colours.transparent then
		Buffer[y] = Buffer[y] or {}
		Buffer[y][x] = Buffer[y][x] or {"", colours.white, colours.black}
		Buffer[y][x][1] = character
		Buffer[y][x][2] = textColour
	else
		Buffer[y] = Buffer[y] or {}
		Buffer[y][x] = {character, textColour, bgColour}
	end
end
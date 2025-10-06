local nuvs = require("libs.NuvsModules")
local out = require("scripts.outStrings")
local c = nuvs.ConsoleColors
local PCE = nuvs.PrettyConsoleErrors

local function booleanArg(argVal, argName)
    if (argVal == "true") then
        return true
    elseif (argVal == "false") then
        return false
    else
        PCE.output(out["invalid" .. argName])
    end
end
if #arg < 8 then PCE.output(out.invalidArguments) end
local info = booleanArg(arg[1], "InfoBool")
local filePath = arg[2]
local sortTolerance = tonumber(arg[3])
local sortBy = arg[4]
local rowChunking = 100 / tonumber(arg[5])
local colChunking = 100 / tonumber(arg[6])
local seamInvert = booleanArg(arg[7], "SeamInvert")
local sortDirection = tonumber(arg[8])
local pixels, width, height, bpp, fileSize = nuvs.BMP.decodeBMP(filePath)

local function writeFile(outputFileName, newPixels, width, height, info)
    nuvs.BMP.writeBMP("results/" .. outputFileName, newPixels, width, height, 24)
    os.execute("ffmpeg -i results/" ..
    outputFileName .. " -compression_level 100 results/" .. string.sub(outputFileName, 1, -4) .. "png -y -loglevel quiet")
    print("\n" ..
        c.white ..
        "> Successfully wrote file:" .. c.reset .. "\n" .. c.green .. "Name: " .. c.white .. outputFileName .. "\n")
    if info == true then
        print(out.fileInformation(filePath, sortTolerance, sortBy, rowChunking, colChunking, seamInvert, sortDirection, width, height, bpp, fileSize))
    end
end

local function pixelSort(info, sortTolerance, sortBy, rowChunking, colChunking, seamInvert, sortDirection)
    local newPixels = {}
    local lineLength = (sortDirection == 0) and width or height
    local rowChunkPCT = math.floor((rowChunking / 100) * lineLength) -- lineLength / rowChunking
    local colChunkPCT = math.floor((colChunking / 100) * lineLength) -- lineLength / colChunking
    local function sortIndex(sortByStr)
        if sortByStr == "red" or "r" then
            return 1 -- Red
        elseif sortByStr == "green" or "gre" or "g" then
            return 2 -- Green
        elseif sortByStr == "blue" or "blu" or "b" then
            return 3 -- Blue
        elseif sortByStr == "alpha" or "alp" or "a" then
            return 4 -- Alpha
        elseif sortByStr == "lum" or "s" or "l" then
            return 5 -- Luminance
        elseif sortByStr == "hue" or "h" then
            return 6 -- Hue
        else
            PCE.output(out.invalidSortBy)
        end
    end
    local function tComparator(sortingTable, sortIn, sortTolerance, ascending)
        table.sort(sortingTable, function(a, b)
            local diff = math.abs(a[sortIn] - b[sortIn])
            if diff < sortTolerance then
                return a[7] < b[7]
            end
            if ascending then
                return a[sortIn] < b[sortIn]
            else
                return a[sortIn] > b[sortIn]
            end
        end)
    end
    local function sortRows()
        for y = 1, height do
            local newRowPixels = {}
            for x = 1, width do
                local r, g, b, a = table.unpack(pixels[y][x])
                newRowPixels[x] = { r, g, b, a, nuvs.Color.luminance255(r, g, b), nuvs.Color.RGBtoHue(r, g, b), x }
            end
            local sortedRowPixels = {}
            local direction = 1
            if #newRowPixels > rowChunkPCT then
                local sortedChunk = {}
                for _, pixel in ipairs(newRowPixels) do
                    table.insert(sortedChunk, pixel)
                    if #sortedChunk == rowChunkPCT then
                        if seamInvert then
                            tComparator(sortedChunk, sortIndex(sortBy), sortTolerance, direction == 1)
                            direction = -direction
                        else
                            tComparator(sortedChunk, sortIndex(sortBy), sortTolerance, true)
                        end
                        for _, px in ipairs(sortedChunk) do table.insert(sortedRowPixels, px) end
                        sortedChunk = {}
                    end
                end
                if #sortedChunk > 0 then
                    tComparator(sortedChunk, sortIndex(sortBy), sortTolerance, true)
                    for _, px in ipairs(sortedChunk) do table.insert(sortedRowPixels, px) end
                end
            else
                if seamInvert then
                    tComparator(newRowPixels, sortIndex(sortBy), sortTolerance, false)
                else
                    tComparator(newRowPixels, sortIndex(sortBy), sortTolerance, true)
                end
                for _, px in ipairs(newRowPixels) do table.insert(sortedRowPixels, px) end
            end
            newPixels[y] = sortedRowPixels
        end
    end
    local function sortColumns()
        for x = 1, width do
            local newColPixels = {}
            for y = 1, height do
                local r, g, b, a = table.unpack(pixels[y][x])
                newColPixels[y] = { r, g, b, a, nuvs.Color.luminance255(r, g, b), nuvs.Color.RGBtoHue(r, g, b), y }
            end
            local sortedColPixels = {}
            local direction = 1
            if #newColPixels > colChunkPCT then
                local sortedChunk = {}
                for _, pixel in ipairs(newColPixels) do
                    table.insert(sortedChunk, pixel)
                    if #sortedChunk == colChunkPCT then
                        if seamInvert then
                            tComparator(sortedChunk, sortIndex(sortBy), sortTolerance, direction == 1)
                            direction = -direction
                        else
                            tComparator(sortedChunk, sortIndex(sortBy), sortTolerance, true)
                        end
                        for _, px in ipairs(sortedChunk) do table.insert(sortedColPixels, px) end
                        sortedChunk = {}
                    end
                end
                if #sortedChunk > 0 then
                    tComparator(sortedChunk, sortIndex(sortBy), sortTolerance, true)
                    for _, px in ipairs(sortedChunk) do table.insert(sortedColPixels, px) end
                end
            else
                if seamInvert then
                    tComparator(newColPixels, sortIndex(sortBy), sortTolerance, false)
                else
                    tComparator(newColPixels, sortIndex(sortBy), sortTolerance, true)
                end
                for _, px in ipairs(newColPixels) do table.insert(sortedColPixels, px) end
            end
            for y = 1, height do
                newPixels[y] = newPixels[y] or {}
                newPixels[y][x] = sortedColPixels[y]
            end
        end
    end
    local function sortBoth()
        sortRows()
        local tempPixels = newPixels
        newPixels = {}
        pixels = tempPixels
        sortColumns()
    end
    if sortDirection == 0 then
        sortRows()
    elseif sortDirection == 1 then
        sortColumns()
    elseif sortDirection == 2 then
        sortBoth()
    else
        PCE.output(out.invalidSortDirection)
    end
    local outputFileName = nuvs.fileToName(filePath) .. "_re.bmp"
    writeFile(outputFileName, newPixels, width, height, info)
end
pixelSort(info, sortTolerance, sortBy, rowChunking, colChunking, seamInvert, sortDirection)
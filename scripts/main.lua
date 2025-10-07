--package.cpath = package.cpath .. ";./modules/?.dll"
local nuvs = require("modules.NuvsModules")
--local sort = require("sort")
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
local pixels, width, height, bpp, fileSize = nuvs.BMP.decodeBMP(filePath)
local sortTolerance = tonumber(arg[3])
local sortBy = arg[4]
local rowChunks = math.max(1, math.floor(width  / math.max(1, tonumber(arg[5]))))
local colChunks = math.max(1, math.floor(height / math.max(1, tonumber(arg[6]))))
local seamInvert = booleanArg(arg[7], "SeamInvert")
local sortDirection = tonumber(arg[8])

local function writeFile(outputFileName, newPixels, width, height, info)
    nuvs.BMP.writeBMP("results/"..outputFileName, newPixels, width, height, 24)
    os.execute("ffmpeg -i results/"..outputFileName.." -compression_level 100 results/"..string.sub(outputFileName, 1, -4).."png -y -loglevel quiet")
    print("\n"..c.white.."> Successfully wrote file:"..c.reset.."\n"..c.green .."Name: "..c.white..outputFileName.."\n")
    if info == true then
        print(out.fileInformation(filePath, sortTolerance, sortBy, arg[5], arg[6], seamInvert, sortDirection, width, height, bpp, fileSize))
        nuvs.BMP.AlgorithmInformation(
        nuvs.fileToName(filePath),
        out.fileInformationTxt(filePath, sortTolerance, sortBy, arg[5], arg[6], seamInvert, sortDirection, width, height, bpp, fileSize)
        )
    end
end

local function sortIndex(sortByStr)
    if sortByStr == "red" or sortByStr == "r" then
        return 1     -- Red
    elseif sortByStr == "green" or sortByStr == "gre" or sortByStr == "g" then
        return 2     -- Green
    elseif sortByStr == "blue" or sortByStr == "blu" or sortByStr == "b" then
        return 3     -- Blue
    elseif sortByStr == "alpha" or sortByStr == "alp" or sortByStr == "a" then
        return 4     -- Alpha
    elseif sortByStr == "lum" or sortByStr == "s" or sortByStr == "l" then
        return 5     -- Luminance
    elseif sortByStr == "hue" or sortByStr == "h" then
        return 6     -- Hue
    else
        PCE.output(out.invalidSortBy)
    end
end

local function pixelSort(fInfo, fSortTolerance, fSortBy, fRowChunks, fColChunks, fSeamInvert, fSortDirection)

    local newPixels = {}

    local function tComparator(sortingTable, sortIn, Tolerance, ascending)
        table.sort(sortingTable, function(a, b)
            local diff = math.abs(a[sortIn] - b[sortIn])
            if diff < Tolerance then
                return a[7] < b[7]
            end
            if ascending then
                return a[sortIn] < b[sortIn]
            else
                return a[sortIn] > b[sortIn]
            end
        end)
    end

    local function chooseAxis(way)
        if way == 0 then
            return height, width, fRowChunks
        elseif way == 1 then
            return width, height, fColChunks
        end
    end

    local function sortAxis(way)
        local axisA, axisB, axisChunks = chooseAxis(way)
        for y = 1, axisA do
            local newAxisPixels = {}
            for x = 1, axisB do
                local r, g, b, a
                if way == 0 then
                    r, g, b, a = table.unpack(pixels[y][x])
                else
                    r, g, b, a = table.unpack(pixels[x][y])
                end
                newAxisPixels[x] = { r, g, b, a, nuvs.Color.luminance255(r, g, b), nuvs.Color.RGBtoHue(r, g, b), x }
            end
            local sortedPixels = {}
            local direction = 1
            if #newAxisPixels > axisChunks then
                local sortedChunk = {}
                for _, pixel in ipairs(newAxisPixels) do
                    table.insert(sortedChunk, pixel)
                    if #sortedChunk == axisChunks then
                        if fSeamInvert then
                            tComparator(sortedChunk, sortIndex(fSortBy), fSortTolerance, true)
                            direction = -direction
                        else
                            tComparator(sortedChunk, sortIndex(fSortBy), fSortTolerance, true)
                        end
                        for _, px in ipairs(sortedChunk) do table.insert(sortedPixels, px) end
                        sortedChunk = {}
                    end
                end
                if #sortedChunk > 0 then
                    tComparator(sortedChunk, sortIndex(fSortBy), fSortTolerance, true)
                    for _, px in ipairs(sortedChunk) do table.insert(sortedPixels, px) end
                end
            else
                if fSeamInvert then
                    tComparator(newAxisPixels, sortIndex(fSortBy), fSortTolerance, false)
                else
                    tComparator(newAxisPixels, sortIndex(fSortBy), fSortTolerance, true)
                end
                for _, px in ipairs(newAxisPixels) do table.insert(sortedPixels, px) end
            end
            if way == 0 then
                newPixels[y] = sortedPixels
            else
                for x = 1, axisB do
                    newPixels[x] = newPixels[x] or {}
                    newPixels[x][y] = sortedPixels[x]
                end
            end
        end
    end

    if fSortDirection == 0 or fSortDirection == 1 then
        sortAxis(fSortDirection)
    elseif fSortDirection == 2 then
        sortAxis(0)
        local tempPixels = newPixels
        newPixels = {}
        pixels = tempPixels
        sortAxis(1)
    else
        PCE.output(out.invalidSortDirection)
    end
    local outputFileName = nuvs.fileToName(filePath) .. "_re.bmp"
    writeFile(outputFileName, newPixels, width, height, fInfo)
end
pixelSort(info, sortTolerance, sortBy, rowChunks, colChunks, seamInvert, sortDirection)
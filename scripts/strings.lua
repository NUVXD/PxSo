local nuvs = require("modules.nuvs")
local PCE = nuvs.PrettyConsoleErrors
local c = nuvs.ConsoleColors
local strings = {}

strings.invalidInfoBool = { {
    "%sError: %sinfo argument must be 'true' or 'false'%s",
    { c.red, c.white, c.reset }
} }
strings.invalidArguments = { {
    "%sWarning: %sYour command must have at least 7 arguments%s",
    { c.green, c.white, c.reset }
}, {
    "%sUsage: %slua main.lua %s<info: true/false> <input file> <sort tolerance> <sort by> <#row chunks> <#col chunks> <seam invert: true/false> <sort direction>%s",
    { c.green, c.reset, c.grey, c.reset }
} }
strings.invalidSeamInvert = { {
    "%sError: %sseamInvert argument must be 'true' or 'false'%s",
    { c.red, c.white, c.reset }
} }
strings.invalidSortBy = { {
    "%sError: %ssortBy argument must be one of the following: red, green, blue, alpha, lum, hue%s",
    { c.red, c.white, c.reset }
} }
strings.invalidSortDirection = { {
    "%sError: %ssortDirection argument must be %s0%s (rows), %s1%s (columns), or %s2%s (both)%s",
    { c.red, c.white, c.green, c.white, c.green, c.white, c.green, c.white, c.reset }
} }
strings.invalidFile = { {
    "%sError: %sThe specified file could not be found or is not a valid BMP file%s",
    { c.red, c.white, c.reset }
} }
----------------------------------
strings.fileInformation = function(filePath, sortTolerance, sortBy, rowChunks, colChunks, seamInvert,
                                      sortDirection, width, height, bpp, fileSize)
    return (
        c.white .. "> Information:\n"
        .. c.green .. "Input file: " .. c.white .. filePath .. c.reset .. "\n"
        .. c.green .. "sortTolerance: " .. c.white .. sortTolerance .. c.reset .. "\n"
        .. c.green .. "sortBy: " .. c.white .. sortBy .. c.reset .. "\n"
        .. c.green .. "rowChunks: " .. c.white .. rowChunks .. c.reset .. "\n"
        .. c.green .. "colChunks: " .. c.white .. colChunks .. c.reset .. "\n"
        .. c.green .. "seamInvert: " .. c.white .. tostring(seamInvert) .. c.reset .. "\n"
        .. c.green .. "sortDirection: " .. c.white .. sortDirection .. c.reset .. "\n"
        .. c.green .. "Image dimensions (WxH): " .. c.white .. width .. "x" .. height .. c.reset .. "\n"
        .. c.green .. "Bits per pixel: " .. c.white .. bpp .. c.reset .. "\n"
        .. c.green .. "File size: " .. c.white .. fileSize .. " bytes (" .. string.sub(tostring(fileSize / 1000000), 1, 4) .. "MB)" .. c.reset .. "\n"
    )
end
strings.fileInformationTxt = function(filePath, sortTolerance, sortBy, rowChunks, colChunks, seamInvert,
                                         sortDirection, width, height, bpp, fileSize)
    return (
        "> Information:\n"
        .. "Input file: " .. filePath .. "\n"
        .. "sortTolerance: " .. sortTolerance .. "\n"
        .. "sortBy: " .. sortBy .. "\n"
        .. "rowChunks: " .. rowChunks .. "\n"
        .. "colChunks: " .. colChunks .. "\n"
        .. "seamInvert: " .. tostring(seamInvert) .. "\n"
        .. "sortDirection: " .. sortDirection .. "\n"
        .. "Image dimensions (WxH): " .. width .. "x" .. height .. "\n"
        .. "Bits per pixel: " .. bpp .. "\n"
        .. "File size: " .. fileSize .. " bytes (" .. string.sub(tostring(fileSize / 1000000), 1, 4) .. "MB)" .. "\n"
    )
end
strings.sortIndex = function(sortByStr)
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
        PCE.output(strings.invalidSortBy)
    end
end

return strings

local nuvs = {}

nuvs.clamp = function(value, min, max) -- clamps a value between a min and a max
    if value < min then return min end
    if value > max then return max end
    return value
end

nuvs.randomise = function(value, interval) -- randomises a value by plus or minus an interval
    local newValue = value + (math.random(-interval, interval))
    return newValue
end

nuvs.randomiseClamped = function(value, interval, min, max) -- randomises a value by plus or minus an interval, clamped between a min and a max
    local newValue = value + (math.random(-interval, interval))
    return nuvs.clamp(newValue, min, max)
end

nuvs.fileToName = function(filePath) -- extracts the file name from a file path (without extension)
    local name = filePath:match("([^\\/]+)$") or filePath
    if name:find("%.") then
        return name:match("(.+)%.[^%.]+$") or name
    else
        return name
    end
end

nuvs.PrettyConsoleErrors = { -- pretty console errors
    output = function(lines)
        local toOutput
        for _, line in ipairs(lines) do
            local formattedLine = line[1]                 -- text string
            if formattedLine == lines[1][1] then          -- if first line
                formattedLine = "\n" .. formattedLine
            elseif formattedLine == lines[#lines][1] then -- if last line
                formattedLine = formattedLine .. "\n"
            end
            local colors = line[2] -- color codes
            toOutput = string.format(formattedLine, table.unpack(colors))
            print(toOutput)
        end
        os.exit(1)
    end
}

nuvs.ConsoleColors = { -- ANSI color codes for console output
    reset = "\27[0m",
    black = "\27[30m",
    bBlack = "\27[1;30m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    white = "\27[37m",
    grey = "\27[90m",
    brightRed = "\27[91m",
    brightGreen = "\27[92m",
    brightYellow = "\27[93m",
    brightBlue = "\27[94m",
    brightMagenta = "\27[95m",
    brightCyan = "\27[96m",
    brightWhite = "\27[97m",
}

nuvs.Color = {                       -- stuff regarding colors
    luminance255 = function(r, g, b) -- calculates the RGB-Luminance[0-255] of a pixel
        local function linearize(c)
            c = c / 255
            if c <= 0.04045 then
                return c / 12.92
            else
                return ((c + 0.055) / 1.055) ^ 2.4
            end
        end
        local R = linearize(r)
        local G = linearize(g)
        local B = linearize(b)
        local s = 0.2126 * R + 0.7152 * G + 0.0722 * B -- WCAG 2.0 formula
        return math.floor(s * 255 + 0.5)
    end,
    averageColor = function(r, g, b) -- calculates the average color of a pixel
        return math.floor((r + g + b) / 3 + 0.5)
    end,
    RGBtoHue = function(r, g, b)
        r, g, b = r / 255, g / 255, b / 255
        local max = math.max(r, g, b)
        local min = math.min(r, g, b)
        local h
        if max == min then
            h = 0
        elseif max == r then
            h = (60 * ((g - b) / (max - min)) + 360) % 360
        elseif max == g then
            h = (60 * ((b - r) / (max - min)) + 120) % 360
        elseif max == b then
            h = (60 * ((r - g) / (max - min)) + 240) % 360
        end
        return h
    end,
}

nuvs.Bit = {          -- functions for reading little-endian integers from byte strings
    u16 = function(s) -- reads a little-endian unsigned 16-bit integer from a string
        local b1, b2 = s:byte(1, 2)
        if not b1 or not b2 then
            error("u16: input string too short")
        end
        return b1 + b2 * 256
    end,
    u32 = function(s) -- reads a little-endian unsigned 32-bit integer from a string
        local b1, b2, b3, b4 = s:byte(1, 4)
        return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    end
}

nuvs.BMP = { -- functions for reading and writing BMP files
    decodeBMP = function(filePath)
        local f = assert(io.open(filePath, "rb"))
        local data = f:read("*all")
        f:close()
        assert(data:sub(1, 2) == "BM", "Not a BMP file")
        local fileSize    = nuvs.Bit.u32(data:sub(3, 6))
        local pixelOffset = nuvs.Bit.u32(data:sub(11, 14))
        local headerSize  = nuvs.Bit.u32(data:sub(15, 18))
        local width       = nuvs.Bit.u32(data:sub(19, 22))
        local height      = nuvs.Bit.u32(data:sub(23, 26))
        local planes      = nuvs.Bit.u16(data:sub(27, 28))
        local bpp         = nuvs.Bit.u16(data:sub(29, 30))
        local compression = nuvs.Bit.u32(data:sub(31, 34))
        assert(planes == 1, "Unsupported BMP: planes != 1")
        assert(compression == 0, "Unsupported BMP compression (only BI_RGB)")
        local absHeight     = math.abs(height)
        local absWidth      = math.abs(width)
        local rowSize       = math.floor((bpp * absWidth + 31) / 32) * 4
        local bytesPerPixel = bpp / 8
        local pixels        = {}
        -- read palette if 8-bit
        local palette       = {}
        if bpp == 8 then
            local paletteOffset = 54 -- standard offset for 8-bit BMPs
            local paletteEntries = (pixelOffset - paletteOffset) / 4
            for i = 0, paletteEntries - 1 do
                local pos = paletteOffset + i * 4 + 1
                local b, g, r = data:byte(pos, pos + 2)
                palette[i] = { r, g, b, 255 }
            end
        end
        -- helper for 16-bit 5-6-5 extraction
        local function extract565(val)
            local r = math.floor(val / 0x800)
            local g = math.floor((val % 0x800) / 0x20)
            local b = val % 0x20
            r = r * 255 / 31
            g = g * 255 / 63
            b = b * 255 / 31
            return r, g, b
        end
        for row = 0, absHeight - 1 do
            local y = (height > 0) and (absHeight - 1 - row) or row
            local rowStart = pixelOffset + row * rowSize
            local rowPixels = {}
            for x = 0, absWidth - 1 do
                local i = rowStart + x * bytesPerPixel + 1
                local r, g, b, a = 0, 0, 0, 255
                if bpp == 8 then
                    local idx = data:byte(i)
                    local c = palette[idx] or { 0, 0, 0, 255 }
                    r, g, b, a = c[1], c[2], c[3], c[4]
                elseif bpp == 16 then
                    local lo, hi = data:byte(i, i + 1)
                    local val = hi * 256 + lo
                    r, g, b = extract565(val)
                elseif bpp == 24 then
                    b, g, r = data:byte(i, i + 2)
                elseif bpp == 32 then
                    b, g, r, a = data:byte(i, i + 3)
                elseif bpp == 48 then
                    local b1, b2, g1, g2, r1, r2 = data:byte(i, i + 5)
                    b = (b2 * 256 + b1) / 257
                    g = (g2 * 256 + g1) / 257
                    r = (r2 * 256 + r1) / 257
                elseif bpp == 64 then
                    local b1, b2, g1, g2, r1, r2, a1, a2 = data:byte(i, i + 7)
                    b = (b2 * 256 + b1) / 257
                    g = (g2 * 256 + g1) / 257
                    r = (r2 * 256 + r1) / 257
                    a = (a2 * 256 + a1) / 257
                end
                rowPixels[x + 1] = { r, g, b, a }
            end
            pixels[y + 1] = rowPixels
        end
        return pixels, absWidth, absHeight, bpp, fileSize
    end,
    writeBMP = function(filename, pixels, width, height, bpp) -- writes a 24 or 32 bit BMP file from pixel data ( pixels[y][x] = {r,g,b,a} )
        local bytes_per_pixel = bpp / 8
        local row_size = math.floor((bytes_per_pixel * width + 3) / 4) * 4
        local image_size = row_size * height
        local file_size = 14 + 40 + image_size
        local pixel_offset = 54

        local f = assert(io.open(filename, "wb"))

        -- BITMAPFILEHEADER (14 bytes)
        f:write("BM")
        f:write(string.pack("<I4", file_size))    -- file size
        f:write(string.pack("<I2", 0))            -- reserved1
        f:write(string.pack("<I2", 0))            -- reserved2
        f:write(string.pack("<I4", pixel_offset)) -- pixel data offset

        -- BITMAPINFOHEADER (40 bytes)
        f:write(string.pack("<I4", 40))         -- header size
        f:write(string.pack("<i4", width))      -- image width
        f:write(string.pack("<i4", height))     -- positive = bottom-up
        f:write(string.pack("<I2", 1))          -- planes
        f:write(string.pack("<I2", bpp))        -- bits per pixel
        f:write(string.pack("<I4", 0))          -- compression (none)
        f:write(string.pack("<I4", image_size)) -- image size
        f:write(string.pack("<i4", 2835))       -- x pixels per meter (~72 DPI)
        f:write(string.pack("<i4", 2835))       -- y pixels per meter
        f:write(string.pack("<I4", 0))          -- colors used
        f:write(string.pack("<I4", 0))          -- important colors

        -- Pixel data
        local pad = row_size - width * bytes_per_pixel
        for row = height, 1, -1 do -- bottom to top
            local rowdata = {}
            for col = 1, width do
                local px = pixels[row][col]
                local r, g, b, a = px[1], px[2], px[3], px[4] or 255
                if bpp == 24 then
                    table.insert(rowdata, string.char(b, g, r))
                else -- 32-bit
                    table.insert(rowdata, string.char(b, g, r, a))
                end
            end
            if pad > 0 then
                table.insert(rowdata, string.rep("\0", pad))
            end
            f:write(table.concat(rowdata))
        end

        f:close()
    end,
    pixelData = function(filePath) -- outputs raw pixel data of BMP to a text file
        local pixels, width, height, bpp, fileSize = nuvs.BMP.decodeBMP(filePath)
        local yPix = 1
        local xPix = 1
        io.output("pixel_data.txt")
        io.write("Raw pixel data of the original input image:\n")
        while yPix <= height do
            if xPix <= width then
                local r, g, b, a = table.unpack(pixels[yPix][xPix])
                io.write(string.format("[%d][%d] = %d, %d, %d, %d\n", xPix, yPix, r, g, b, a))
                xPix = xPix + 1
            else
                yPix = yPix + 1
                xPix = 1
            end
        end
        print("Wrote pixel_data.txt")
    end,
    AlgorithmInformation = function(fileName, information)
        io.output("assets/results/"..fileName.."_re.txt")
        io.write(information)
    end
}

return nuvs
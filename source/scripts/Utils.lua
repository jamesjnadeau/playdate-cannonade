-- Utils.lua
-- Small math / drawing helpers shared across the game.

Utils = {}

local gfx <const> = playdate.graphics
local sqrt <const> = math.sqrt
local sin <const> = math.sin
local cos <const> = math.cos
local atan2 <const> = math.atan  -- Lua 5.4: math.atan(y, x) works like atan2
local pi <const> = math.pi

function Utils.clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- Wrap an angle (degrees) into [0, 360)
function Utils.wrapDeg(a)
	a = a % 360
	if a < 0 then a = a + 360 end
	return a
end

-- Shortest signed difference from a to b, in degrees, range (-180, 180].
function Utils.angleDiff(a, b)
	local d = (b - a) % 360
	if d > 180 then d = d - 360 end
	return d
end

function Utils.deg2rad(d) return d * pi / 180 end
function Utils.rad2deg(r) return r * 180 / pi end

function Utils.dist(x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	return sqrt(dx * dx + dy * dy)
end

function Utils.dist2(x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	return dx * dx + dy * dy
end

-- Angle (degrees) pointing from (x1,y1) toward (x2,y2). 0 = +x (east).
function Utils.angleTo(x1, y1, x2, y2)
	return Utils.rad2deg(atan2(y2 - y1, x2 - x1))
end

-- Unit vector for a heading in degrees.
function Utils.heading(deg)
	local r = Utils.deg2rad(deg)
	return cos(r), sin(r)
end

-- Draw a dashed/dotted line between two points (screen space).
function Utils.drawDottedLine(x1, y1, x2, y2, dash, gap)
	dash = dash or 4
	gap = gap or 4
	local dx, dy = x2 - x1, y2 - y1
	local len = sqrt(dx * dx + dy * dy)
	if len < 1 then return end
	local ux, uy = dx / len, dy / len
	local step = dash + gap
	local d = 0
	while d < len do
		local sx = x1 + ux * d
		local sy = y1 + uy * d
		local e = d + dash
		if e > len then e = len end
		local ex = x1 + ux * e
		local ey = y1 + uy * e
		gfx.drawLine(sx, sy, ex, ey)
		d = d + step
	end
end

return Utils

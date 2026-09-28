local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }

function Format.number(value: number): string
	local n = math.floor(value)
	if n < 1000 then
		return tostring(n)
	end
	local index = 1
	local scaled = n
	while scaled >= 1000 and index < #SUFFIXES do
		scaled /= 1000
		index += 1
	end
	local pattern = if scaled < 10 then "%.2f%s" elseif scaled < 100 then "%.1f%s" else "%.0f%s"
	return string.format(pattern, scaled, SUFFIXES[index])
end

function Format.rate(value: number): string
	if value < 10 and value % 1 ~= 0 then
		return string.format("%.1f", value)
	end
	return Format.number(value)
end

function Format.time(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return string.format("%dh %02dm", s // 3600, (s % 3600) // 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

return Format

local phoneResources = {
	"sound/chudmorse_phone/911_male.mp3",
	"sound/chudmorse_phone/911_female.mp3",
	"sound/chudmorse_phone/end_call.mp3",
	"sound/chudmorse_phone/warning.mp3",
	"materials/chudmorse_phone/fox_call_dark.png",
	"materials/chudmorse_phone/fox_call_alert.png"
}

for _, path in ipairs(phoneResources) do
	resource.AddFile(path)
end

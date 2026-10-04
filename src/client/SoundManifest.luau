--!strict
-- The one place to change game audio: swap an ID or a level here, never in the code that plays it.
-- Every ID is a free Creator Store asset from Roblox's own UI set ("Roblox_UI_*", "RBLX UI *")
-- or its licensed Pro Sound Effects / APM Music libraries. `source` is the exact store title.
-- Every non-empty ID was checked in Studio on 2026-10-03: Audio type, owner Roblox /
-- ProSoundEffects / APMOfficial, preload Success, nonzero length. None has had a human listening
-- pass yet. An empty `id` is a PLACEHOLDER: it plays nothing.
local Manifest = {}

export type Group = "UI" | "SFX" | "Reveal" | "Music"
export type Entry = {
	id: string, -- numeric asset ID, or "" (placeholder, silent)
	source: string,
	group: Group,
	volume: number,
	speed: number?, -- PlaybackSpeed (changes pitch and length together)
	pitch: number?, -- random +/- fraction added to speed, for sounds that repeat
	cooldown: number?, -- minimum seconds between two plays of this name (default 0.05)
	voices: number?, -- Sound instances allowed to overlap (default 1)
}
export type Cue = { id: string, source: string }
export type Track = {
	id: string, -- numeric asset ID, or "" (placeholder, silent)
	source: string,
	volume: number, -- the track's own level; the Music group sets the overall music mix
	looped: boolean?, -- default true
	fadeIn: number?, -- seconds
	fadeOut: number?, -- seconds, when another track takes over or music stops
}

-- Linear SoundGroup volumes. Master also carries the session mute (Settings > Sound).
Manifest.master = 0.8
Manifest.groups = { UI = 0.6, SFX = 0.8, Reveal = 1, Music = 0.3 } :: { [Group]: number }
-- One UI sound per gesture: a tap that also navigates plays only the first sound in this window.
Manifest.gap = { UI = 0.04 } :: { [Group]: number }

Manifest.sounds = {
	-- UI
	click = {
		id = "15675032796",
		source = "Roblox_UI_Small_Click",
		group = "UI",
		volume = 0.5,
		pitch = 0.04,
		voices = 2,
	},
	select = {
		id = "15675059323",
		source = "Roblox_UI_Bright_Click",
		group = "UI",
		volume = 0.4,
		pitch = 0.05,
		voices = 2,
	},
	tab = {
		id = "15675037413",
		source = "Roblox_UI_Paper_Swipe",
		group = "UI",
		volume = 0.45,
		pitch = 0.03,
		cooldown = 0.08,
	},
	open = {
		id = "15675055424",
		source = "Roblox_UI_Cute_Pop",
		group = "UI",
		volume = 0.5,
		cooldown = 0.1,
	},
	close = {
		id = "15675081158",
		source = "Roblox_UI_Cute_Goodbye",
		group = "UI",
		volume = 0.4,
		cooldown = 0.1,
	},
	denied = {
		id = "10066914500",
		source = "RBLX UI Back (SFX)",
		group = "UI",
		volume = 0.45,
		speed = 0.8,
		cooldown = 0.25,
	},
	error = {
		id = "15675062723",
		source = "Roblox_UI_Whistle_Low",
		group = "UI",
		volume = 0.4,
		cooldown = 0.5,
	},
	-- Coins
	collect = {
		id = "9113849910",
		source = "Coin Throws 4 (SFX)",
		group = "SFX",
		volume = 0.55,
		pitch = 0.05,
		cooldown = 0.15,
		voices = 2,
	},
	coinLand = {
		id = "9126075967",
		source = "Synth Sparkle Tone High Pitch Tone Burst Pin (SFX)",
		group = "SFX",
		volume = 0.18,
		speed = 1.2,
		pitch = 0.12,
		cooldown = 0.07,
		voices = 3,
	},
	-- Display and Shelves
	place = {
		id = "9120917813",
		source = "Wood Impacts Soft Impacts On Temple Blocks 6 (SFX)",
		group = "SFX",
		volume = 0.6,
		pitch = 0.05,
		cooldown = 0.1,
	},
	remove = {
		id = "9119669618",
		source = "Suction Pop 6 (SFX)",
		group = "SFX",
		volume = 0.5,
		pitch = 0.05,
		cooldown = 0.1,
	},
	unlock = {
		id = "10066947742",
		source = "RBLX UI Purchase (SFX)",
		group = "SFX",
		volume = 0.6,
		cooldown = 0.3,
	},
	complete = {
		id = "9048764102",
		source = "Magical Meetup - Tag1 (APM Music)",
		group = "Reveal",
		volume = 0.55,
		cooldown = 2,
	},
	-- Daily goal and Open 10
	goalReady = {
		id = "9126073318",
		source = "Synth Sparkle Tone High Pitch Bell Tone Ding (SFX)",
		group = "SFX",
		volume = 0.45,
		cooldown = 1,
	},
	claim = {
		id = "15675043410",
		source = "Roblox_UI_Tonal_Stinger",
		group = "SFX",
		volume = 0.6,
		cooldown = 0.5,
	},
	results = {
		id = "9116394756",
		source = "Magic Glows Soft Clusters Of Chiming Hits 3 (SFX)",
		group = "Reveal",
		volume = 0.5,
		cooldown = 1,
	},
} :: { [string]: Entry }

-- Box opening: IDs for the opening cinematic's own cue slots (OpeningAudioConfig keys), which
-- keeps their timing, mix and rarity ladder. Slots not listed here stay silent.
Manifest.opening = {
	entrance = { id = "15675012262", source = "Roblox_UI_Whoosh_04" },
	shake = { id = "9113564057", source = "Box Grab Department Store Type 31 (SFX)" },
	click = { id = "15675059323", source = "Roblox_UI_Bright_Click" },
	crack = { id = "9117624959", source = "Plastic Sheet Impacts Rips Paper Tears 6 (SFX)" },
	lid = { id = "9119669295", source = "Suction Pop 2 (SFX)" },
	impact = { id = "9120917438", source = "Wood Impacts Soft Impacts On Temple Blocks 1 (SFX)" },
	rarityLegendary = {
		id = "9116395089",
		source = "Magic Glows Soft Clusters Of Chiming Hits 4 (SFX)",
	},
	rarityMythical = {
		id = "9125635442",
		source = "Magical Exit Sparkling Pass Bys Clinking Chi (SFX)",
	},
	revealCommon = {
		id = "9126076030",
		source = "Synth Sparkle Tone High Pitch Tone Burst Pin (SFX)",
	},
	revealUncommon = {
		id = "9126073001",
		source = "Synth Sparkle Tone High Pitch Bell Tone Ding (SFX)",
	},
	revealRare = { id = "9116394876", source = "Magic Glows Soft Clusters Of Chiming Hits 2 (SFX)" },
	revealLegendary = { id = "9048764475", source = "Magical Meetup - Hit2 (APM Music)" },
	revealMythical = { id = "9048764286", source = "Magical Meetup - Tag2 (APM Music)" },
	discovery = {
		id = "9125644310",
		source = "Magic Twirling Small High Pitch Spinning Chi (SFX)",
	},
} :: { [string]: Cue }

-- Background music, keyed by area or context. Only "world" exists today. Area or special-event
-- music later is one more entry here plus a `Music.play(name)` call where that context starts.
-- Checked in Studio on 2026-10-03 (Audio, owner Roblox, preload Success, 95.5 s) and measured
-- across its loop point with Looped = true: the level stays continuous through the wrap (no
-- silent gap). Not yet listened to. Effective level = volume x Music group x Master (~0.19).
-- Backups (APM Music, verified to load, all end in about 1.5-2 s of silence, so they gap when
-- looped as-is; a LoopRegion would need a listening pass to pick bar-aligned points):
--   9046598930 "Watching the Garden Grow (a)" 163 s
--   9046598509 "Tiny Twinkle Toes (a)" 141 s
--   1848268110 "Whimsical Reverie - Alt3, NoDrums" 132 s (ukulele and sparkling bells)
--   9047880640 "Morning Spirit (Underscore)" 106 s
Manifest.music = {
	world = {
		id = "15675069601",
		source = "Roblox_UI_Loop_Calm_Music",
		volume = 0.8,
		fadeIn = 3,
		fadeOut = 1.5,
	},
} :: { [string]: Track }

return Manifest

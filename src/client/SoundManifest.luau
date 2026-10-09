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
-- loudness: mean PlaybackLoudness at Volume 1, measured in Studio. A signal proxy, not a listening
-- result; it lets a test keep the rarity ladder climbing when an ID or a gain changes.
export type Cue = { id: string, source: string, loudness: number? }
export type Track = {
	id: string, -- numeric asset ID, or "" (placeholder, silent)
	source: string,
	volume: number, -- the track's own level; the Music group sets the overall music mix
	looped: boolean?, -- default true
	loopEnd: number?, -- seconds; loop back to 0 here instead of at the file's end
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
	-- Rarity identity, mid-flight as the box's energy changes color: every tier gets one, so
	-- Common and Uncommon flights are never silent. Glassy ding < bell burst < chime cluster.
	rarityCommon = {
		id = "9126073953",
		source = "Synth Sparkle Tone High Pitch Tone Burst Din (SFX)",
		loudness = 33,
	},
	rarityUncommon = {
		id = "9126071458",
		source = "Synth Sparkle Tone High Pitch Bell Tone Burs (SFX)",
		loudness = 19,
	},
	rarityRare = {
		id = "9116395179",
		source = "Magic Glows Soft Clusters Of Chiming Hits 6 (SFX)",
		loudness = 6,
	},
	rarityLegendary = {
		id = "9116395089",
		source = "Magic Glows Soft Clusters Of Chiming Hits 4 (SFX)",
		loudness = 7,
	},
	rarityMythical = {
		id = "9125635442",
		source = "Magical Exit Sparkling Pass Bys Clinking Chi (SFX)",
		loudness = 36,
	},
	revealCommon = {
		id = "9126076030",
		source = "Synth Sparkle Tone High Pitch Tone Burst Pin (SFX)",
		loudness = 13,
	},
	revealUncommon = {
		id = "9126073001",
		source = "Synth Sparkle Tone High Pitch Bell Tone Ding (SFX)",
		loudness = 11,
	},
	revealRare = {
		id = "9116394876",
		source = "Magic Glows Soft Clusters Of Chiming Hits 2 (SFX)",
		loudness = 12,
	},
	revealLegendary = {
		id = "9048764475",
		source = "Magical Meetup - Hit2 (APM Music)",
		loudness = 40,
	},
	revealMythical = {
		id = "9048764286",
		source = "Magical Meetup - Tag2 (APM Music)",
		loudness = 47,
	},
	discovery = {
		id = "9125644310",
		source = "Magic Twirling Small High Pitch Spinning Chi (SFX)",
	},
} :: { [string]: Cue }

-- Background music, keyed by area or context. Only "world" exists today. Area or special-event
-- music later is one more entry here plus a `Music.play(name)` call where that context starts.
-- Library cues end in a few seconds of silence, so `loopEnd` (measured in Studio where the final
-- note has decayed) loops back to the start before that silence. Checked 2026-10-04: Audio,
-- owner APMOfficial, preload Success; a LoopRegion wrap at loopEnd measured with no silent gap.
-- Not yet listened to. Effective level = volume x Music group x player Music setting x Master.
-- Other verified "Bouncing Mallets"/sunshine-pop picks, with their measured loop ends:
--   9042946821 "Let It Shine" (sun-drenched bouncy marimba + vibraphone), loopEnd 143.3
--   9042947041 "Happy Whistle" (mallets, whistling, laid-back groove), loopEnd 101.0
--   9038721033 "Easy Island" (ukulele, marimba, celesta, gentle ska beat), loopEnd 135.2
--   9042948177 "Summer Breakfast (Light version)", loopEnd 107.6
--   15675069601 "Roblox_UI_Loop_Calm_Music" (the first pick; a true loop, no loopEnd needed)
-- Background music pauses for a box opening: fade out this fast, then pause; fade back in this
-- slowly when it resumes from the same spot. Seconds.
Manifest.suppress = { fadeOut = 0.3, fadeIn = 1.2 }
Manifest.music = {
	world = {
		-- "Light, tropical and laid-back pop melody, marimba, piano, pizzicati, drums played
		-- with brushes and handclaps." (APM Music, Stereoscopic: Bouncing Mallets)
		id = "9042946814",
		source = "Summer Breakfast (APM Music)",
		volume = 0.8,
		loopEnd = 107.8,
		fadeIn = 3,
		fadeOut = 1.5,
	},
} :: { [string]: Track }

return Manifest

"""Original Blindbox 'Porcelain & Starlight' sound pack. Python standard library only.

No samples, downloads, plugins, models, instruments or third-party recordings are used.
Deterministic modal synthesis, filtered noise, periodic additive beds and short room taps.
Run: python tools/audio/build.py
"""
from __future__ import annotations

from array import array
import hashlib
import json
import math
from pathlib import Path
import random
import re
import sys
import wave

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio/opening"
RATE = 48000
TAU = 2 * math.pi
ROOT_NOTE = 293.664768  # D4: common harmonic vocabulary, not a borrowed melody.


def snake(key: str) -> str:
    return re.sub(r"(?<!^)([A-Z])", r"_\1", key).lower()


class Sound:
    def __init__(self, key: str, duration: float, loop=False):
        self.key, self.loop = key, loop
        self.n = round(duration * RATE)
        self.duration = self.n / RATE
        self.l, self.r = array("d", [0]) * self.n, array("d", [0]) * self.n
        self.rng = random.Random(int.from_bytes(hashlib.sha256(key.encode()).digest()[:8], "big"))

    def modal(self, frequency, level=1, decay=0.15, attack=0.0015, start=0,
              length=None, pan=0, ratios=(1, 2.01, 3.98), brightness=0.3, glide=0):
        """Damped physical-mode family, with faster decay in brighter modes."""
        first = round(start * RATE)
        count = min(self.n - first, round((length or self.duration) * RATE))
        for j, ratio in enumerate(ratios):
            f = frequency * ratio
            if f > 6500:
                continue
            weight = level * (brightness ** j)
            tau = max(0.008, decay / (1 + j * 0.65))
            angle = (pan + 1) * math.pi / 4
            left, right = math.cos(angle), math.sin(angle)
            phase = 0.0
            for i in range(count):
                t = i / RATE
                # Frequency relaxation adds a tactile elastic body instead of a pure beep.
                phase += TAU * (f + glide * math.exp(-t / 0.018)) / RATE
                env = (1 - math.exp(-t / attack)) * math.exp(-t / tau)
                value = math.sin(phase) * env * weight
                self.l[first+i] += value * left
                self.r[first+i] += value * right

    def air(self, level=0.3, low=300, high=2500, start=0, length=None,
            attack=0.015, decay=0.09, rising=False, pan=0):
        first = round(start * RATE)
        count = min(self.n-first, round((length or self.duration) * RATE))
        a = 1-math.exp(-TAU * high / RATE)
        b = 1-math.exp(-TAU * low / RATE)
        fast = slow = 0.0
        left, right = math.cos((pan+1)*math.pi/4), math.sin((pan+1)*math.pi/4)
        for i in range(count):
            t = i / RATE
            white = self.rng.uniform(-1, 1)
            fast += a * (white-fast)
            slow += b * (white-slow)
            env = (1-math.exp(-t/attack)) * math.exp(-t/decay)
            if rising:
                env *= (i / max(1, count-1)) ** 0.7
            value = (fast-slow) * level * env * 4
            self.l[first+i] += value*left
            self.r[first+i] += value*right

    def wash(self, frequencies, level=0.35, attack=0.06, pan=0.13, spectral=False):
        """Soft inharmonic bowed-glass swell; subtle side motion, mono carries all notes."""
        for j, f in enumerate(frequencies):
            phase = 0
            side = (-1 if j % 2 else 1) * pan
            left, right = math.cos((side+1)*math.pi/4), math.sin((side+1)*math.pi/4)
            for i in range(self.n):
                t = i/RATE
                p = t/self.duration
                # Unequal partial attacks create an opening of color rather than a volume jump.
                attack_j = attack * (1 + j*0.23)
                env = (1-math.exp(-t/attack_j)) * (1-p)**(1.5 if spectral else 2.4)
                movement = 1 + 0.0008 * math.sin(TAU*(1.1+j*0.13)*t+j)
                phase += TAU*f*movement/RATE
                value = math.sin(phase) * env * level / (1+j*0.65)
                self.l[i] += value*left
                self.r[i] += value*right

    def bed(self, frequencies, air_level=0.12, shimmer=False):
        """Exact integer-cycle tones and circularly filtered noise: seamless without dips."""
        for j, freq in enumerate(frequencies):
            cycles = round(freq*self.duration)
            phase = self.rng.random()*TAU
            left, right = math.cos(((-1)**j*0.16+1)*math.pi/4), math.sin(((-1)**j*0.16+1)*math.pi/4)
            for i in range(self.n):
                p = i/self.n
                breath = 0.88 + 0.12*math.sin(TAU*(1+j%2)*p + j)
                # Phase modulation is periodic; no end-point phase or amplitude reset.
                drift = (0.06 if shimmer else 0.025)*math.sin(TAU*2*p+j)
                value = math.sin(TAU*cycles*p+phase+drift)*breath*0.32/(1+j*0.9)
                self.l[i] += value*left
                self.r[i] += value*right
        noise = array("d", (self.rng.uniform(-1, 1) for _ in range(self.n)))
        fast = slow = 0.0
        a, b = 1-math.exp(-TAU*1900/RATE), 1-math.exp(-TAU*280/RATE)
        # Warm the IIR on the previous cycle; the final filter state matches its initial state.
        for value in noise[-RATE:]:
            fast += a*(value-fast)
            slow += b*(value-slow)
        for i, value in enumerate(noise):
            fast += a*(value-fast)
            slow += b*(value-slow)
            breeze = (fast-slow)*air_level*(0.92+0.08*math.sin(TAU*i/self.n))
            self.l[i] += breeze
            self.r[i] += breeze

    def room(self, amount=0.06):
        """A few early reflections, never a long masking algorithmic reverb."""
        for channel, offset in ((self.l, 0), (self.r, 0.0013)):
            dry = array("d", channel)
            for seconds, gain in ((0.011, 1), (0.023, 0.6), (0.037, 0.4), (0.053, 0.2)):
                delay = round((seconds+offset)*RATE)
                for i in range(delay, self.n):
                    channel[i] += dry[i-delay]*amount*gain

    def master(self, target_rms=0.16, peak_ceiling=0.68):
        # Remove DC, round the very strongest partial summations without clipping.
        for channel in (self.l, self.r):
            dc = sum(channel)/self.n
            for i in range(self.n):
                channel[i] = math.tanh((channel[i]-dc)*0.85)/0.85
        if not self.loop:
            attack, release = round(0.0006*RATE), min(round(0.012*RATE), self.n//5)
            for channel in (self.l, self.r):
                for i in range(attack):
                    channel[i] *= math.sin(i/attack*math.pi/2)**2
                for i in range(release):
                    channel[-1-i] *= math.sin(i/release*math.pi/2)**2
        rms = math.sqrt(sum(x*x for channel in (self.l,self.r) for x in channel)/(2*self.n))
        peak = max(max(abs(x) for x in self.l), max(abs(x) for x in self.r))
        gain = min(target_rms/max(1e-9,rms), peak_ceiling/max(1e-9,peak))
        for channel in (self.l,self.r):
            for i in range(self.n): channel[i] *= gain
        return self

    def save(self, directory=OUT):
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / (snake(self.key)+".wav")
        pcm = array("h")
        for left, right in zip(self.l, self.r):
            pcm.extend((round(left*32767), round(right*32767)))
        if sys.byteorder != "little": pcm.byteswap()
        with wave.open(str(path), "wb") as stream:
            stream.setparams((2, 2, RATE, self.n, "NONE", "not compressed"))
            stream.writeframes(pcm.tobytes())
        return path


def compose(key: str) -> Sound:
    d = ROOT_NOTE
    beds = {
        "ambience": (6, [d/2, d*1.5, d*2.5], 0.09),
        "ambienceGrove": (6, [d/2, d, d*1.5, d*2.5], 0.15),
        "ambienceTide": (6, [d/2, d*1.125, d*2, d*3], 0.1),
        "tension": (3, [d/2, d*1.002, d*1.5], 0.1),
        "charge": (2, [d/2, d, d*2.002, d*3], 0.24),
        "await": (4, [d/2, d, d*1.5], 0.06),
        "flight": (3, [d/2, d*1.5, d*2, d*3.002], 0.25),
        "flightAir": (2, [], 1),
        "flightMythical": (4, [d, d*1.4142, d*2, d*2.8284, d*4], 0.11),
        "dive": (1, [d/2, d, d*1.5], 0.7),
        "silhouette": (4, [d/2, d*1.5, d*2.002], 0.07),
        "silhouetteMythical": (4, [d/2, d*1.4142, d*2.8284], 0.065),
        "result": (6, [d/2, d*1.25, d*1.5, d*2], 0.065),
    }
    if key in beds:
        length, frequencies, air = beds[key]
        sound = Sound(key, length, True)
        sound.bed(frequencies, air, "Mythical" in key)
        return sound.master(0.13 if key in ("charge","flight","dive") else 0.095, 0.45)
    lengths = {
        "entrance": .36, "settle": .17, "shake": .095, "click": .065, "compression": .065,
        "crack": .145, "lid": .145, "launch": .275, "acceleration": .18,
        "rarityTransformation": .25, "transformLegendary": .145, "legendaryPulse": .32,
        "mythicalInward": .04, "mythicalPearl": .135, "transformMythical": .60,
        "postImpactShimmer": .43, "discovery": .24, "close": .09,
        "reveal": .60, "impact": .20,
    }
    tiers = ["Common","Uncommon","Rare","Legendary","Mythical"]
    for prefix, durations in [
        ("rarity", [.24,.38,.50,.52,.76]),
        ("impact", [.17,.19,.21,.23,.24]),
        ("reveal", [.34,.44,.58,.70,.76]),
    ]:
        lengths.update({prefix+tier:duration for tier,duration in zip(tiers,durations)})
    s = Sound(key, lengths[key])
    if key in ("entrance","lid","acceleration","launch","compression","mythicalInward"):
        s.air(0.75, 320 if key=="launch" else 550, 2700, attack=.006, decay=s.duration*.36,
              rising=key in ("compression","mythicalInward"))
        s.modal(d if key=="launch" else d*1.5, .32, s.duration*.25, ratios=(1,1.53,2.12),
                glide=-130 if key=="launch" else 70, brightness=.22)
        if key=="launch":
            s.modal(d/2, .6, .065, ratios=(1,2,3), glide=160, brightness=.25)
            s.wash([d*2,d*3], .11, .02)
    elif key in ("settle","shake","click","close","crack"):
        root = {"settle":330,"shake":640,"click":780,"close":660,"crack":510}[key]
        s.modal(root, .8, .019 if key in ("click","shake") else .038, ratios=(1,1.57,2.61), brightness=.35, glide=60)
        s.air(.50 if key=="crack" else .28, 750, 4400 if key=="crack" else 2300, attack=.0007, decay=.012)
        if key=="crack":
            s.modal(155,.8,.038,ratios=(1,2.6),brightness=.38,glide=170)
            s.modal(1750,.14,.026,start=.006,ratios=(1,1.414),brightness=.2)
        elif key=="settle":
            s.modal(180,.3,.035,ratios=(1,2),brightness=.2)
    elif key.startswith("impact"):
        tier = key.removeprefix("impact")
        idx = tiers.index(tier) if tier else 1
        s.modal(112+idx*7,1,.035,ratios=(1,2.03,3.07),brightness=.42,glide=160)
        s.air(.45, 400, 2600, attack=.001, decay=.018)
        s.modal(d*(2 if tier=="Mythical" else 1),.4,.045,ratios=(1,1.414,2.828) if tier=="Mythical" else (1,1.5,2.5),brightness=.40)
        if tier=="Legendary": s.modal(220,.35,.055,ratios=(1,2,3),brightness=.3)
    elif key in ("transformLegendary","legendaryPulse","rarityTransformation"):
        s.modal(d/2, .8,.042 if key=="transformLegendary" else .065,ratios=(1,2,3,4),brightness=.48,glide=40)
        s.air(.28,550,2400,attack=.002,decay=.025)
        s.modal(d*1.5 if key=="legendaryPulse" else d,.35,.10,ratios=(1,2.01,3.97),brightness=.2)
    elif key=="mythicalPearl":
        s.modal(d*3,.75,.043,attack=.002,ratios=(1,1.4142,2.8284),brightness=.23)
        s.modal(d*1.5,.18,.045,ratios=(1,),pan=-.1)
    elif key in ("transformMythical","rarityMythical","revealMythical"):
        if key=="transformMythical":
            s.wash([d/2,d,d*1.4142,d*2,d*2.8284],.7,.025,spectral=True)
            s.air(.10,600,2000,attack=.08,decay=.2)
        elif key=="rarityMythical":
            s.wash([d*2,d*2.8284,d*3,d*4,d*5.657],.38,.065,spectral=True)
            for f,at,pan in ((d*4,.015,-.18),(d*2.8284,.08,.18),(d*3,.16,0)):
                s.modal(f,.17,.13,start=at,ratios=(1,1.998),brightness=.14,pan=pan)
        else:
            s.wash([d,d*1.25,d*1.5,d*2.5,d*3.75],.55,.022,spectral=True)
            for f,at,pan in ((d*3,.003,-.18),(d*4,.063,.18),(d*5,.145,0)):
                s.modal(f,.19,.14,start=at,ratios=(1,1.4142),brightness=.16,pan=pan)
            s.modal(d/2,.27,.15,attack=.015,ratios=(1,2),brightness=.15)
        s.room(.11)
    elif key.startswith("rarity") or key.startswith("reveal"):
        reveal = key.startswith("reveal")
        tier = key.removeprefix("reveal" if reveal else "rarity") or "Rare"
        idx = tiers.index(tier)
        # Independently composed voicings/envelopes, not pitch variants of a single waveform.
        voicings = [(2,), (1.5,2,3), (1,1.5,2.5,3.75), (.5,1,1.5,2,3)]
        notes = voicings[idx]
        for j, ratio in enumerate(notes):
            s.modal(d*ratio, .75/(1+j*.7), (.12 if reveal else .085)*(1+idx*.3),
                    attack=.0025 if idx<2 else .004,
                    start=j*(.015 if reveal else .008),
                    ratios=(1,2.006,3.96,5.43) if idx<3 else (1,2,3,4),
                    brightness=.32 if idx<2 else .24, pan=(-1)**j*.12)
        if reveal:
            s.wash([d,d*1.25,d*1.5] if idx<3 else [d/2,d,d*1.5,d*2],.20,.025)
        elif idx>=2:
            s.wash([d*2,d*3,d*5],.12,.025)
        s.room(.05+idx*.012)
    elif key in ("postImpactShimmer","discovery"):
        if key=="discovery":
            for frequency,at in ((d*3,0),(d*4,.025)):
                s.modal(frequency,.4,.06,start=at,ratios=(1,2.01),brightness=.17,pan=.1)
        else:
            s.wash([d*2,d*3,d*4.01],.35,.035,spectral=True)
            s.air(.06,800,2400,attack=.025,decay=.11)
        s.room(.08)
    else:
        raise ValueError(key)
    rms = .17 if key.startswith(("rarity","reveal","transform","impact")) else .15
    if key in ("crack","launch","legendaryPulse"): rms = .20
    if key in ("postImpactShimmer","discovery"): rms = .12
    return s.master(rms, .68)


def keys() -> list[str]:
    text = (ROOT/"src/client/OpeningAudioConfig.luau").read_text(encoding="utf-8")
    result = set(re.findall(r'cue\("([^"]+)",', text))
    result.update(prefix+tier for tier in ("Common","Uncommon","Rare","Legendary","Mythical")
                  for prefix in ("rarity","impact","reveal"))
    return sorted(result)


def main():
    manifest = {"name":"Porcelain & Starlight", "version":1, "sampleRate":RATE,
                "provenance":"Original deterministic synthesis authored for nathanhuynhers/blindbox at the user's request. No third-party samples or melodies.",
                "generator":"tools/audio/build.py", "assets":{}}
    for key in keys():
        sound = compose(key)
        path = sound.save()
        manifest["assets"][key] = {"source":path.relative_to(ROOT).as_posix(),
            "key":"Audio.Opening."+key[0].upper()+key[1:], "assetType":"Audio",
            "displayName":"Blindbox "+re.sub(r"([A-Z])",r" \1",key).strip().title(),
            "duration":sound.duration,"looped":sound.loop,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
        print("Rendered", key, f"{sound.duration:.3f}s", "loop" if sound.loop else "shot", flush=True)
    (OUT/"pack.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    print("Created",len(manifest["assets"]),"original stereo PCM WAV assets.")


if __name__=="__main__":
    main()

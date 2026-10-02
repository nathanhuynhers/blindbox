"""Audit original masters and render ten previews through the production Luau mixer trace.

Run tests/run.py first; then python tools/audio/preview.py path/to/luau.exe.
These are offline PCM previews, not proof of native Roblox playback or transcoding quality.
"""
from array import array
import html
import json
import math
from pathlib import Path
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio/opening"
RATE = 48000
BLOCK = RATE // 240


def read(path):
    with wave.open(str(path), "rb") as stream:
        assert (stream.getnchannels(), stream.getsampwidth(), stream.getframerate()) == (2, 2, RATE)
        pcm = array("h", stream.readframes(stream.getnframes()))
        if sys.byteorder != "little":
            pcm.byteswap()
    return pcm


def metrics(pcm):
    peak = max(abs(x) for x in pcm) / 32768
    rms = math.sqrt(sum(x*x for x in pcm) / len(pcm)) / 32768
    mono = math.sqrt(sum(((pcm[i]+pcm[i+1]) / 2)**2 for i in range(0,len(pcm),2)) / (len(pcm)/2)) / 32768
    return {"peakDbFS": round(20*math.log10(max(peak,1e-10)),2),
            "rmsDbFS": round(20*math.log10(max(rms,1e-10)),2),
            "monoLossDb": round(20*math.log10(max(mono/rms,1e-10)),2),
            "dc": round(sum(pcm)/len(pcm)/32768,7)}


def main():
    pack = json.loads((OUT/"pack.json").read_text(encoding="utf-8"))
    sources = {key: read(ROOT/item["source"]) for key,item in pack["assets"].items()}
    report = {"method":"48 kHz PCM; production Luau mixer traced at 240 Hz; linear resampling. No Roblox playback tested.",
              "masters":{},"previews":{}}
    for key, pcm in sources.items():
        entry = metrics(pcm)
        assert entry["peakDbFS"] < -3, key+": headroom"
        assert entry["rmsDbFS"] > -40 and entry["monoLossDb"] > -1, key+": audible mono core"
        assert abs(entry["dc"]) < .003, key+": DC"
        if pack["assets"][key]["looped"]:
            delta = max(abs(pcm[0]-pcm[-2]),abs(pcm[1]-pcm[-1]))
            largest_step = max(abs(pcm[i]-pcm[i-2]) for i in range(2,len(pcm)))
            assert delta <= largest_step, key+": discontinuous loop seam"
            entry["seamStepRatio"] = round(delta/max(1,largest_step),3)
        else:
            assert pcm[0] == pcm[1] == pcm[-1] == pcm[-2] == 0, key+": endpoint click"
        report["masters"][key] = entry
    result = subprocess.run([sys.argv[1],str(ROOT/"tools/audio/trace.luau")],cwd=ROOT,capture_output=True,text=True,check=True)
    traces = {}
    frame = None
    for line in result.stdout.splitlines():
        fields = line.split(",")
        if fields[0] == "FRAME":
            _,name,number,phase = fields
            frame = {"frame":int(number),"phase":phase,"voices":[]}
            traces.setdefault(name,[]).append(frame)
        elif fields[0] == "VOICE":
            _,identifier,key,volume,speed = fields
            frame["voices"].append((int(identifier),key,float(volume),float(speed)))
    preview_dir = OUT/"previews"
    preview_dir.mkdir(exist_ok=True)
    cards = []
    for name,frames in traces.items():
        mixed = array("d",[0]) * (len(frames)*BLOCK*2)
        positions, prior = {}, {}
        for frame in frames:
            base = frame["frame"]*BLOCK*2
            for identifier,key,volume,speed in frame["voices"]:
                pcm = sources[key]
                length = len(pcm)//2
                looped = pack["assets"][key]["looped"]
                position = positions.get(identifier,0.)
                old = prior.get(identifier,volume)
                for i in range(BLOCK):
                    if position >= length:
                        if looped:
                            position %= length
                        else:
                            break
                    index = int(position)
                    fraction = position-index
                    following = (index+1)%length if looped else min(index+1,length-1)
                    level = old + (volume-old)*(i+1)/BLOCK
                    for channel in (0,1):
                        value = pcm[index*2+channel]*(1-fraction)+pcm[following*2+channel]*fraction
                        mixed[base+i*2+channel] += value*level
                    position += speed
                positions[identifier] = position
                prior[identifier] = volume
        peak = max(abs(x) for x in mixed)
        assert peak < 30000, name+": combined mix clipped"
        output = array("h",(round(x) for x in mixed))
        report["previews"][name] = {**metrics(output),"duration":round(len(frames)/240,3),
            "voices":len(positions),"maxConcurrent":max(len(frame["voices"]) for frame in frames)}
        if sys.byteorder != "little":
            output.byteswap()
        with wave.open(str(preview_dir/(name+".wav")),"wb") as stream:
            stream.setparams((2,2,RATE,0,"NONE","not compressed"))
            stream.writeframes(output.tobytes())
        title = name.replace("_"," ").title()
        cards.append(f'<article><h2>{title}</h2><audio controls preload="none" src="previews/{name}.wav"></audio></article>')
        print("Preview",name,report["previews"][name],flush=True)
    (OUT/"quality.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    cues = "".join(f'<article><h3>{html.escape(key)}</h3><audio controls preload="none" src="{Path(item["source"]).name}"></audio></article>' for key,item in pack["assets"].items())
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Porcelain &amp; Starlight</title>
<style>body{margin:40px auto;padding:0 24px;max-width:1040px;background:#101d28;color:#e5f0f0;font:16px/1.5 system-ui}h1{font-size:40px;color:#bfe4db}h2,h3{margin:0 0 14px;font-size:18px}p{max-width:760px;color:#b2c8ce}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}article{padding:22px;background:#1b303c;border-radius:16px}audio{width:100%}details{margin:40px 0}summary{cursor:pointer;margin-bottom:20px}</style>
<h1>Porcelain &amp; Starlight</h1><p>48 original sounds for Blindbox. Ceramic touches, warm air, and a rarity ladder from simple delight to spectral wonder.</p><p>Full openings follow the game's mix and timing, including a short wait for Tap to Open and a new-discovery accent. Compare at one comfortable volume. These previews precede Roblox's audio processing.</p><div class="grid">'''+"".join(cards)+'</div><details><summary>Explore all 48 source sounds</summary><div class="grid">'+cues+'</div></details></html>'
    (OUT/"listen.html").write_text(page,encoding="utf-8")
    print("PASS: all 48 masters and ten opening mixes checked; listen.html is ready.")


if __name__ == "__main__":
    main()

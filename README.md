# KRAFTY CONTENT ENGINE

Target: 500 initial clips, 2,500 monthly, £25 indicative infrastructure budget. Production is separate from publishing.

V0.1: local CLI for editing rights-cleared media using FFmpeg. No paid API calls or automatic posting. Source discovery and trend research are future modules. Never commit music, footage, credentials or private campaign data.

## Quick start
Install Python 3.11+ and FFmpeg (including ffprobe). Run `python engine.py --help`. Create a local JSON manifest containing an array of objects with `video`, `start`, and `rights_confirmed` fields. Rights confirmation must cover editing and intended commercial social use. Run `python engine.py manifest.json song.wav output --limit 20`. Smoke-test with your own footage first. Output is portrait MP4 for manual review. No claims of platform clearance or performance are made.

## Roadmap
- Music and scene analysis
- Official YouTube discovery API and permitted TikTok trend references
- Rights registry, content scoring and duplicate detection
- Persistent job queue, dashboard, cost accounting and tests
- Approved publishing integration and performance feedback

Do not expose the CLI or a future dashboard to the internet without authentication and deployment review. Do not deploy on the existing radio server before benchmarking.

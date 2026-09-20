# AI-Native SDLC — Artifact Chain Structure (ADC Hackathon 2026)

This is the full set of MD files used to run the AI-native SDLC for the competition. Each file is an "artifact" in the chain — each later file is generated based on the earlier ones, and every file can be continuously updated as discussions with Claude progress.

## Folder structure

```
project-root/
├── intent/
│   ├── 01-intent.md          ← start of the chain, includes Rubrics
│   ├── 02-spec.md            ← tech stack, design pattern, architecture
│   ├── 03-schema.md          ← data models
│   ├── 04-endpoints.md       ← API endpoints
│   ├── 05-scaffolder.md      ← initial codebase setup
│   ├── 06-plan.md            ← execution plan, split into parallel workstreams
│   ├── 07-frontend-generation.md  ← workflow using v0/stitch/figma
│   ├── 08-design.md          ← UI design system
│   ├── 09-taste.md           ← running log of aesthetic preferences, updated continuously
│   └── 10-accessibility-wcag.md   ← WCAG reminder skill, applied throughout
├── references/                ← screenshots of reference UI pages
└── theme/                     ← HTML extracted from v0/stitch/figma
```

## Run order (corrected for logical sequencing)

scaffolder.md (setting up the code skeleton) comes before plan.md (detailed execution plan), because the plan needs to know how the code is already organized in order to split work accurately.

1. intent.md
2. spec.md
3. schema.md
4. endpoints.md
5. scaffolder.md
6. plan.md
7. Frontend generation (v0/stitch/figma)
8. design.md
9. taste.md (runs in parallel, updated continuously from step 7 onward)
10. accessibility-wcag.md (applied throughout, starting from step 2 — not just at the end)

**Important note on WCAG:** even though it's listed as the last item, this skill should be loaded in as early as spec.md and design.md, not just checked at the end. Checking accessibility after the build is finished usually means reworking the architecture (e.g. missing focus management, missing semantic HTML from the start) — a cost you can't afford in a 3-day competition.

## Principle that applies throughout

Whenever a new idea comes up, always ask: **"Does this serve a rubric line in intent.md?"** If not, put it in Open Questions, not into the build.

---

## Files not yet created

- **ADC-HACKATHON-CHECKLIST.md** — a day-by-day checklist to use during the competition, referenced in the original planning document but not included in the content provided to generate this skeleton. Create this separately once you have it, or ask to have it drafted from the official agenda.
- **pitch.md** — not part of the original 10-file chain, but the WCAG file (10-accessibility-wcag.md) explicitly says the Day-3 pitch should trace every completed checklist item back to a Rubric line. Consider adding this as an 11th artifact once you're closer to Day 3.

---

## ⚠️ Tổng hợp: cần chuẩn bị / điền gì khi cuộc thi bắt đầu

*(Chi tiết theo từng file nằm ở cuối mỗi file trong `intent/`. Đây là bản tổng hợp nhanh.)*

- [ ] **Competition Brief** (release 9:00–10:00 sáng Day 1) — quyết định gần như toàn bộ nội dung của `01-intent.md` (Problem, Users, Outcome).
- [ ] **Disability Focus Area** được BTC assign cho team (không đổi được sau khi xác nhận).
- [ ] **Solution Category** — chọn 1 trong 3: Attitudinal & Communication / Architectural & Industrial / Technological (theo template slide 1).
- [ ] **Tên team, tên project.**
- [ ] Quyết định team size thực tế → có gộp `03-schema.md`/`04-endpoints.md` vào `02-spec.md` hay không.
- [ ] Làm rõ chú thích "hoặc xài cái architecture blueprint" trong bản gốc — quyết định có dùng thay thế cho `05-scaffolder.md` hay không.
- [ ] Điều chỉnh lại các checkpoint trong `06-plan.md` cho khớp với agenda thật (thời gian code thực tế chỉ có chiều Day 1 + Day 2 + vài giờ sáng Day 3 trước 7:00 AM).
- [ ] Chuẩn bị màu sắc/phong cách UI mong muốn trước khi vào bước `07-frontend-generation.md`.

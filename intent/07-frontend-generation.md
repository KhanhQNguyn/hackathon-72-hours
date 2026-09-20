# Frontend Generation Workflow (v0 / stitch / Figma) — [Product Name]

## Process

1. Paste intent.md and spec.md into the tool (v0/stitch/Figma AI).
2. List the pages needed for the project (e.g. login, register, dashboard, ...).
   _(để trống)_
3. Choose a color palette based on personal preference, paste it into the prompt.
   _(để trống)_
4. Choose a style (minimal / pixel / oldschool / ...).
   _(để trống)_
5. Explicitly ask the tool to meet a minimum contrast ratio of 4.5:1 for regular text (WCAG AA) — many AI UI-gen tools default to visually appealing but low-contrast color choices.
6. Screenshot all pages, save into the `/references` folder.
7. Extract the HTML and save each page separately into the `/theme` folder (faster and uses less tokens than having Claude re-read from screenshots).

## Notes

- If there isn't enough time for this step, it's fine to skip it and have Claude generate the UI directly from spec.md plus a short style description in design.md — accepting a less polished UI in exchange for speed.

## ⚠️ Cần điền khi cuộc thi bắt đầu

- [ ] Danh sách trang cụ thể (phụ thuộc vào Core Features trong intent.md).
- [ ] Bảng màu, phong cách UI muốn dùng.

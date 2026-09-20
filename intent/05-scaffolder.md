# scaffolder.md — [Product Name]

## Starter prompt

> "Based on intent.md, spec.md, schema.md, and endpoints.md, create a scaffolder.md file to set up the initial codebase for the project, organizing folders by architecture (e.g. client/server, app/client...). Then actually scaffold the corresponding folder/file structure."

## Example folder structure

```
project-root/
├── client/ (or app/)
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── hooks/
│   │   └── ...
├── server/
│   ├── src/
│   │   ├── routes/
│   │   ├── models/
│   │   ├── middleware/
│   │   └── ...
├── intent/          ← the artifact chain MD files
├── references/
├── theme/
└── README.md
```

## Scaffolding checklist

- [ ] Initialize package.json (or equivalent) for each layer
- [ ] Set up linting + formatting right away (so lint hooks run from the first commit)
- [ ] Set up a sample env file (.env.example)
- [ ] Set up basic CI if used (tests run automatically on push)
- [ ] Make sure the base HTML structure has `<html lang="...">` and landmark roles (`<main>`, `<nav>`, `<header>`) from the very first layout file — the foundation for WCAG compliance later

> ⚡ No need for many discussion rounds on this file — once plan.md exists in the next step, you can re-scaffold once more if the architecture changes.

## ⚠️ Cần điền khi cuộc thi bắt đầu

- [ ] Cần intent/spec/schema/endpoints đã có nội dung thật để scaffold đúng kiến trúc.
- [ ] Làm rõ chú thích gốc "hoặc xài cái architecture blueprint" — quyết định có dùng thay thế cho scaffolder.md truyền thống hay không (chưa có nội dung cụ thể về blueprint này trong tài liệu gốc, cần bổ sung nếu muốn dùng).

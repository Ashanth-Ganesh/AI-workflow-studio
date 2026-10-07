# Assignment 5 — Design D0

`D0_High_Level_Design.pdf` is the generated 14-page PDF. To export after editing, open `D0_High_Level_Design.html` in Chrome or Edge, then select **Print / Save as PDF**. Use Letter paper, Landscape, 100% scale, and turn off the browser's headers and footers. The document embeds its diagrams and styles, so it works offline as a single file.

The document contains all seven assignment sections, seven owned components, thirteen interface contracts, both access and workflow data flows, assigned owners, story mappings, pattern justification, and eight proposed decisions.

The `.drawio` files are editable in diagrams.net/draw.io. The `.svg` files are standalone vector exports. Titles, goals, and legends are included in each diagram. The Python script is the reproducible document/diagram source and uses only the standard library:

```powershell
.\.venv\Scripts\python.exe Design_Diagrams\build_d0.py
```

The generator is the canonical source: edit its content and geometry before rebuilding. Independent edits in draw.io are preserved in that file until a rebuild, but do not automatically update the HTML/SVG; export and replace the corresponding embedded SVG if editing diagrams independently.

The document maps all five stories in `User_stories.md` by their original titles. Because that file contains no IDs, US1–US5 are document reference labels assigned in source order. It sets no numeric timing requirements. Placeholder workflow CRUD is foundation scope; the full execution/node/provider design is a later target from `Docs/Project.md`.

The component table and its listed owners are accepted for D0. Review the design decisions and resolve the hosting discrepancy: the Azure story specifies API hosting on App Service, while `Docs/Project.md` proposes Container Apps. The document records both without claiming a hosting decision.

The assignment asks each team member to submit the complete PDF separately and asks the team to commit the document and diagram sources in this folder. Files are prepared locally; repository commits and Canvas submission are separate actions.

---
name: user-default-instructions
description: >-
  Sameer's default agent instructions: execution discipline, communication
  standards, code style, conversation reasoning, MCP/skills usage, HC2-UI
  workspace rules, site header (blue bar) partner links, and Reports conventions
  (same-origin API proxy, SheetJS + AG Grid Community, download-on-click only,
  fullscreen overlay after load, station/PEA parity). Apply for all tasks in
  this repository unless overridden.
---

# User default instructions (summary)

Use this skill as the baseline for how to work, write, and communicate in this project.

## Compliance and sources of truth

- Follow **user rules**, **tool/system descriptions**, **skills**, and **MCP server instructions** completely—not partially.
- When any of those sources specify a **format, workflow, naming convention, or step sequence**, follow it even if another approach seems better.
- Treat constraints in tool and MCP descriptions as **requirements**, not suggestions.
- When a listed **skill** is relevant, **read and follow it** rather than improvising.

## Execution and environment

- This is a **real environment** with shell and network access: **run commands and investigate** yourself; do not only tell the user what to run.
- Do **not** give up after a single failure—try alternatives, diagnose, and retry.
- The **Today's date** field in the session `user_info` block is **authoritative** (e.g. for “current” year in searches or answers—do not assume an older year).
- Prefer **absolute paths** as tool args when practical.

## MCP usage

- When an enabled MCP server matches the task, **inspect that MCP** (tools/resources) before answering—do not wait for an explicit “use MCP” request.
- **Always read** the tool’s schema/descriptor under the project `mcps/` folder **before** calling `call_mcp_tool`.

## Communication and markdown

- Use **code citation blocks** for existing code: opening fence on its **own line**, format `` `startLine:endLine:filepath` `` (only that citation style for file excerpts).
- Inside citations or backticks, show **literal** characters (no HTML entities for symbols).
- For **web or file URLs**, use full strings in markdown links; do not shorten paths or URLs.
- Aim for **clear, structured prose** (technical-blog quality): complete sentences, proportional length to task complexity.
- **Commit and PR descriptions**: complete sentences, good grammar, only relevant detail.
- Prefer **plain, accessible language** over jargon; explain what changed and **why** when it helps.
- Use **bold** and inline **backticks** sparingly (only where they add clarity).
- Avoid **§** in user-facing text (poor rendering in some UIs).
- Use **mermaid** or ASCII diagrams when they clarify non-trivial flows—not for trivial edits.
- Avoid generic **engagement closers** (“Say the word and I’ll…”). If a follow-up is useful, **ask directly** whether they want it.
- Mark **todo** items completed as work finishes; do not leave items `in_progress` when done.

## Conversation and intent

- Interpret each message in light of the **full thread**: refinements often **steer** the current task rather than cancel it.
- Infer **underlying goals**, constraints, and what “success” means—not only the literal last sentence.
- If a message could be a **refinement** vs a **new direction**, default to treating it as guidance for work in progress.

## Code and UI changes

- Change **only what the task requires**. No drive-by refactors, unrelated files, or scope creep; a small focused diff is better than a large mixed one.
- **Read surrounding code** before editing; match naming, types, patterns, imports, and documentation density—additions should read like the same author.
- **Reuse** existing helpers/components instead of duplicating similar logic.
- Prefer **one clear code path** over many special cases.
- Do **not** add noisy comments, obvious docstrings, extra variables, or heavy defensive try/catch unless justified.
- Do **not** remove unrelated comments or code “while you’re there.”
- For UI: **consistent** spacing, typography, color, and layout aligned with existing patterns.

## Markdown files

- Do **not** create or edit markdown documentation files unless the user asked for them (this skill file was an explicit exception).

## HC2-UI / Next.js workspace

- This repo’s **Next.js** may differ from generic training knowledge: consult **`node_modules/next/dist/docs/`** when writing Next.js code; heed deprecations.
- Project entry for agents: **`AGENTS.md`** / **`CLAUDE.md`** (follow those pointers).

### Site header: top blue bar (`Hc2Header`)

- **Component**: `src/components/Hc2Header.tsx` — the narrow **blue** strip (`#049cdb`) above the dark logo bar.
- **Left**: **`datafit.it`** as the label, hyperlink **`https://datafit.it/`** (spelling is **Datafit** / **datafit**, not “datafir”). Open in a new tab with `rel="noopener noreferrer"`.
- **Right**: **`Blackstraw.ai`** as the label, hyperlink **`https://blackstraw.ai/`**. Same external-link pattern.
- **Layout**: `justify-between` so left and right sit at opposite ends; keep styling consistent with the existing bar (uppercase tracking, white text, hover underline).
- **Do not** restore **phone numbers** (e.g. `tel:`) or **HC2 help contact** (e.g. `Help@HC2Broadcasting.com`) in this blue strip unless the user explicitly asks to bring them back.

### Reports: API proxy, downloads, fullscreen, Excel + AG Grid

- **Location**: `src/components/reports/ReportsWorkspace.tsx` — filters, fetch, parsing, embedded cards, and **`ReportFullscreenShell`**. Proxy route: **`src/app/api/reports/[kind]/route.ts`** (`station` → upstream **`/report/station`**, `pea` → **`/report/pea`**; paths from **`@/lib/api/paths`**).

#### Networking (CORS)

- The **browser must not** fetch report bytes directly from **`NEXT_PUBLIC_API_URL`** (cross-origin → typical **`Failed to fetch`** without CORS). **Always** use same-origin **`GET /api/reports/station?…`** and **`GET /api/reports/pea`** from the client—the proxy server-fetches the API and forwards status, body, **`Content-Type`**, and **`Content-Disposition`**. Same rationale as **`/api/maps/image`** for map images.

#### Downloads

- **Do not** auto-download when the user clicks **Load** (e.g. PEA Excel). Saving the file happens **only** when the user clicks **Download** (embedded toolbar strip and/or **`ReportFullscreenShell`** header). Use a reliable programmatic pattern (e.g. temporary **`<a download>`** + **`URL.createObjectURL`**) for blob downloads.

#### Fullscreen overlay

- On **successful** load (station or PEA), open the large **`ReportFullscreenShell`** overlay (**`fixed inset-0`**, body **`overflow: hidden`**, **Escape** closes). **Do not** add an **“Open full screen”** control on the cards unless the user asks. **Do not** add a browser **`requestFullscreen`** (“Full screen”) button in the overlay toolbar unless the user asks—toolbar stays **Download** (when applicable) + **Close**.

#### Excel detection and station/PEA parity

- **`parseBufferAsExcelOrPayload`** (SheetJS **`xlsx`**, dynamic import) is the **single** path for both **antenna (station)** and **PEA** after reading **`arrayBuffer`**. **`looksLikeExcel`** uses MIME + filename (`.xlsx` / `.xls`) and, when needed, **ZIP `PK` signature** sniff for **`application/octet-stream`** (or empty type) so mislabeled OOXML still parses. Parsing failures fall back to **`ReportPayload`** **`file`** mode. Keep **station** and **PEA** behavior **aligned** when changing detection or preview.

#### AG Grid preview

- **Display**: **AG Grid Community** (`ag-grid-community`, `ag-grid-react`). Register **`AllCommunityModule`** once with **`ModuleRegistry.registerModules([AllCommunityModule])`**. Do not introduce a second table implementation for the same data unless the user asks to replace AG Grid.
- **`ExcelWorkbookPreview`** (`variant="embedded"` | `"fullscreen"`) hosts worksheet tabs + **`AgGridReact`** — keep **embedded** and **fullscreen** variants working together when editing layout or theming.

#### Fullscreen (“expanded”) layout (flex + grid height)

- AG Grid with **`domLayout="normal"`** needs a **resolved height** through the flex stack. When editing fullscreen preview, validate **embedded and fullscreen**: use **`min-h-0`**, **`flex-1`**, and **`h-full`** on wrappers from **`ReportFullscreenShell`** content down to the grid container; give **`AgGridReact`** a **`className`** such as **`h-full min-h-0 w-full`** in fullscreen; keep **worksheet tabs** **`shrink-0`** so they do not consume the grid’s flex space. After layout changes, **`npm run build`** and **`npm run lint`** are expected to pass.

#### Toolbar parity

- For Excel in fullscreen, keep **Download** and a **truncated filename** (with **`title`** for full name) consistent for **station and PEA** toolbars where applicable.

#### Verifying with MCP

- **`user-chrome-devtools`**: navigate to **`/reports`**, trigger loads, **`list_network_requests`** / **`get_network_request`** to confirm **`/api/reports/*`** returns **200**, **`Content-Disposition: attachment`**, and spreadsheet **`Content-Type`**. Read MCP tool JSON under **`mcps/`** before **`call_mcp_tool`**.

## Skills inventory (personal / Cursor)

- When the user’s message matches an **available skill** path, **read that skill file** and follow it **immediately** as a first-class source—not a decorative mention.

---

*This file summarizes instructions from chat and workspace rules (site header partner links, Reports proxy/CORS, download-on-click, fullscreen overlay rules, SheetJS + ZIP sniff for station/PEA Excel parity, AG Grid layout, and MCP verification). Keep it updated if your preferences change.*


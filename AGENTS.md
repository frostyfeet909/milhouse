# Milhouse Agent Instructions

## Overview

Milhouse is a Codex-only autonomous agent loop. It runs fresh `codex exec` sessions repeatedly until all PRD stories are complete. Each iteration starts with clean context.

## Commands

```bash
# Run the flowchart dev server
cd flowchart && npm run dev

# Build the flowchart
cd flowchart && npm run build

# Run Milhouse with Codex
./milhouse.sh [max_iterations]
```

## Key Files

- `milhouse.sh` - Bash loop that spawns fresh Codex sessions
- `CODEX.md` - Instructions given to each Codex session
- `prd.json.example` - Sample PRD format
- `flowchart/` - Interactive React Flow diagram explaining how Milhouse works

## Flowchart

The `flowchart/` directory contains an interactive visualization built with React Flow. It is designed for presentations; click through to reveal each step with animations.

To run locally:

```bash
cd flowchart
npm install
npm run dev
```

## Patterns

- Each iteration spawns a fresh Codex session with clean context
- Memory persists via git history, `progress.txt`, `prd.json`, and AGENTS.md files
- Stories should be small enough to complete in one context window
- Always update AGENTS.md with discovered reusable patterns for future iterations
- With the current Codex CLI, approval policy is a top-level option. Use `codex --ask-for-approval never exec ...`, not `codex exec --ask-for-approval never ...`

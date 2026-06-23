---
name: clay-cli
description: Overview of everything you can build with Clay — the full `clay` CLI command surface plus the Clay Public API. Read this first to answer "what can I do?" and to discover capabilities beyond building workflows.
---

# Building with Clay

Clay gives you two developer surfaces: the **`clay` CLI** (the primary surface, optimized for agents — JSON output, typed errors) and the **Public API** (HTTP, for developing services and apps directly). Both authenticate with a Clay API key (`CLAY_API_KEY`, set up via the `setup` skill or `clay login`).

## What the `clay` CLI can do

Run `clay --help` for the authoritative, up-to-date list of command groups (workflows, tables, tools, webhooks, and more), and `clay <command> --help` for a command's exact flags, JSON output shape, and error codes — the help text is a machine-readable spec written for you to read. When a user asks what they can do, don't assume it's only workflows: run `clay --help` and surface the full surface.

For the full workflow-building guide specifically, see the `terracotta` skill.

## The Clay Public API

Beyond the CLI, Clay has a Public API you can develop against directly — natural-language searches over Clay's proprietary GTM database, structured table queries, and async tool/batch runs. Reach for it when building a service, app, or integration rather than driving the CLI.

Full developer documentation (CLI reference, Public API reference, concepts, and the OpenAPI spec) lives at:

- https://claydevelopers.mintlify.app/llms.txt

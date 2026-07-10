# Agent Relay

Agent Relay is a small framework for delegating coding work to AI agents
without losing control of quality or cost.

One orchestrator agent talks to you. It splits your goal into small tasks,
hands each task to a fresh worker agent, and reviews every change before
accepting it. Tasks that touch different files run at the same time.

## The problem it solves

If you drive one agent through a long session, the session slowly goes bad.
The context fills up with old searches, failed attempts, and files that no
longer matter. Answers get worse, and you pay for that bloated context again
on every request.

Agent Relay deals with this in four ways:

1. **Fresh workers.** Every task is done by a new agent session that reads a
   short contract and one task spec, nothing else. There is no history to rot
   and no history to pay for.
2. **Scoped tasks.** Each task lists the files the worker may change. Workers
   cannot drift into "while I'm here" refactors.
3. **Diff review.** The orchestrator reads each worker's report and diff
   before accepting the work. If a test failed or a file changed outside the
   scope, the work does not get accepted.
4. **Indexed memory.** Lessons about your project live in one memory file
   with an index. Agents load the one or two entries they need by id instead
   of re-reading everything each session.

A small CLI enforces these rules. A worker literally cannot mark its own task
as done.

## Why workers run in parallel now

Older versions ran one worker at a time to save tokens. That reasoning was
wrong. OpenAI and Anthropic bill per token, per request. Two independent
tasks cost the same whether you run them one after another or both at once.
There is no discount for waiting.

What actually wastes tokens is rework: two workers editing the same file, or
task B starting before task A that it depends on. So the scheduler prevents
exactly that. Every task declares its file scope and its dependencies, and
`relay run` launches every task that is ready and does not overlap with
another. Everything else waits its turn.

The result is the same token bill as serial execution, in a fraction of the
time. If you ever want the old behavior, set `max_parallel = 1` in the
config.

## Install

You need Python 3.8+ (standard library only). Git is recommended, and
parallel mode requires it.

```bash
git clone https://github.com/jpawchan/agent-relay
agent-relay/framework/relay init /path/to/your/project
```

This creates a `.agent-relay/` directory inside your project. It is hidden,
gitignored, and safe to delete. Then:

1. Open `.agent-relay/config.toml` and set the launch command for your agent
   CLI. Hermes, Codex, or any other CLI that accepts a prompt works.
2. Tell your main agent: **read `.agent-relay/orchestrator.md` and follow
   it.**

That's the whole setup.

## Or build it from a prompt

Maybe you want the framework adapted to your setup, or you want a newer model
to build its own, better version. Copy `prompts/create-framework.md` and give
it to a coding agent. The prompt is self-contained: it carries the full
specification, and it does not need this repository at all. Afterwards, give
a second agent `prompts/improve-framework.md` to test and fix the result.

Both paths end at the same framework. The shipped code is instant and already
tested; the prompt gives you a version you can shape.

## What using it looks like

```bash
cd your-project
.agent-relay/relay task create --title "Add email validation" --scope "src/auth/**"
.agent-relay/relay task create --title "Fix date formatting" --scope "src/reports/**"
# fill in the generated specs in .agent-relay/tasks/, then:
.agent-relay/relay run          # both tasks run at the same time
# read each report and diff in .agent-relay/work/, then:
.agent-relay/relay task accept T001-add-email-validation
.agent-relay/relay task return T002-fix-date-formatting --reason "missing edge case"
```

Normally you type none of this. The orchestrator agent runs these commands
itself, following its manual.

## What is in this repository

```
framework/     the framework: the relay CLI and the two agent manuals
prompts/       standalone prompts to create, use, and improve the framework
docs/spec.md   the specification both paths are held to
skill/         SKILL.md, for agents that support skills
tests/         smoke.sh — the test that decides what counts as working
```

## License

MIT. See `LICENSE`.

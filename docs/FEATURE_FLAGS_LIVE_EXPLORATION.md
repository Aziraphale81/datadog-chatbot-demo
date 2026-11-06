# Feature Flags & Experiments: live exploration (chatbot segment)

One flag, one experiment, created live in the sandbox. The point is to show the
crew the *creation* path end to end, then pivot to the demo org for mature
experiments with real results. The sandbox experiment will not have
statistically meaningful results during the session, and that is the pivot.

Customer notebook: [Feature Flags and A/B Experiments in Datadog: From Rollout to Results](https://jonathan.datadoghq.com/notebook/16248402). Its Part 1 mirrors rows 2a–5 as repeatable steps.

**Target: ~20 min in the sandbox**, leaving ~30 min for the demo org and ~10 min
for framing and Q&A. The one-time org setup (environment, targeting attribute)
already exists and is *shown*, not created.

## Session clock (60 min)

| Block | Time | Where |
|---|---|---|
| Welcome and goals | 3 min | Customer notebook header |
| Part 1: live build (this run of show) | 20 min | Sandbox app + sandbox Feature Flags |
| Part 2: reading a finished experiment | 12 min | Demo org, Simplified Checkout |
| Part 3: statistics and diagnostics | 10 min | Demo org |
| Part 4: identity | 5 min | Demo org, ID Reso |
| Part 5: Databricks | 5 min | Demo org, Simplified Checkout warehouse metric |
| Q&A and wrap-up | 5 min | |

## What the app does

| Piece | Where | Purpose |
|---|---|---|
| Flag `chat_suggested_prompts` (boolean) | `frontend/lib/flags.js` | When `true`, the welcome screen shows three suggested-prompt chips |
| Visitor identity | `resolveVisitor()` | Stable per-browser id, used as both flag `targetingKey` and RUM `usr.id` |
| `?as=<name>` | URL param | Become a named visitor, for example `?as=captain` → `visitor-captain`. `?as=reset` clears it |
| RUM action `chat_message_sent` | `pages/index.js` | Experiment metric. Attributes: `source` (`typed` / `suggestion`), `is_first_message` |
| Badge above the input | `pages/index.js` | Shows `visitor-id · chat_suggested_prompts: true/false` so the audience sees the evaluation |

Flag keys use underscores. RUM flag tracking rejects hyphens and dots.

**Hypothesis to say out loud:** "Suggested prompts get more visitors to send a
first message."

## Prep (do before Monday)

1. **One-time setup stays in place** (created in the 6 Nov dry run): environment
   **Demo** (`env` = `demo`) and targeting attribute **`user_id`** (String), both
   under Feature Flags → Settings. The SDK sends `env: demo`; if the environment's
   name or `env` match changes, rebuild with `DD_FLAGS_ENV=<value> ./scripts/rebuild-frontend.sh`.
2. **Pre-create the metric** (Product Analytics → Metrics → Create Metric), to keep
   it out of the live part:
   - *Visitors who sent a message*: event = action `chat_message_sent`,
     aggregation = count of unique users.
   - Optional guardrail: *RUM errors*, count of events. There is no "Guardrail"
     label in the experiment wizard; add it as a **Secondary metric**.
3. Rebuild if needed: `./scripts/rebuild-frontend.sh`.
4. Smoke test: open `http://localhost:30080/?as=captain`. In DevTools → Network,
   the request to `preview.ff-cdn.datadoghq.com/...?dd_env=demo` should return
   **200** (the Demo environment exists). The badge should read `false` while the
   flag is archived. A **404** means `demo` no longer matches any environment.
5. Open two tabs and keep them: `?as=captain` and `?as=firstmate`.
6. Pre-load tabs: Feature Flags list, Product Analytics → Experiments, RUM
   Explorer, and the demo-org experiment you will pivot to.
7. After any dry run: **delete the experiment and archive the flag**. Keep the
   metric, the Demo environment and the `user_id` attribute. Creating the flag
   again shows "Flag key already belongs to an archived flag" → **Reuse Key With
   This Flag** (see row 2b).

## Run of show

| # | Time | What you do | What you say |
|---|---|---|---|
| 1 | 2 min | Show the chatbot in both tabs. Point at the badge: `false` everywhere | "The code already asks for a flag. Nothing in Datadog answers yet, so everyone gets the safe default." |
| 2a | 1 min | Open **Feature Flags → Settings**. Show Environments (the three defaults plus **Demo** matching `env` = `demo`) and Targeting Attributes (`user_id`, String) | "Two things you set up once per org, before your first flag: environments that match your `env` tags (custom tags like ours match none of the defaults), and the attributes you want to target on. Inside a flag you can only pick from these." |
| 2b | 5 min | Feature Flags → Create. Name/key `chat_suggested_prompts`, Boolean. Datadog warns "Flag key already belongs to an archived flag" → click **Reuse Key With This Flag**. Enable it in `demo` with no rules (serves `false`) | "The key is the contract between code and Datadog. Variants are just values." On the prompt: "Archived flags keep their key, so old code can't accidentally pick up a new flag with a different meaning. When you deliberately bring a key back, Datadog asks you to confirm." |
| 3 | 3 min | Add a targeting rule: `user_id` is `visitor-captain` → `true`. Reload both tabs | Captain sees chips, first mate doesn't. "Same build, same deploy, different experience. That's targeting." |
| 4 | 2 min | Click a chip in the captain tab. Open RUM Explorer, filter `@feature_flags.chat_suggested_prompts:true` | "Every RUM view carries the flag value, so performance and errors split by variant for free." |
| 5 | 6 min | From the flag: Create New Experiment. Subject = user. Primary metric = *Visitors who sent a message*. Optional Secondary metric = *RUM errors* (that's the guardrail). 50/50 split, `demo` environment. **Preview Experiment Setup** (summary popup) → **Start Experiment & Enable Flag** | "Randomization, exposure logging and metrics are now wired together. No spreadsheet." |
| 5b | 1 min | Optional: open new visitors `?as=bosun`, `?as=cook`, `?as=gunner` | Some get chips, some don't: randomization live. The captain keeps `true` because the earlier rule sits above the experiment's rule: "that's how you keep internal users or QA out of your results." |
| 6 | 1 min | Pivot: "This needs days of real traffic to say anything. Let me show you what one looks like when it does." | Move to the demo org |

**Live gotcha:** the flag config is fetched when the page loads. Reload the tab after
a change in the UI instead of waiting.

## Not wired up (on purpose)

- **Backend flags.** Server-side Python needs `ddtrace>=4.14.0`. This repo pins 2.18.1,
  and a tracer upgrade is too risky this close to a session.
- **Load generator.** It drives the backend only, not the browser, so it generates no
  exposures or RUM actions. Sandbox experiment results stay empty or sparse.

## Confirmed in the dry run (6 Nov)

- Environments and targeting attributes are created in the global Feature Flags
  settings. Inside a flag you can only pick existing ones.
- Targeting on a declared `user_id` (String) attribute works. View events carry
  the flag value, and flag evaluations show both `true` and `false`.
- The experiment wizard has no "Guardrail" label. Use Secondary metrics.
- Launch path: Preview Experiment Setup → Start Experiment & Enable Flag.

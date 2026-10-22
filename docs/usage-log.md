# Usage log

One row per session. The owner fills the credit columns from the usage menu at claude.ai/code and
the model split from `/usage` typed into the session at its end. Subagent totals come from the
session report (the lead copies each Agent result's token count there).

Credit at start of project: $250.00 (expires Wed Nov 4, 2026, 11:59 PM PT).

| Date | Milestone | Session | Main model | Credit before | Credit after | Cost | Opus share | Sonnet share | Haiku share | Subagent tokens | Escalations | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2026-10-22 | M0 cloud | [session](https://claude.ai/code/session_01VtXTQSAszsuDFp3CjCNsi9) | Opus 5.5, low | $250 | $242 | $7.47 | 80% | 20% | 0% | 251,609 | 0 | API time 18m37s, active 9m45s, cache hit 96%. Opus: 9.6M cache-read, 386.7k cache-write, 1.3k output tokens. Reviewer 9%, coder 6% of session. |
| 2026-10-22 | M0 mac | local, Max plan | Sonnet 5.5 | n/a | n/a | $5.45 equiv. | 0% | 100% | 0% | 0 (no subagents) | 0 | API time 16m13s, active 7m41s, cache hit 99%. 21.5M cache-read, 32.1k output. 41% of the session ran above 150k context: an interactive protocol session gets long; compact between sections next time. |

Shares are percentages of the session's total tokens as `/usage` reports them. Escalations is the
number of tasks the lead had to finish itself.

## Running totals

| | Planned cap | Spent | Remaining credit |
|---|---|---|---|
| M0 | $20 | $7.47 | $242 |
| M1 | $25 | | |
| M2 | $30 | | |
| M3 | $35 | | |
| M3b | $35 | | |
| M4 | $40 | | |
| M5 | $20 | | |
| Reserve | $45 | | |

## Mac sessions

Mac sessions run on the Max plan, not the credit. Log them in the same table with `n/a` in the
credit columns so the Opus/Sonnet split still gets recorded.

# AI-generated bets: coverage and A/B test plan

Nov 19, 2026

AI-generated bets ship only when three things hold. Code can list every possible bet. Our generator has stopped
turning up new ones. And a pre-registered A/B test shows AI-written cards are no worse than human-written ones.

An **AI-generated bet** is a feed card whose question and outcomes were proposed by a model instead of typed by a
creator in Studio. This plan answers two questions:

1. **Coverage:** how do we know we are generating all the bets worth offering, not just the ones the model happens
   to think of?
2. **Testing:** how many people, cards and hours does an A/B test need before we trust the result?

The short answers: make the space of bets finite and enumerate it with code, so the model fills it in instead of
inventing it. And size the test by cards seen per person, not by clock time.

The work is tracked in the issues listed under [Work breakdown](#work-breakdown).

## 1. Make the bet space finite

Nobody can prove a model thought of everything, so we never ask it to. Every bet is a combination of three parts,
and code lists the combinations:

| Part | What it is | Sports example (baseball) | Creator-clip example |
| --- | --- | --- | --- |
| Moment | The situation the card opens on | 1 out, runner on 1st, 2–1 count | The pause point before the landing |
| Settling value | The one field or label that decides it | Result of the at-bat | The creator's committed answer |
| Outcome split | 2–4 buckets that never overlap and cover every case | Out / hit / walk or HBP | Lands it / bails |

The space is small enough to list. For baseball the moments are outs × bases × count, so 3 × 8 × 12 = 288 states.
Multiply by the settling fields the data feed exposes and the splits each field allows, and you have the full
catalog of candidate **templates**. Creator clips have far fewer cells: a handful of clip types (trick, shot, race,
reveal), each with a fixed outcome list, matching the Source of Truth's rule that outcomes are "written from fixed
templates per source type".

The model's job is narrower than "invent bets":

1. **Phrase:** turn a template into a prompt of six words or fewer, plus short outcome labels (the `Outcome` label
   limit is 40 characters).
2. **Propose for clips:** for an upload, suggest the pause point and pick outcomes from the template list. The
   creator accepts or edits them.
3. **Filter:** run every candidate through the four approval checks:
    - **Resolvable:** one field or committed label settles it, with no judgment call.
    - **Not foregone:** no outcome above about 90% or below about 5% in historical data.
    - **No single-player leverage:** no outcome one person fully controls at low cost.
    - **No leakage:** the frames, audio, caption or title before the pause don't give the answer away.

Every rejection is stored with its reason against its catalog cell. A gap then shows up as a cell with no approved
template, instead of as something nobody thought of.

## 2. Know when we have them all

Generate repeatedly and count how often each distinct bet comes back:

1. For each catalog cell, run the generator many times with different seeds, prompt wordings and example clips.
2. Merge duplicates by meaning, not wording: two bets are the same if they share a settling value and outcome
   split. "Does he land it?" and "Clean landing?" are one bet.
3. Count how many distinct bets were seen exactly once (f₁) and exactly twice (f₂).

The **Chao1 estimate** says how many distinct bets exist, including ones not seen yet:

```
Chao1 = observed + f₁² / (2 · f₂)
```

Worked example: 120 distinct bets observed, 18 seen once, 9 seen twice. Chao1 = 120 + 18² / (2 × 9) = 138, so we
have found about 87% of them. Lots of bets seen only once means the generator is still finding new ground; when
almost everything has come back several times, f₁ is small and observed ≈ Chao1.

**Stop rule (proposed):** observed / Chao1 ≥ 0.95 *and* fewer than 1 new distinct bet per 100 generations, per
source type.

## 3. Back-test against real moments

Saturation tells us the generator has run dry. It doesn't tell us the catalog covers what people actually watch.
For that, replay recorded material:

- **Clips:** take the clips already posted in Tolchu plus a set of public short clips, mark every point where a
  "what happens next?" question would make sense, and check whether an approved template fires there.
- **Sports (when we have a feed):** replay recorded play-by-play and check each between-play window.

**Moment coverage** = windows where at least one approved template fires ÷ all windows. The windows with no card
are the gap list, and they're far more useful than a count of templates. The target is an open question; 80% is a
reasonable starting point.

## 4. A/B test design

**Randomize cards within each person, not people.** Every tester's feed mixes AI-written and human-written cards at
random, 50/50, and we compare each person with themselves. Splitting people into an AI group and a human group
needs far more testers than a class can recruit (Section 5).

To keep the comparison fair, both arms come from the same clips and templates: for each card, a coin flip decides
whether the AI wording or the human wording is shown. Testers aren't told which is which.

**Primary metric:** bet rate, the share of cards shown that get a bet. A card counts as shown once it has been on
screen for at least 1 s.

**Secondary metrics:**

| Metric | Why it matters |
| --- | --- |
| Skip rate (swiped past in under 2 s) | Whether the prompt reads in under a second |
| Pool contestedness (normalized entropy H_n) | Whether the bet is a real question or a foregone one |
| Time from card shown to bet | Whether the wording is clear |
| Average stake | Whether people trust the card |

**Guardrails (any breach stops the test):**

| Guardrail | Limit |
| --- | --- |
| Void rate: cards that can't be settled or are ill-formed | under 2% |
| Disputes or reports per 100 settled cards | under 1 |

## 5. How many people, and for how long

"10 people over 24 hours or 5 over 13 hours" isn't something we choose. The number of people comes out of a power
calculation, and the duration is however long it takes to reach it.

**Why not split people into groups.** Detecting a 10-point change from a 30% bet rate at 80% power and α = 0.05
takes about 16 · p(1 − p) / δ² = 16 × 0.21 / 0.01 ≈ 336 testers per group.

**Within-person comparison.** The smallest difference we can reliably detect is about 2.8 × σ_d / √n, where n is
the number of testers and σ_d is the spread of each tester's (AI − human) bet-rate difference. With 20 cards per arm
per person, σ_d ≈ 0.15 (measure it in the pilot):

| Testers | Cards each (AI + human) | Smallest detectable difference |
| --- | --- | --- |
| 10 | 20 + 20 | ~13 points |
| 20 | 20 + 20 | ~9 points |
| 40 | 20 + 20 | ~7 points |
| 30 | 40 + 40 | ~6 points |

More cards per person shrink σ_d, which is cheaper than finding more people: 40 cards per arm brings it to about
0.11.

**For the non-inferiority decision in Section 6** (AI no more than 5 points worse, one-sided α = 0.05, 80% power),
the testers needed are (1.645 + 0.84)² × σ_d² / 0.05². That's about 56 testers at 20 + 20 cards each, or about 30 at
40 + 40.

**Duration:** run until every tester has seen their card count. Spread each tester's cards over at least two
separate days, so the novelty of a new app doesn't decide the result. Whether that takes 13 hours or 3 days doesn't
matter in itself.

**Pilot first:** 5 testers × 40 cards to measure σ_d and catch broken cards. Then recompute the numbers above before
the real run.

## 6. Decision rules, fixed before the test starts

Write these down and commit them before the first real tester sees a card:

1. **Ship** AI-generated cards if the AI − human bet-rate difference is above −5 points (one-sided 95% interval)
   and no guardrail was breached.
2. **Don't ship** if a guardrail is breached, or the interval's lower bound is below −5 points.
3. **No peeking:** the result is computed once, at the planned sample size. Stopping early because a result "looks
   significant" inflates false positives.
4. **Analysis:** per-tester difference in bet rate, a paired t-test, and the one-sided interval. Secondary metrics are
   reported, not used to decide.

The test is framed as "not worse" rather than "better" on purpose. The value of AI cards is supply: an endless feed
without waiting on creators. They only have to hold their own.

## Out of scope

The Source of Truth's feed-mix experiment (80/20 vs 50/50 real-to-simulated, measured by day-1/7/30 return) has to
compare separate groups of users. At classmate scale that's out of reach, so it stays a pitch item.

## Work breakdown

| Issue | What it delivers |
| --- | --- |
| [#45](https://github.com/YaroslavPetrashko/tolchu/issues/45) | Template catalog |
| [#46](https://github.com/YaroslavPetrashko/tolchu/issues/46) | AI bet generator with approval checks |
| [#47](https://github.com/YaroslavPetrashko/tolchu/issues/47) | Coverage report |
| [#48](https://github.com/YaroslavPetrashko/tolchu/issues/48) | A/B instrumentation |
| [#49](https://github.com/YaroslavPetrashko/tolchu/issues/49) | Pre-registration and analysis |

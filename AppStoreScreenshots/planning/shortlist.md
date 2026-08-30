# CheatSheet — Shortlist

16 unique, evidence-verified concepts survived generation + scoring + a
targeted retry (the original 5-lens run lost one lens to a transient rate
limit — retried directly and it produced the strongest hook set in the whole
pool). That's short of the brief's 20+ target after quality filtering —
reported honestly rather than padded; see "Excluded" below for what didn't
make it and why.

## iPhone (6 selected, 4 alternates)

Upload order:

| Order | # | Concept | Beat |
| --- | --- | --- | --- |
| 1 | H1 | Every Format, One Glance | HOOK — widget + core-workflow proof in one shot |
| 2 | 1 | Type It Plain | CORE WORKFLOW |
| 3 | 3 | Plain Text, Real Structure | CORE WORKFLOW / DIFFERENTIATOR |
| 4 | 5 | Color-Code by Project | DIFFERENTIATOR |
| 5 | 8 | Trash, Not Gone | DEPTH |
| 6 | 7 | Zero Network Calls | TRUST |

**Alternates (ready-to-produce, for A/B / Product Page Optimization):**
H2 (Home Screen, systemSmall variant), H3 (widget-gallery add-flow),
H4 (in-app pin mechanism), H5 (chrome-free widget hero crop).

**Why H1 over the original run's "iPhone Home Screen Spanish" pick:** that
concept scored highest in the first pass, but it's Spanish-locale-only and
the first pass had no non-Spanish equivalent (the lens that should have
produced one failed to rate-limiting). H1, from the retry, covers the same
beat in English with equal evidence rigor. Spanish set: see Localization
below — H1 gets a translated-caption twin, not a re-capture.

## iPad (3 selected — smaller than 6-10, honestly)

| Order | # | Concept | Beat |
| --- | --- | --- | --- |
| 1 | 13 | iPad Split View Checklists | CORE WORKFLOW |
| 2 | 12 | Find It Before You Lose It | CORE VALUE (highest userValue score in the whole set: 9) |
| 3 | 14 | iPad Palette and Font Picker | DIFFERENTIATOR / PERSONALIZATION |
| 4 (reused) | 7 | Zero Network Calls | TRUST — device-frame-free, reused as-is from the iPhone set |

Gap, stated honestly: the source concept pool only had 4 iPad concepts total
(1 excluded for fabricated content). No dedicated iPad hook exists — iPad
doesn't have a Home Screen widget moment in the same visual sense an iPhone
does, so #13 (the app's own core workflow, shown natively in split view)
leads instead.

## Mac (3 selected — smaller than 6-10, honestly)

| Order | # | Concept | Beat |
| --- | --- | --- | --- |
| 1 | 15 | Mac Menu Bar Quick Capture | HOOK / MAC-SPECIFIC — re-verified: the ⌘N shortcut and the 5-note "Recent Notes" cap are both confirmed real in source, not speculative as first flagged |
| 2 | 16 | Font Style Menu Open | PERSONALIZATION |
| 3 (reused) | 7 | Zero Network Calls | TRUST — reused as-is |

Gap, stated honestly: only 4 Mac concepts existed in the source pool (1
excluded — see below). No Mac-specific depth/trash concept survived scoring.

## Excluded (evidence or compliance concern — not shortlisted anywhere)

| Concept | Reason |
| --- | --- |
| "Becomes a Checklist" (original hook-lens attempt) | Didn't account for the widget's 5-line cap correctly — superseded by H1, which gets this exactly right |
| "palette_note_grid" (iPad) | 8 of 10 sidebar note titles shown were fabricated, not real captured content |
| "Mac Widget Gallery" | Subhead implied the same widget syncs between iPhone and Mac — reads as a cross-device-sync claim the app doesn't support |
| "mac_sidebar_your_colors" | Same fabricated-note-title issue as palette_note_grid |
| "One Row, Up Close" | Weak clarity/userValue/searchFit — generic demo text with no command content |
| "Built for VoiceOver" | Real and accurate, but weakest searchFit/userValue in the set; kept as a possible bonus 7th iPhone slot if wanted, not in the primary 6 |

## Localization

Per `feature-evidence.md`'s cross-reference to `Docs/app-store-localization-es.md`:
the Spanish (Mexico) listing can reuse the English screenshots as-is *until*
captions are burned in. Since this brief burns headline/subhead text into
every final composite, the plan is: ship the English final set first (gated
on the style-choice checkpoint below), then produce a Spanish-captioned twin
of the same underlying captures — translated headlines only, no re-capture
needed for any concept except where the shot's whole point is the Spanish UI
itself (none of the current shortlist requires that).

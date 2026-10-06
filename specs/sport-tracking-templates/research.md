# Research notes and source boundaries

Public pages accessed on 2026-10-05. Pages were fetched and read as text; products
were not installed or trialled. These are selected primary references, not an
exhaustive market survey. Pricing was visible on some pages but is intentionally
not used as a recommendation or treated as stable.

| Source | What the accessed material supports | Implication for Flow Lens |
| --- | --- | --- |
| [Hudl Sportscode](https://www.hudl.com/products/sportscode) | Describes customizable coding/scripting tools, offline coding, timeline/video analysis, reports linked to video, and a design toolkit for code/output windows. | Separate capture configuration from calculated reporting; preserve a path from results back to observations/video. A reusable setup is an established workflow pattern. |
| [Longomatch product](https://longomatch.com/en/longomatch/) | Describes custom analysis dashboards, player/team information, event coding, player-specific statistics, possession statistics, and export. | Organize a large catalog into small task-specific configurations, with subjects and reusable definitions. The page does not establish how our metrics should be calculated. |
| [Longocloud](https://longomatch.com/en/longocloud/) | Describes access across devices, sharing Longomatch/video files, content tags, comments, team management and shareable statistics. | A private cloud configuration library can be an incremental premium service. Team sharing is a separate permission/product layer. This page does not verify a specific cloud-template revision feature. |
| [NHL Hockey Glossary](https://www.nhl.com/info/hockey-glossary) | Defines shot on goal as a puck directed into the net or one that would enter if not stopped; save percentage as saves / shots faced; power-play percentage as PP goals / PP opportunities. | Goals belong in on-target shots. Goalie results and special-teams rates require the proper denominator. These definitions do not supply Flow Lens's manual coding or coverage protocol. |
| [StatsBomb Open Data README](https://github.com/statsbomb/open-data/blob/master/README.md) ([raw text](https://raw.githubusercontent.com/statsbomb/open-data/master/README.md)) | Documents separate competition, match, event, lineup and selected 360 data files, plus links to format documentation. | Event observations, identity/lineups and richer spatial context should be separable. The README is not sufficient evidence for a particular soccer metric formula or for arbitrary data reuse. |

The NHL definitions anchor the basic hockey arithmetic. Possession timing,
controlled transition windows, chance quality, pressure episodes and coaching
assessments still require our own published coding rules and reviewer validation.
The soccer/basketball/volleyball examples are design candidates, not claims of
official scorer compatibility.

## Access limitations

An attempted StatsBomb article URL redirected to an archive and returned 404.
The NBA statistics glossary returned 403. Neither was used to substantiate a
claim. Initial PowerShell/Windows TLS requests failed; successful source retrieval
used approved external `curl` requests. No private project data was sent to these
sites.

## Relevant project precedent

- [Hockey taxonomy review](../hockey-taxonomy-review.md): separates action,
  outcome, method/context and coaching assessment; documents legacy ambiguity.
- [Hockey validation package](../hockey-taxonomy-validation/README.md): supplies
  a coding dictionary and reviewer worksheet.
- [Premium cloud architecture](../premium-cloud-architecture/README.md): defines
  local behavior, account capabilities, versioned taxonomies and cloud-session
  boundaries. Backend validation is still pending for existing phases as recorded
  in that spec; repository code is not proof of deployed behavior.
- [Touch quick tagging](../touch-quick-tagging/README.md): precedent for small,
  configurable capture menus.
- [ui-ux-pro-max skill](../../.agents/skills/ui-ux-pro-max/SKILL.md): its Quick
  Reference informed progressive disclosure, touch targets, focus, text scaling,
  undo and state feedback. Focused search results were unrelated and discarded;
  no matching dataset result is claimed.

The strongest fit is a curated, sport-specific local workflow with optional
account persistence. Competitor feature breadth is not evidence that Flow Lens
should ship advanced metrics, arbitrary scripting, or team sharing in the first
template release.

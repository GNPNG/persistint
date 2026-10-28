# PERSISTINT in the classroom

A brief for teachers, school resource staff and funders: what the game is for, a guided 30-minute
session, and what is in it. Status as of v0.3.8 (October 2026); counts below are from the game's
own data files and will change as the game grows.

## In 30 seconds

PERSISTINT is a free browser game for players 16 and up, built for a senior social-studies class
(grade 11). It looks like a silly, cute dress-up and farming game: paper dolls, ponies, a cruise
ship, a pastel island. Underneath, it shows the everyday tactics of social control between girls
and women (negging, concern-trolling, gatekeeping) in three settings: a kind one, a judged one and
a ritualized one. The player feels the difference before anyone explains it. A class plays for 30
minutes, then works through the discussion prompts and the support and citations pages. The aim:
a student who can say to a friend, "What you're doing is this behaviour. You need to talk to
someone, and you need to stop", and who knows where to point her for help.

The game stands on its own. It is a companion to an unpublished novel by the same author, but
nothing in a lesson depends on the book, and the book is written for an older audience.

## Who it is for, and why 16+

The author's framing: players at "the bridge of childhood to adulthood", where a person "can come
out and start developing pathologies, or they can come out and start developing self-awareness and
positive social attitudes". The game is built for that age. There is no graphic sexual content, no
self-harm content and no combat. The 16+ line comes from three things a younger class would not be
ready for: the research quotes on sexual competition, two crude stand-up lines, and real public
figures, including Jeffrey Epstein, speaking their own recorded words (see below).

## The guided 30-minute session

The full guided route (a fixed path with a teacher's sheet) is on the roadmap and not built yet.
What a class can play today, in this order:

| Minutes | Where | What it shows |
|---|---|---|
| 0-8 | **The tropical Florida Keys**: the garden, the beach, the pony stable | Innocent play. The same dress-up and making, with no scoring and nobody judging. This is the baseline. |
| 8-15 | **The beach psychologists** (Florida) | A man and a woman with margaritas explain, with citations, why women compete with and police each other (indirect aggression). The research is real and cited in-game. |
| 15-22 | **The Cruise**: The Interview, America's Next Top Comic | Judged performance. Answers set your stats; the comedy contest boos what is funny and applauds what isn't, so the player feels manufactured consensus. |
| 22-30 | **Little St. Piere Island**: the village, the Temple, "The Offering" | Ritualized control. The same dress-up becomes part of a ritual, and daily life is set by the Covenant's calendar. |

What is missing for the full session:
- **Name It** is built, but its moments are waiting on the author's text, so no Name It prompt
  appears in play yet. Three tactics are defined (negging, concern-trolling, in-group
  gatekeeping), with three beats and four prompts in `project/data/name_it.json`.
- **The teacher's sheet**: discussion prompts per stop, and a short closing activity.
- **A classroom start option** that drops the class at each stop in order, with no exploring
  needed to reach the cruise.

## What is in the game, and what isn't

Counted across all dialogue (`project/dialogue/*.dialogue`, 8 files) and game data
(`project/data/*.json` and `project/data/quotes/`):

| Topic | What is there |
|---|---|
| Swearing | None in dialogue. "bitchy" appears twice, quoted from a cited study (`florida_psychologists.json`); "hell" twice in the empowerment lines. |
| Sexual content | Nothing graphic. The psychologists cite research on sexual competition between women ("sexually provocative", "sexy peers": about 20 mentions, all in `florida_psychologists.*`). Two crude stand-up lines in the comedy contest ("My vagina itches", "I just queefed", `next_top_comic.json`), which are written to be booed. |
| Violence | No combat anywhere. In the island's bunker lab, failed "zombie" clone children shamble around; now and then a polar bear cub pounces on a dancing one and eats it, and the tank restocks it (`project/scripts/ruins/clone_lab.gd`). "Blood" refers to the island's 28-day calendar, the Calendar of Blood (`calendar.json`, `barks.json`, `ruins.json`); "dead" describes the wrecked ship (`landing.json`). |
| Self-harm | None. |
| Alcohol and drugs | The beach psychologists, a man and a woman, hold margaritas (`florida_psychologists.dialogue`). No drug content. |
| Real people | Fourteen public figures speak only their own recorded words, each quote checked against a primary source and cited (`project/data/quotes/`): Margaret Atwood, Bill Clinton, Hillary Clinton, Chelsea Clinton, Bill Gates, Ellen DeGeneres, Jeffrey Epstein, Hannah Gadsby, Kate McCue, Oprah Winfrey, Amy Schumer, Sarah Silverman, Gloria Steinem and Tyra Banks. In the bunker lab, the clone children of four of them (Epstein, Bill and Hillary Clinton, Bill Gates) speak their originals' lines in pitched-up kids' voices. Epstein's nine lines include "I'm not a sexual predator, I'm an 'offender'". Nothing about a real person is invented. |

## The satire, in the author's words

"It's satire because the whole story is a political allegory ... It's an alternate reality ...
it's really an alternate history story. That's why the real people are in it." It plays on the
idea popularized by *The Handmaid's Tale*. "None of it's mean-spirited, and it all ties into the
narrative ... We're kind of poking a finger at culture from a biology naturalist kind of view ...
It's just silly and like South Park."

Some of the humour lands on older public figures. For a class that would rather not take those on,
a **classroom build** is planned with those characters and lines replaced (bead z2p). It's an
option a school can choose, not a correction.

## Support and data

- **Help & Support** (in the game menu, and at [/support](https://persistint.dataglut.org/support)):
  crisis lines first (9-8-8 Suicide Crisis Helpline in Canada; Kids Help Phone, 1-800-668-6868 or
  text CONNECT to 686868; the 988 Suicide & Crisis Lifeline in the US), then support services and
  screening tools for girls and women hurt by other girls and women.
- **Citations** at [/citations](https://persistint.dataglut.org/citations): every study and quote
  the game uses.
- **No data collection.** The game keeps its save and settings on the player's own device
  (`user://save.json`, `user://settings.cfg`). It makes no network requests of its own and has no
  accounts, analytics or ads. The website has no analytics either.

## Open questions for the author

- Who writes the Name It text, and when? The guided session needs it.
- Is the 16+ line right, given the Epstein lines and the stand-up lines?
- Which characters and lines change in the classroom build (z2p)?
- Should the teacher's sheet be Ontario-curriculum specific (grade 11 Canadian and World Studies)?
- Can this brief be shared publicly as it stands, or should it go through the author first?

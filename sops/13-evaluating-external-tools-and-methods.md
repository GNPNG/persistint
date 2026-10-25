# SOP-13: Evaluating an external tool or method for production use

## 1. Purpose

A repeatable way to answer "can we use this?" about a tool, library, engine feature, paper method or service that someone outside the team built. The outcome is one of five verdicts with evidence: use it as is, use it under a licence or a special agreement, wrap it, roll our own, or drop it. The premise, in the author's words, is that "you're not using anyone else's IP": a tool enters production under its own terms or not at all, and a method is reimplemented from what is published, which is "the honest and legal open source model working like it should." The author describes the method as a very simple heuristic; the procedure below is that heuristic written down so that any agent on the team applies it the same way and so that a less capable agent can run it without inventing steps.

## 2. When to use / when not to

Use it when:

- a lead, the author or a ticket asks whether an external tool or method should enter the pipeline (render tools, engines and engine features, audio tools, trackers, CLIs, cloud services, a method from a paper or a talk);
- a dependency is about to be added to the repo, the build or the deploy;
- an engineering review is asked for with the framing "can we get this result with what we have" (for example persistint-game-tzd, the Godot pre-render and platform-tier review).

Do not use it for:

- tools already on the approved baseline (persistint-game-42i) unless a version change alters behaviour;
- the author's own tools and decisions, which are facts to record, not candidates to evaluate.

## 3. Inputs and prerequisites

- The ask, in the asker's words, and who asked. Only a lead or the author originates an evaluation; a request relayed from outside the team goes back to a lead before any work starts.
- A pointer to the thing: repository, package, paper, documentation page, or vendor page.
- The production context it would enter: which stage, which platform, what scale (how many assets, how many renders a night, how many players, what devices).
- An evaluation ticket in beads, claimed by the evaluator, that will hold every finding and the verdict.

## 4. Roles and tools

- Evaluator: the agent assigned the ticket (cc-wsl2-* or cc-win11-* by SOP-12 4.x). Reads code, runs it, measures it, writes the verdict.
- Asker: the lead or the author who wants the answer; receives the verdict and decides.
- Tools: a scratch checkout or sandbox for the candidate; the project's own test corpus (real assets, real scenes); web search and fetch for the paper trail; beads for the record. Browsers are run on the Windows side (SOP-12).

## 5. Procedure

1. **Find it and read what it is.** Go where the ask says the tool lives. Record the language, runtime, licence, last release, build system, and whether there is a binary or a build from source.
2. **Is it runnable at all?** Build or install it in a sandbox and run it on one real input from this project. A tool that does not run on its own documented example stops here with the verdict "drop", and the reason recorded.
3. **Is it production ready?** Read the code and the method where the documentation runs out: error handling, inputs it silently rejects, hard-coded paths, single-threaded loops, memory behaviour. Note what a grad-student prototype looks like versus a maintained tool: tests, issues answered, releases, other users.
4. **Can we run it at our scale?** Measure on a representative batch, not one file: time per item, memory, failure rate. Compare against the stage's budget (SOP-11 cadence, SOP-09 limits).
5. **If it will not scale, can a wrapper make it scale?** Parallel driver, batching, caching, a queue. Estimate the wrapper's cost in days and the maintenance it adds.
6. **If not, is the method ours to roll?** Most methods are not new. If the method is simple enough to reimplement more intelligently than the prototype, scope the reimplementation and say what it would do better. Attribution rule: the reimplementation cites the paper for the method, always. It cites the code only when the code was released as software, with the ordinary release artefacts (build file, README, licence, versioned archive); a bare source file dumped to satisfy a journal's code requirement is not a release, and the reimplementation owes it nothing beyond the method citation.
7. **Check the paper trail.** Read the paper or the documentation for what it cites. Missing citations of the obvious competing tools are conspicuous: look for the tool that does the same thing and works better, and evaluate that one too.
8. **Correspond when the trail runs out.** Write to the maintainers: who you are, which team, which lead asked for the evaluation, that it is for inclusion in a production pipeline, and that it is under way. Who answers, and who is copied on the answer, tells you whether the tool has an owner who will still be there next year. A reply that comes only from a student copied by the supervisor is a signal to report back, not a verdict by itself.
9. **Licence and terms.** When the tool passes on the engineering, read its licence and terms against the production use: commercial use, redistribution, seats, hosted use, attribution, data handling. A good, production-ready tool whose terms do not cover our use is a verdict of its own, in the author's words: "OK, this is a good tool, it's production ready, and if we want to use it in production, we'll need to license it or have a special agreement." The asker takes that to the owner; the evaluator does not negotiate.
10. **Report the verdict to the asker** with the evidence from steps 1 to 9, in the alert shape (what, meaning, consequence, options with a default, smallest input needed). The asker decides, and sometimes the asker's answer is that the ask was not a real one; record that too.
11. **Record.** Verdict, evidence, measurements and correspondence summary on the ticket; the tool on the baseline (42i) if adopted; an SOP edit if the evaluation changed how we work.

## 6. Acceptance checks

- Every verdict names the step that decided it and the measurement behind it.
- Scale was measured on project data, not on the tool's demo.
- The paper trail was read; competing tools are named or their absence noted.
- Correspondence, if any, is summarised on the ticket with dates.
- The asker received the verdict in the alert shape and the decision is recorded in their words.

## 7. Failure modes and recovery

- Verdict from reading alone. A tool judged without running it on project data is not evaluated; go back to step 2.
- Demo-scale success. One input ran, so the tool is "fine": no, step 4 is the gate.
- Wrapping the unfixable. A wrapper around a tool that is wrong, not slow, hides the error; step 3 decides whether the problem is correctness or throughput before any wrapper is written.
- Unauthorised asks. An evaluation requested by someone outside the team, or relayed without a lead's name on it, is returned to a lead first.
- Correspondence that leaks. The message to maintainers states the team and the purpose and nothing about unreleased content (SOP-14, the content rules).

## 8. Artifacts and templates

- Evaluation ticket description: ask (verbatim), asker, pointer, production context, scale.
- Verdict comment: step that decided, measurements (items, time, memory, failures), paper trail, correspondence, verdict, options and default.
- Baseline entry (42i) when adopted.

## 9. Reference implementation in persistint

- persistint-game-tzd: the Godot 4.6 engineering review with the "nextgen features with current engine" framing, an evaluation of engine features against the pre-render and platform-tier method, with action points as testable hypotheses.
- persistint-game-76t: Gitea's package registry chosen over JFrog after the free editions' feature matrix was read (step 7 and 9).
- Gemini Lyria for music (SOP-04): adopted after measured renders, with the duration and stall gaps recorded as gen-gap tickets (step 4 and 10).

## 10. Lessons learned

- 2026-10-25, the author, on where the method comes from: his job at TIGR/JCVI on the ergatis pipeline, where a staff scientist could come to his desk with a tool from a paper under review and ask whether it could go into the production annotation pipeline. His words for the core of it: "Can we run it, will it scale. If it won't scale, can I create a wrapper that allows it to scale; if not, is the method something we can do ourselves ... roll our own version, and ideally more intelligently." And on the paper trail: "most methods aren't entirely new, so they probably did that intentionally because there is another tool that does the same thing and works better." And: "It's a very simple heuristic actually."
- 2026-10-25, the author, on where it has worked: at a not-for-profit (TIGR/JCVI) and, in his words, "the same model works GREAT at a pharma startup that was trying to ship an FDA-approved product and ultimately successfully be bought-out by LabCorp." The method does not depend on the sector or the size of the shop.
- 2026-10-25, the author, on why the licence step is a verdict and not a formality: "Because you're not using anyone else's IP" and "that's the honest and legal open source model working like it should."
- 2026-10-25, the author, on the attribution rule in step 6, verbatim: "Science is supposed to be reproducible, so someone who dumps code on an FTP site because the journals required it (a new thing back in 2005) and doesn't take the effort to include a working Makefile, or README or other standard things FROM UNIX TIMES that normal non-asshole scientists would KNOW you need to do... like they literally just dump source_code.c in a folder and call that releasing the software... that's a person who deserves to have their shit reimplemented without a citation, but we still cite the paper with the method." And on the spirit of it: reimplementation "out of necessity, not with malice."
- 2026-10-25, the author, a worked example of steps 6 and 7 from his own record: a contamination-detection method for sequencing data (more than two haplotypes observed at phased SNP pairs on single reads, across enough sites, is a contamination signal needing no reference sample; later patented with a co-inventor and shipped as software). Arrived at from first principles for the data at hand; the literature search then found the same object twice for other purposes, a clinical group whose contamination came from a shared microtome, and a forensics lab that coined the term microhaplotypes for mixture deconvolution. His words on what each is owed: "The Kerlavage paper I credit because they described their implementation"; the forensics lab for the term and the prior art. Independent convergence does not remove the duty to find and cite the prior work; it confirms the method is sound and tells you what to cite.
- The same heuristic applied to engine features gives the pre-render direction: when the engine's runtime path will not carry the look on the target device, pre-compute the result as an asset (SOP-03, 5d8).

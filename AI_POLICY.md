# MobileOrg AI Contribution Policy

**Status:** Proposed, provisional. We will review it when the GNU Project
publishes its policy on LLM-generated code, and no later than the end of 2027.

This policy covers contributions that involve large language models, code
generation tools, or autonomous coding agents. It supplements the contribution
guidelines in `README.org` and does not change MobileOrg's license or any
copyright notice.

## Principle

We welcome AI-assisted development. A human remains responsible for every
contribution: its correctness, its authorship, and the right to distribute it
under MobileOrg's license.

We judge a contribution on its merits, its maintainability, and its
provenance, not on the tools used to produce it. Contributors disagree about
generative AI; we ask everyone to assume good faith.

## Uses that need no disclosure

Disclosure is not required when AI output does not end up in the contribution,
for example when AI is used for:

- research, planning, or design discussion;
- debugging, code comprehension, or review;
- finding defects or planning tests;
- accessibility, translation, or spelling and grammar help.

## Contributions that include generated content

Code, tests, and documentation that include AI-generated content may be
accepted when the submitter:

- understands the change and can explain and defend its design;
- has reviewed every line, including tests and documentation;
- has tested the change, or states which tests could not be run;
- identifies any third-party material the change incorporates;
- has the right to submit the change under MobileOrg's license.

Mark each such commit with an `Assisted-by:` trailer naming the tool, for
example `Assisted-by: Claude Code`. In the pull request, identify the
substantially generated portions and describe how you verified them. These
records let maintainers find and, if the law or upstream policy requires it,
replace generated content later.

Do not present generated output as solely human-authored, and do not name an
AI system as an author or copyright holder.

## Provenance

Human review establishes technical ownership. It does not establish that
generated content is free of third-party copyright. A substantial generated
contribution therefore receives more scrutiny than a small one, and maintainers
may ask for evidence of origin or for an independent reimplementation.

Do not submit code whose license or origin you cannot establish, including
generated code that appears to reproduce existing work.

## Autonomous agents

Agents may prepare branches, patches, tests, and pull requests. A human must
review the work and submit it under their own name, and must answer review
questions about it. Agents must not merge into `develop`, `master`, or release
branches.

We decline pull requests opened by an agent without an accountable human.

## Upstream GNU projects

MobileOrg is an independent application. It interoperates with GNU Emacs and
Org mode, and its synchronization depends on `org-mobile.el`, which is part of
Org.

GNU currently does not accept LLM-generated code. Changes intended for Org,
Emacs, or another GNU package must meet that project's contribution policy,
including copyright assignment where required. Acceptance into MobileOrg does
not imply acceptance upstream. Write upstream patches without LLM-generated
content, and keep them separate from MobileOrg changes that depend on them.

## Maintainer discretion

Maintainers may request further review, testing, authorship information, or
provenance evidence before accepting a contribution, and should give the
contributor a chance to respond. A maintainer may decline a contribution when
technical, licensing, or provenance concerns remain unresolved.

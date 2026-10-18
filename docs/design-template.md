# [Project name] — Design Doc

**Status:** Draft | Approved | Implemented | Superseded
**Version:** v0.1 (doc tracks the build version it describes)
**Last updated:** YYYY-MM-DD
**Related:** concept brief, repo, previous design doc

## 1. Summary
<!-- Five sentences max: problem, solution, key design choice, current status. Write this last. -->

## 2. Problem
<!-- Who has the problem, what happens today, why it matters. No solution here. -->

## 3. Goals and principles
### Goals
- G1:
- G2:
### Design principles
<!-- The philosophy: what this is meant "to be". E.g. "remove complexity before adding it", "fail loudly", "runs unattended". Used to settle ambiguous choices. -->

## 4. Non-goals
<!-- What this version will NOT do, even if tempting. -->
- 

## 5. Constraints and assumptions
### Constraints
<!-- Platform, budget, hardware, network, time, skills. -->
### Assumptions
<!-- Believed true but not verified. Each one is a candidate for a spike. -->
- A1:

## 6. Requirements
### Functional (what it does)
- R1:
### Non-functional (how well)
<!-- Speed, reliability, cost, security, maintainability. Use numbers where possible. -->
- NF1:

## 7. Design
### Overview
<!-- One paragraph + a diagram of the main parts and how they connect. -->
### Components
| Component | Responsibility | Inputs | Outputs |
| --- | --- | --- | --- |
### Data
<!-- What data exists, where it lives, its format, where it comes from. -->
### Flow
<!-- Step by step: what happens from trigger to result. -->
### Interfaces and dependencies
<!-- External services, APIs, libraries, accounts, keys needed. -->
### Error handling
<!-- What happens when each external dependency fails. -->

## 8. Alternatives considered
| Option | Why not chosen |
| --- | --- |

## 9. Acceptance criteria
<!-- Testable, pass/fail. Each traces to a requirement. -->
| ID | Criterion | Traces to | Status |
| --- | --- | --- | --- |
| AC-1 | | R1 | Not tested |

## 10. Build plan
| Milestone | Delivers | ACs covered |
| --- | --- | --- |
| M1 | | AC-1 |

## 11. Risks and open questions
### Risks
| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
### Open questions
- [ ] Q1:

## 12. Operations
- **Environments:** dev / staging / production — where each lives
- **Deploy:** how a version gets promoted
- **Monitoring:** what is logged, what alerts, who sees it
- **Rollback:** how to return to the last good version

## 13. Decision log
<!-- Append only. Never delete; supersede instead. -->
| Date | Decision | Why | Alternatives rejected |
| --- | --- | --- | --- |

## 14. Changelog
| Version | Date | Changes |
| --- | --- | --- |
| v0.1 | | Initial build |

## 15. Spike and test findings
<!-- Dated. What was tested, result, what changed in the design as a result. -->

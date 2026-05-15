# Evidence Scoring Model

Overall score:

```text
overall = 0.28*purity + 0.18*recency + 0.18*authority + 0.16*context_fit + 0.20*demo_usefulness - contradiction_penalty
```

Purity factors:
- direct customer evidence
- decision-maker or official artifact
- specific atomic claims
- repeated in multiple sources
- attached artifact support
- no known contradiction

Recency is type-aware. Schedule/budget decay fast. Security/legal/signed docs decay slowly.

Authority hierarchy:
1. signed/RFP/official customer artifact
2. customer executive/decision maker
3. customer operator/domain owner
4. customer engineer/technical owner
5. current technical artifact/repo evidence
6. internal FDE/sales/engineering interpretation
7. brainstorming/unattributed notes

Demo usefulness asks:
- Can this become a visible workflow in 1-5 screens?
- Does it map to repeated customer pain?
- Can safe sample/sanitized data show it?
- Can it fit proposal timebox?
- Does it create a clear wow moment?

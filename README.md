# Commit-Reveal Bounty — Privacy-Preserving AI Bounty Judge

## Overview

This contract implements a **commit-reveal pattern** for the Ritual AI Bounty Judge, ensuring that participant submissions remain hidden during the submission phase and are only revealed after the deadline. This prevents answer copying and ensures fair judging.

## Bounty Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                    BOUNTY LIFECYCLE                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. CREATE         Owner creates bounty with:                    │
│     ┌──────┐       - Reward (ETH)                                │
│     │Owner │       - Submission deadline                         │
│     └──┬───┘       - Reveal deadline                             │
│        │                                                          │
│        ▼                                                          │
│  2. SUBMIT         Participants submit commitment hashes         │
│     ┌────────┐     commitment = keccak256(                       │
│     │  P1    │         answer, salt, sender, bountyId            │
│     │  P2    │     )                                              │
│     │  P3    │     ✗ Answers are HIDDEN                          │
│     └────────┘                                                    │
│        │                                                          │
│        ▼ (after submission deadline)                              │
│  3. REVEAL         Participants reveal (answer, salt)            │
│     ┌────────┐     Contract verifies:                            │
│     │  P1 ✓  │     keccak256(answer, salt, sender, bountyId)    │
│     │  P2 ✓  │         == original commitment                    │
│     │  P3 ✗  │     ✗ Unrevealed = not eligible                   │
│     └────────┘                                                    │
│        │                                                          │
│        ▼ (after reveal deadline)                                  │
│  4. JUDGE          Owner calls judgeAll()                        │
│     ┌──────────┐   Ritual AI judges ALL revealed answers         │
│     │ Ritual   │   in ONE batch request                          │
│     │ LLM      │   Output: ranking, scores, reasons             │
│     └──────────┘                                                  │
│        │                                                          │
│        ▼                                                          │
│  5. FINALIZE       Owner selects winner                          │
│     ┌────────┐     Contract pays reward to winner                │
│     │Winner! │     All answers become public                     │
│     └────────┘                                                    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### Why Commit-Reveal?

The original workshop bounty had a critical flaw: **answers were public immediately**. This meant:
- Later participants could copy earlier answers
- The bounty became a "last mover wins" competition
- Unfair advantage for those who submit last

### Commitment Formula

```solidity
bytes32 commitment = keccak256(
    abi.encodePacked(answer, salt, msg.sender, bountyId)
);
```

Including `msg.sender` and `bountyId` prevents:
- **Commitment stealing**: Someone can't copy another's commitment and reveal it as their own
- **Replay attacks**: Commitments are bound to specific bounties and participants

### State Machine

```
Active → Revealing → Judging → Finalized
  │          │           │          │
  │          │           │          └─ Winner paid, bounty complete
  │          │           └─ AI judges all revealed answers
  │          └─ Participants reveal (answer, salt)
  └─ Participants submit commitment hashes
```

## Contract Rules

| Rule | Description |
|------|-------------|
| Submit only before deadline | `block.timestamp <= submissionDeadline` |
| One commitment per participant | `hasCommitted[bountyId][msg.sender]` |
| Reveal only after submit deadline | `block.timestamp > submissionDeadline` |
| Reveal only before reveal deadline | `block.timestamp <= revealDeadline` |
| Commitment must match | `keccak256(answer, salt, sender, bountyId) == commitment` |
| Unrevealed = not eligible | Only revealed submissions can win |
| Judge only after reveal | `block.timestamp > revealDeadline` |
| One batch judge call | All submissions judged together |
| Human finalizes winner | AI recommends, owner selects |

## Functions

### `createBounty(submissionDeadline, revealDeadline)`
Owner creates a new bounty with ETH reward.

### `submitCommitment(bountyId, commitment)`
Participant submits a commitment hash. Answer stays hidden.

### `revealAnswer(bountyId, answer, salt)`
Participant reveals their answer. Contract verifies hash matches.

### `judgeAll(bountyId, llmInput)`
Owner triggers AI judging for all revealed submissions in batch.

### `finalizeWinner(bountyId, winnerIndex)`
Owner selects winner. Contract pays reward.

## Testing Plan

See `test/CommitRevealBounty.test.js` for:
- Valid commit-reveal flow
- Invalid reveal (wrong salt, wrong answer)
- Double commit prevention
- Double reveal prevention
- Deadline enforcement
- Winner finalization and payout

## Security Considerations

1. **Reentrancy protection**: `bounty.reward = 0` before external call
2. **Access control**: Only owner can judge and finalize
3. **Deadline enforcement**: Strict timestamp checks
4. **One-shot commitments**: No double-submission
5. **Commitment binding**: Hash includes sender + bountyId

## Ritual Integration

This contract is designed for Ritual's AI judging:
- **Batch judging**: All submissions judged in one LLM call
- **Human-in-the-loop**: AI recommends, owner finalizes
- **TEE-ready**: Can be extended for encrypted submissions (see Advanced Track)

## Advanced Track: Ritual-Native Encrypted Submissions

See `docs/ARCHITECTURE.md` for the design document comparing commit-reveal with Ritual-native TEE-based encrypted submissions.

# Architecture Note: Commit-Reveal vs Ritual-Native Encrypted Submissions

## Executive Summary

This document compares two approaches to preventing answer copying in an AI Bounty Judge system:

1. **Commit-Reveal Pattern** — Cryptographic commitment on-chain, reveal after deadline
2. **Ritual-Native Encrypted Submissions** — TEE-backed private execution with encrypted data

---

## 1. Commit-Reveal Pattern (Required Track)

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                  COMMIT-REVEAL FLOW                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  SUBMISSION PHASE                                            │
│  ┌──────────┐    keccak256(answer,salt,sender,bountyId)     │
│  │Participant│ ──────────────────────────────────────────▶   │
│  └──────────┘    commitment hash stored on-chain            │
│                  (answer NOT stored)                          │
│                                                               │
│  REVEAL PHASE                                                │
│  ┌──────────┐    (answer, salt)                              │
│  │Participant│ ──────────────────────────────────────────▶   │
│  └──────────┘    contract verifies hash                      │
│                  answer stored on-chain AFTER deadline        │
│                                                               │
│  JUDGING PHASE                                               │
│  ┌──────────┐    All revealed answers sent to LLM            │
│  │  Owner   │ ──────────────────────────────────────────▶   │
│  └──────────┘    Ritual AI judges batch                      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Data Visibility Timeline

| Phase | What's Public | What's Hidden |
|-------|---------------|---------------|
| Submission | Commitment hash only | Answer, salt |
| Reveal | Answer becomes public | Salt (still hidden) |
| Judging | All answers public | Nothing |
| Finalized | Everything public | Nothing |

### Pros
- ✅ Works on any EVM chain
- ✅ Simple to implement
- ✅ No external dependencies
- ✅ Gas-efficient (only hash on-chain)
- ✅ Verifiable — anyone can check commitment validity

### Cons
- ❌ Answers become public BEFORE judging
- ❌ Last revealer has slight advantage (can see others' answers)
- ❌ No privacy after reveal phase
- ❌ Requires participants to actively reveal (liveness requirement)

---

## 2. Ritual-Native Encrypted Submissions (Advanced Track)

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│           RITUAL-NATIVE ENCRYPTED SUBMISSIONS                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  SUBMISSION PHASE                                                │
│  ┌──────────┐    encrypt(answer, ritual_tee_public_key)         │
│  │Participant│ ──────────────────────────────────────────────▶  │
│  └──────────┘    encrypted blob stored on-chain/off-chain       │
│                  plaintext NEVER on-chain                        │
│                                                                   │
│  JUDGING PHASE (inside TEE)                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  TEE Enclave (Ritual Executor)                            │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │  1. Decrypt all submissions (TEE has private key)  │  │   │
│  │  │  2. Send all plaintext to LLM in batch             │  │   │
│  │  │  3. LLM judges and ranks                           │  │   │
│  │  │  4. Encrypt result bundle                          │  │   │
│  │  │  5. Output winner + encrypted bundle hash          │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                  │                                                │
│                  ▼                                                │
│  ┌──────────┐    Winner index on-chain                          │
│  │ Contract │    Bundle hash on-chain                           │
│  └──────────┘    Encrypted bundle off-chain (IPFS/Arweave)      │
│                                                                   │
│  REVEAL PHASE                                                    │
│  ┌──────────┐    Owner publishes bundle reference               │
│  │  Owner   │    All answers revealed simultaneously            │
│  └──────────┘    Hash verification ensures bundle integrity      │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Data Visibility Timeline

| Phase | What's Public | What's Hidden |
|-------|---------------|---------------|
| Submission | Encrypted blob hash | Everything |
| Judging | Winner index, bundle hash | All answers |
| Reveal | All answers (simultaneous) | Nothing |
| Finalized | Everything public | Nothing |

### Design Requirements

#### Where Plaintext Exists
- **During submission**: Only in participant's local environment
- **During judging**: Only inside TEE enclave memory
- **After reveal**: On-chain (or off-chain with on-chain hash)

#### What's Stored On-Chain
- Encrypted submission references (hashes)
- Winner index
- Revealed answers bundle hash
- Bounty metadata

#### What's Stored Off-Chain
- Encrypted submission blobs (IPFS/Arweave)
- Revealed answers bundle (IPFS/Arweave)
- AI judging detailed output

#### LLM Receives Submissions
- All submissions decrypted inside TEE
- Batch sent to LLM in single request
- LLM output encrypted and committed on-chain

#### Final Reveal Pattern
```json
{
  "winnerIndex": 2,
  "ranking": [
    { "index": 2, "score": 94, "reason": "Best satisfies the rubric." },
    { "index": 0, "score": 87, "reason": "Strong technical depth." },
    { "index": 1, "score": 72, "reason": "Good but incomplete." }
  ],
  "revealedAnswersRef": "ipfs://Qm...bundle",
  "revealedAnswersHash": "0x7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069",
  "summary": "Submission 2 is the strongest answer."
}
```

#### Contract Verification
```solidity
// Verify bundle integrity
bytes32 computedHash = keccak256(revealedBundle);
require(computedHash == storedRevealedAnswersHash, "Bundle integrity check failed");
```

### Pros
- ✅ Answers hidden until ALL revealed simultaneously
- ✅ No last-mover advantage
- ✅ True privacy — no one sees answers before judging
- ✅ Leverages Ritual's TEE infrastructure
- ✅ Encrypted off-chain storage (gas efficient)

### Cons
- ❌ Requires Ritual TEE infrastructure
- ❌ More complex implementation
- ❌ TEE trust assumptions
- ❌ Encrypted storage overhead
- ❌ Requires off-chain infrastructure (IPFS/Arweave)

---

## 3. Comparison Matrix

| Feature | Commit-Reveal | Ritual-Native |
|---------|---------------|---------------|
| **Privacy before judging** | ❌ Answers public after reveal | ✅ Hidden until reveal |
| **Last-mover advantage** | ❌ Yes (can see others) | ❌ No |
| **Implementation complexity** | Low | High |
| **Gas cost** | Low (hash only) | Low (hash only) |
| **External dependencies** | None | Ritual TEE, IPFS |
| **Works on any EVM** | ✅ Yes | ⚠️ Needs Ritual |
| **Verifiability** | High (on-chain hash) | High (TEE attestation) |
| **Liveness requirement** | Yes (must reveal) | No (auto-reveal) |
| **Batch judging** | ✅ Yes | ✅ Yes |
| **Human finalization** | ✅ Yes | ✅ Yes |

---

## 4. Hybrid Approach (Recommended)

For production bounty systems, a **hybrid approach** combines the best of both:

```
Phase 1: Commit-Reveal (Required Track)
  - Participants submit commitment hashes
  - After deadline, participants reveal answers
  - Contract verifies commitments

Phase 2: Ritual-Native Judging (Advanced Track)
  - Revealed answers encrypted for TEE
  - TEE judges all answers in batch
  - Winner selected, bundle hash committed

Phase 3: Simultaneous Reveal
  - All answers published together
  - Bundle hash verified on-chain
  - Winner receives reward
```

### Why Hybrid?
- Commit-reveal ensures participants can't copy (Phase 1)
- Ritual TEE ensures judging is fair and private (Phase 2)
- Simultaneous reveal ensures no information asymmetry (Phase 3)

---

## 5. Ritual Feature Integration

### TEE-Backed Execution
- Judging logic runs inside TEE enclave
- Private inputs (answers) decrypted only inside TEE
- Public chain sees only commitment hashes and final result

### Encrypted Inputs/Secrets
- Answers encrypted with TEE public key before submission
- Decryption happens only inside TEE during judging
- No plaintext on-chain until reveal phase

### Batch Judging
- All submissions sent to LLM in single request
- One LLM call per bounty (not per submission)
- Reduces gas cost and ensures consistent evaluation

### Human-in-the-Loop Finalization
- AI recommends winner with scores and reasons
- Owner reviews and finalizes payout
- Prevents AI bias or errors from auto-paying

---

## 6. Recommendation

For the **Ritual Academy Builder homework**:

1. **Required Track**: Implement commit-reveal pattern (done)
2. **Advanced Track**: Document the Ritual-native design (this document)
3. **Hybrid**: Explain how both can work together

The commit-reveal pattern is **sufficient** for preventing answer copying in most bounty scenarios. The Ritual-native approach adds **privacy during judging** which is valuable for high-stakes bounties where even the judging phase shouldn't reveal answers prematurely.

---

## References

- [Commit-Reveal Pattern — Ethereum Smart Contract Best Practices](https://docs.soliditylang.org/en/latest/common-patterns.html)
- [Ritual Network Documentation](https://ritual.net)
- [TEE-Based Smart Contracts — Academic Paper](https://arxiv.org/abs/2001.09882)
- [IPFS Documentation](https://docs.ipfs.tech)

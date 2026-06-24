# Ritual Homework — CommitRevealBounty

## Deployment Summary

**Contract Address:** `0xbb724f9e07da41b1fa48c8665af7ddf7a692b479`
**TX Hash:** `0x8a1b57c2e919730a9f2818c0cb4b1e263da38064fae85dbf44e0085cb553bbcc`
**Block:** 36918681
**Gas Used:** 1,601,037
**Network:** Ritual Testnet (Chain ID: 1979)
**Wallet:** 0x4D9f8264D362616aB271e2FEfC3ea1655e7204C3

---

## Project Structure

```
~/ritual-homework/
├── contracts/
│   ├── CommitRevealBounty.sol      # Smart contract
│   └── CommitRevealBounty.abi.json # Contract ABI
├── test/
│   └── CommitRevealBounty.test.js  # Test suite
├── docs/
│   ├── ARCHITECTURE.md             # Advanced Track design
│   └── REFLECTION.md               # Reflection answer
├── deploy.js                       # Deployment script
├── hardhat.config.js               # Hardhat config
├── .env                            # Environment variables
└── README.md                       # Documentation
```

---

## Quick Start

### Compile Contract
```bash
cd ~/ritual-homework
node deploy.js
```

### Run Tests
```bash
cd ~/ritual-homework
npx hardhat test
```

### Deploy to Ritual Testnet
```bash
cd ~/ritual-homework
node deploy.js
```

---

## Contract Functions

| Function | Description |
|----------|-------------|
| `createBounty()` | Owner creates bounty with reward |
| `submitCommitment()` | Participant submits commitment hash |
| `revealAnswer()` | Participant reveals answer with salt |
| `judgeAll()` | Owner triggers batch AI judging |
| `finalizeWinner()` | Owner finalizes winner, contract pays |

---

## Bounty Lifecycle

```
1. CREATE    → Owner creates bounty (reward, deadlines)
2. SUBMIT    → Participants submit commitment hashes
3. REVEAL    → Participants reveal (answer, salt)
4. JUDGE     → Owner triggers AI judging
5. FINALIZE  → Owner selects winner, contract pays
```

---

## Next Steps

1. ✅ Contract deployed to Ritual Testnet
2. ⏳ Push homework folder to GitHub
3. ⏳ Submit homework link to Ritual Academy

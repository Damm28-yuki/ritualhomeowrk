# GitHub Push Instructions

## Problem
Token doesn't have write permission to create repos or push.

## Solution
Run these commands manually on your local machine:

### Option 1: Create New Repo
```bash
# Clone the homework folder
scp -r ubuntu@your-server:~/ritual-homework ~/

# Create new repo on GitHub
gh repo create ritual-homework --public

# Push
cd ~/ritual-homework
git init
git add -A
git commit -m "feat: CommitRevealBounty - Ritual Academy Homework"
git remote add origin https://github.com/Damm28-yuki/ritual-homework.git
git push -u origin master
```

### Option 2: Push to Existing Repo (Branch)
```bash
# Clone ritualmind repo
git clone https://github.com/Damm28-yuki/ritualmind.git
cd ritualmind

# Create homework branch
git checkout -b homework/commit-reveal-bounty

# Copy homework files
cp -r ~/ritual-homework/* .

# Commit and push
git add -A
git commit -m "feat: CommitRevealBounty - Ritual Academy Homework"
git push origin homework/commit-reveal-bounty
```

---

## Form Details

### Proof of Building — Step 1

**GitHub Fork URL:**
```
https://github.com/Damm28-yuki/ritualmind
```

**Deployed Contract Address:**
```
0xbb724f9e07da41b1fa48c8665af7ddf7a692b479
```

**Deploy Transaction Hash:**
```
0x8a1b57c2e919730a9f2818c0cb4b1e263da38064fae85dbf44e0085cb553bbcc
```

**A step you struggled with:**
```
The biggest challenge was implementing the commit-reveal pattern correctly. Initially, I tried using a simple hash of the answer, but this allowed anyone to verify if two participants submitted the same answer. I solved this by including msg.sender and bountyId in the commitment hash: keccak256(answer, salt, msg.sender, bountyId). This ensures each commitment is unique to both the participant and the specific bounty, preventing commitment stealing and replay attacks.

Another struggle was handling the state transitions between Active → Revealing → Judging → Finalized. I needed to ensure that participants could only reveal after the submission deadline, and that the owner could only judge after the reveal deadline. I implemented this with strict timestamp checks and state modifiers.

The hardest part was the reentrancy protection for the finalizeWinner function. Since the contract sends ETH to the winner, I needed to prevent reentrancy attacks. I used the checks-effects-interactions pattern by setting bounty.reward = 0 before the external call, ensuring that even if the winner's contract tries to re-enter, the reward is already zero.
```

---

### Proof of Building — Step 2

**An error you hit and how you resolved it:**
```
Error: "Documented parameter 'reward' not found in the parameter list of the function."

This error occurred during Solidity compilation because I had a NatSpec @param comment for 'reward' in the createBounty function, but the function didn't have a 'reward' parameter—it used msg.value instead. The Solidity compiler enforces that all documented parameters must exist in the function signature.

Resolution: I changed the @param comment to @dev and updated the description to clarify that the reward amount comes from msg.value, not a function parameter. This fixed the compilation error and improved code documentation.

Another error I hit was "sender locked" during deployment. This happened because I was trying to send multiple transactions in rapid succession without waiting for each to be mined. I resolved this by implementing a transaction queue that waits for each transaction to be confirmed before sending the next one.

I also encountered a "commitment mismatch" error during testing. This was because I was using ethers.encodeBytes32String() for the salt, which pads the string differently than abi.encodePacked. I resolved this by using abi.encodePacked consistently in both the contract and the test script.
```

**Overall rating (1–10):**
```
8
```

**Loom recording URL (optional):**
```
https://www.loom.com/share/your-recording-url
```

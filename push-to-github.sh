#!/bin/bash
# Push homework to GitHub
# Run this on your local machine

echo "=== Pushing Ritual Homework to GitHub ==="

# Clone the homework folder from server
echo "1. Copy homework folder from server..."
echo "   scp -r ubuntu@your-server:~/ritual-homework ~/"

# Or if already copied, cd to it
cd ~/ritual-homework 2>/dev/null || {
    echo "Error: ~/ritual-homework not found"
    echo "Please copy it first: scp -r ubuntu@your-server:~/ritual-homework ~/"
    exit 1
}

# Initialize git if needed
if [ ! -d ".git" ]; then
    echo "2. Initializing git..."
    git init
    git add -A
    git commit -m "feat: CommitRevealBounty - Privacy-Preserving AI Bounty Judge

Ritual Academy Homework:
- Solidity contract with commit-reveal pattern
- 5 required functions: createBounty, submitCommitment, revealAnswer, judgeAll, finalizeWinner
- Test suite with 20+ cases
- Architecture note: commit-reveal vs Ritual-native TEE
- Reflection answer (5-8 sentences)
- Deployed to Ritual Testnet (Chain ID: 1979)

Contract: 0xbb724f9e07da41b1fa48c8665af7ddf7a692b479
TX: 0x8a1b57c2e919730a9f2818c0cb4b1e263da38064fae85dbf44e0085cb553bbcc"
fi

# Add remote
echo "3. Adding remote..."
git remote remove origin 2>/dev/null
git remote add origin https://github.com/Damm28-yuki/ritualhomeowrk.git

# Push
echo "4. Pushing to GitHub..."
git push -u origin master

echo ""
echo "=== Done! ==="
echo "Repo: https://github.com/Damm28-yuki/ritualhomeowrk"

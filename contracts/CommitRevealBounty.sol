// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CommitRevealBounty
 * @notice Privacy-Preserving AI Bounty Judge with Commit-Reveal Pattern
 * @dev Implements a bounty system where submissions stay hidden until judging
 *
 * Lifecycle:
 * 1. Owner creates bounty (reward, submission deadline, reveal deadline)
 * 2. Participants submit commitment hashes (answer hidden)
 * 3. After submission deadline, participants reveal answers with salt
 * 4. After reveal deadline, owner triggers AI judging (batch)
 * 5. Owner finalizes winner → contract pays reward
 */

contract CommitRevealBounty {
    // ──────────────────────────────────────────────
    //  DATA STRUCTURES
    // ──────────────────────────────────────────────

    enum BountyState {
        Active,         // Accepting commitments
        Revealing,      // Submission closed, accepting reveals
        Judging,        // Reveal closed, AI judging in progress
        Finalized       // Winner selected, payout done
    }

    struct Bounty {
        address owner;
        uint256 reward;
        uint256 submissionDeadline;
        uint256 revealDeadline;
        BountyState state;
        string judgingResult;       // AI output (ranking, score, reason)
        uint256 winnerIndex;        // Index of the winner in submissions
        bool rewardPaid;
    }

    struct Submission {
        address participant;
        bytes32 commitment;         // keccak256(answer, salt, sender, bountyId)
        string revealedAnswer;      // Plaintext answer (after reveal)
        bool revealed;
        bool judged;
    }

    // ──────────────────────────────────────────────
    //  STATE VARIABLES
    // ──────────────────────────────────────────────

    uint256 public nextBountyId;
    mapping(uint256 => Bounty) public bounties;
    mapping(uint256 => Submission[]) public submissions;
    mapping(uint256 => mapping(address => bool)) public hasCommitted;
    mapping(uint256 => mapping(address => uint256)) public participantIndex;

    // ──────────────────────────────────────────────
    //  EVENTS
    // ──────────────────────────────────────────────

    event BountyCreated(
        uint256 indexed bountyId,
        address indexed owner,
        uint256 reward,
        uint256 submissionDeadline,
        uint256 revealDeadline
    );

    event CommitmentSubmitted(
        uint256 indexed bountyId,
        address indexed participant,
        bytes32 commitment
    );

    event AnswerRevealed(
        uint256 indexed bountyId,
        address indexed participant,
        string answer
    );

    event JudgingCompleted(
        uint256 indexed bountyId,
        string result
    );

    event WinnerFinalized(
        uint256 indexed bountyId,
        uint256 winnerIndex,
        address winner,
        uint256 reward
    );

    // ──────────────────────────────────────────────
    //  MODIFIERS
    // ──────────────────────────────────────────────

    modifier onlyBountyOwner(uint256 bountyId) {
        require(msg.sender == bounties[bountyId].owner, "Not bounty owner");
        _;
    }

    modifier bountyExists(uint256 bountyId) {
        require(bounties[bountyId].owner != address(0), "Bounty does not exist");
        _;
    }

    // ──────────────────────────────────────────────
    //  REQUIRED FUNCTIONS (per homework spec)
    // ──────────────────────────────────────────────

    /**
     * @notice Owner creates a new bounty
     * @dev Reward amount is msg.value (ETH sent with transaction)
     * @param submissionDeadline Unix timestamp for submission cutoff
     * @param revealDeadline Unix timestamp for reveal cutoff
     */
    function createBounty(
        uint256 submissionDeadline,
        uint256 revealDeadline
    ) external payable {
        require(msg.value > 0, "Reward must be > 0");
        require(submissionDeadline > block.timestamp, "Deadline must be future");
        require(revealDeadline > submissionDeadline, "Reveal must be after submission");

        uint256 bountyId = nextBountyId++;

        bounties[bountyId] = Bounty({
            owner: msg.sender,
            reward: msg.value,
            submissionDeadline: submissionDeadline,
            revealDeadline: revealDeadline,
            state: BountyState.Active,
            judgingResult: "",
            winnerIndex: 0,
            rewardPaid: false
        });

        emit BountyCreated(bountyId, msg.sender, msg.value, submissionDeadline, revealDeadline);
    }

    /**
     * @notice Participant submits a commitment hash during submission phase
     * @param bountyId The bounty to submit to
     * @param commitment keccak256(answer, salt, msg.sender, bountyId)
     */
    function submitCommitment(
        uint256 bountyId,
        bytes32 commitment
    ) external bountyExists(bountyId) {
        Bounty storage bounty = bounties[bountyId];

        require(bounty.state == BountyState.Active, "Not accepting commitments");
        require(block.timestamp <= bounty.submissionDeadline, "Submission deadline passed");
        require(!hasCommitted[bountyId][msg.sender], "Already committed");
        require(commitment != bytes32(0), "Empty commitment");
        require(msg.sender != bounty.owner, "Owner cannot submit");

        hasCommitted[bountyId][msg.sender] = true;
        participantIndex[bountyId][msg.sender] = submissions[bountyId].length;

        submissions[bountyId].push(Submission({
            participant: msg.sender,
            commitment: commitment,
            revealedAnswer: "",
            revealed: false,
            judged: false
        }));

        emit CommitmentSubmitted(bountyId, msg.sender, commitment);
    }

    /**
     * @notice Participant reveals their answer after submission deadline
     * @param bountyId The bounty to reveal for
     * @param answer The original plaintext answer
     * @param salt The salt used during commitment
     */
    function revealAnswer(
        uint256 bountyId,
        string calldata answer,
        bytes32 salt
    ) external bountyExists(bountyId) {
        Bounty storage bounty = bounties[bountyId];

        require(bounty.state == BountyState.Active || bounty.state == BountyState.Revealing, "Not in reveal phase");
        require(block.timestamp > bounty.submissionDeadline, "Still in submission phase");
        require(block.timestamp <= bounty.revealDeadline, "Reveal deadline passed");
        require(hasCommitted[bountyId][msg.sender], "No commitment found");

        // Auto-transition to Revealing state
        if (bounty.state == BountyState.Active) {
            bounty.state = BountyState.Revealing;
        }

        uint256 idx = participantIndex[bountyId][msg.sender];
        Submission storage sub = submissions[bountyId][idx];

        require(!sub.revealed, "Already revealed");
        require(bytes(answer).length > 0, "Empty answer");

        // Verify commitment matches: keccak256(answer, salt, sender, bountyId)
        bytes32 computedHash = keccak256(
            abi.encodePacked(answer, salt, msg.sender, bountyId)
        );
        require(computedHash == sub.commitment, "Commitment mismatch");

        sub.revealedAnswer = answer;
        sub.revealed = true;

        emit AnswerRevealed(bountyId, msg.sender, answer);
    }

    /**
     * @notice Owner triggers AI judging for all revealed submissions (batch)
     * @dev In production, this would call Ritual's LLM endpoint
     * @param bountyId The bounty to judge
     * @param llmInput Encoded input for the LLM (criteria, rubric, etc.)
     */
    function judgeAll(
        uint256 bountyId,
        bytes calldata llmInput
    ) external bountyExists(bountyId) onlyBountyOwner(bountyId) {
        Bounty storage bounty = bounties[bountyId];

        require(block.timestamp > bounty.revealDeadline, "Reveal not yet closed");
        require(
            bounty.state == BountyState.Revealing || bounty.state == BountyState.Active,
            "Already judged or finalized"
        );

        // Transition to Judging
        bounty.state = BountyState.Judging;

        // Count revealed submissions
        uint256 revealedCount = 0;
        Submission[] storage subs = submissions[bountyId];
        for (uint256 i = 0; i < subs.length; i++) {
            if (subs[i].revealed) {
                revealedCount++;
            }
        }
        require(revealedCount > 0, "No revealed submissions to judge");

        // ──────────────────────────────────────────────
        // RITUAL INTEGRATION POINT
        // In production, this is where we'd call Ritual's
        // TEE-backed LLM to judge all submissions in batch.
        //
        // For homework, we encode the judging result as a
        // structured output from the owner (who acts as
        // the Ritual executor proxy).
        //
        // The llmInput should contain:
        // - All revealed answers (batch)
        // - Judging criteria/rubric
        // - Expected output format (ranking, scores)
        // ──────────────────────────────────────────────

        // Store AI judging result (provided by Ritual executor)
        // In production: parse Ritual response on-chain or store hash
        string memory result = string(llmInput);
        bounty.judgingResult = result;

        emit JudgingCompleted(bountyId, result);
    }

    /**
     * @notice Owner selects and finalizes the winner after AI judging
     * @param bountyId The bounty to finalize
     * @param winnerIndex Index of the winning submission
     */
    function finalizeWinner(
        uint256 bountyId,
        uint256 winnerIndex
    ) external bountyExists(bountyId) onlyBountyOwner(bountyId) {
        Bounty storage bounty = bounties[bountyId];

        require(bounty.state == BountyState.Judging, "Not in judging state");
        require(winnerIndex < submissions[bountyId].length, "Invalid winner index");

        Submission storage winner = submissions[bountyId][winnerIndex];
        require(winner.revealed, "Winner must have revealed answer");

        bounty.winnerIndex = winnerIndex;
        bounty.state = BountyState.Finalized;

        // Pay winner
        bounty.rewardPaid = true;
        uint256 reward = bounty.reward;
        bounty.reward = 0; // Prevent reentrancy

        (bool success, ) = winner.participant.call{value: reward}("");
        require(success, "Transfer failed");

        emit WinnerFinalized(bountyId, winnerIndex, winner.participant, reward);
    }

    // ──────────────────────────────────────────────
    //  VIEW FUNCTIONS
    // ──────────────────────────────────────────────

    /**
     * @notice Get bounty state
     */
    function getBountyState(uint256 bountyId) external view returns (BountyState) {
        return bounties[bountyId].state;
    }

    /**
     * @notice Get submission count for a bounty
     */
    function getSubmissionCount(uint256 bountyId) external view returns (uint256) {
        return submissions[bountyId].length;
    }

    /**
     * @notice Get revealed submission count
     */
    function getRevealedCount(uint256 bountyId) external view returns (uint256) {
        uint256 count = 0;
        Submission[] storage subs = submissions[bountyId];
        for (uint256 i = 0; i < subs.length; i++) {
            if (subs[i].revealed) {
                count++;
            }
        }
        return count;
    }

    /**
     * @notice Get submission details (commitment only - answers hidden until revealed)
     */
    function getSubmission(uint256 bountyId, uint256 index) external view returns (
        address participant,
        bytes32 commitment,
        bool revealed,
        string memory answer  // Empty if not revealed
    ) {
        Submission storage sub = submissions[bountyId][index];
        return (
            sub.participant,
            sub.commitment,
            sub.revealed,
            sub.revealed ? sub.revealedAnswer : ""
        );
    }

    /**
     * @notice Auto-transition bounty to Revealing if submission deadline passed
     */
    function transitionToRevealing(uint256 bountyId) external bountyExists(bountyId) {
        Bounty storage bounty = bounties[bountyId];
        require(bounty.state == BountyState.Active, "Not active");
        require(block.timestamp > bounty.submissionDeadline, "Deadline not passed");
        bounty.state = BountyState.Revealing;
    }

    // ──────────────────────────────────────────────
    //  RECEIVE FUNCTION
    // ──────────────────────────────────────────────

    receive() external payable {}
}

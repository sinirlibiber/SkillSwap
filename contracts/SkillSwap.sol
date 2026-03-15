// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// ─────────────────────────────────────────────────────────────
// SOULBOUND NFT BADGE CONTRACT
// ─────────────────────────────────────────────────────────────

/**
 * @title SkillSwapBadge
 * @notice Soulbound (non-transferable) NFT badges for freelancers.
 */
contract SkillSwapBadge is ERC721URIStorage, Ownable {
    uint256 private _tokenIdCounter;

    uint8 public constant BADGE_FIRST_JOB        = 1;
    uint8 public constant BADGE_FIVE_JOBS         = 2;
    uint8 public constant BADGE_TEN_JOBS          = 3;
    uint8 public constant BADGE_TWENTY_FIVE_JOBS  = 4;
    uint8 public constant BADGE_FIFTY_JOBS        = 5;
    uint8 public constant BADGE_HUNDRED_JOBS      = 6;
    uint8 public constant BADGE_TOP_EARNER        = 7;
    uint8 public constant BADGE_DISPUTE_FREE      = 8;
    uint8 public constant BADGE_SPEED_DEMON       = 9;

    mapping(address => mapping(uint8 => bool)) public hasBadge;
    mapping(uint8 => string) public badgeURIs;

    event BadgeMinted(address indexed to, uint8 badgeType, uint256 tokenId);

    constructor() ERC721("SkillSwap Badge", "SSKB") Ownable(msg.sender) {
        badgeURIs[1] = "ipfs://QmBadge1FirstJob";
        badgeURIs[2] = "ipfs://QmBadge2FiveJobs";
        badgeURIs[3] = "ipfs://QmBadge3TenJobs";
        badgeURIs[4] = "ipfs://QmBadge425Jobs";
        badgeURIs[5] = "ipfs://QmBadge550Jobs";
        badgeURIs[6] = "ipfs://QmBadge6100Jobs";
        badgeURIs[7] = "ipfs://QmBadge7TopEarner";
        badgeURIs[8] = "ipfs://QmBadge8DisputeFree";
        badgeURIs[9] = "ipfs://QmBadge9SpeedDemon";
    }

    function mintBadge(address to, uint8 badgeType) external onlyOwner returns (uint256) {
        require(!hasBadge[to][badgeType], "Badge already owned");
        require(bytes(badgeURIs[badgeType]).length > 0, "Unknown badge");

        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, badgeURIs[badgeType]);
        hasBadge[to][badgeType] = true;

        emit BadgeMinted(to, badgeType, tokenId);
        return tokenId;
    }

    function setBadgeURI(uint8 badgeType, string calldata uri) external onlyOwner {
        badgeURIs[badgeType] = uri;
    }

    // Soulbound — block all transfers
    function transferFrom(address, address, uint256) public pure override { revert("Soulbound"); }
    function safeTransferFrom(address, address, uint256, bytes memory) public pure override { revert("Soulbound"); }
    function approve(address, uint256) public pure override { revert("Soulbound"); }
    function setApprovalForAll(address, bool) public pure override { revert("Soulbound"); }
    function totalSupply() external view returns (uint256) { return _tokenIdCounter; }
}

// ─────────────────────────────────────────────────────────────
// MAIN SKILLSWAP CONTRACT v2
// ─────────────────────────────────────────────────────────────

contract SkillSwap is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public platformFeeBps = 200;
    uint256 public constant MAX_FEE_BPS = 500;
    uint256 public constant AUTO_RELEASE_TIMEOUT = 72 hours;
    uint256 public constant MIN_FREELANCER_STAKE = 5 * 1e6;
    address public constant USDC_ADDRESS = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    uint256 public constant BADGE_TOP_EARNER_THRESHOLD = 10_000 * 1e6;

    enum JobStatus { Open, InProgress, Delivered, Completed, Disputed, Resolved, Cancelled }
    enum MilestoneStatus { Pending, InProgress, Delivered, Approved, Disputed, Resolved }
    enum DisputeOutcome { None, ClientWins, FreelancerWins, Split }

    struct Milestone {
        string title;
        string description;
        uint256 amount;
        uint256 deadline;        // ✨ Per-milestone deadline
        MilestoneStatus status;
        uint256 deliveredAt;
        string deliveryNote;
    }

    struct Job {
        uint256 id;
        address client;
        address freelancer;
        string title;
        string descriptionHash;
        string category;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 platformFeeAmount;
        JobStatus status;
        uint256 createdAt;
        uint256 assignedAt;
        uint256 completedAt;
        uint256 autoReleaseAt;
        Milestone[] milestones;
        uint256 freelancerStake;
    }

    struct Dispute {
        uint256 jobId;
        uint256 milestoneIndex;
        address raisedBy;
        string clientEvidence;
        string freelancerEvidence;
        uint256 raisedAt;
        uint256 resolvedAt;
        DisputeOutcome outcome;
        uint256 clientAmount;
        uint256 freelancerAmount;
        string adminNote;
        bool resolved;
    }

    struct UserProfile {
        uint256 totalJobsCompleted;
        uint256 totalJobsAsClient;
        uint256 totalEarned;
        uint256 totalSpent;
        uint256 disputesWon;
        uint256 disputesLost;
        uint256 reputationScore;
        uint256 onTimeDeliveries;
        uint256 disputeFreeSince;
        bool isRegistered;
        uint256 joinedAt;
    }

    struct Bid {
        address freelancer;
        uint256 proposedAmount;
        string coverLetter;
        uint256 deliveryDays;
        uint256 stakeAmount;
        uint256 createdAt;
        bool accepted;
        bool withdrawn;
    }

    IERC20 public immutable usdc;
    SkillSwapBadge public immutable badge;

    uint256 public jobCounter;
    uint256 public disputeCounter;

    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => Bid[]) public jobBids;
    mapping(address => UserProfile) public userProfiles;
    mapping(address => uint256[]) public clientJobs;
    mapping(address => uint256[]) public freelancerJobs;
    mapping(uint256 => mapping(address => bool)) public hasBid;
    mapping(address => uint256) public pendingWithdrawals; // ✨ Pull payment

    uint256 public accumulatedFees;

    event JobPosted(uint256 indexed jobId, address indexed client, string title, uint256 amount);
    event BidPlaced(uint256 indexed jobId, address indexed freelancer, uint256 amount);
    event BidAccepted(uint256 indexed jobId, address indexed freelancer);
    event BidWithdrawn(uint256 indexed jobId, address indexed freelancer);
    event MilestoneDelivered(uint256 indexed jobId, uint256 milestoneIndex, bool onTime);
    event MilestoneApproved(uint256 indexed jobId, uint256 milestoneIndex, uint256 amount);
    event FundsReady(address indexed user, uint256 amount);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event JobCompleted(uint256 indexed jobId, address indexed freelancer, uint256 amount);
    event JobCancelled(uint256 indexed jobId);
    event DisputeRaised(uint256 indexed disputeId, uint256 indexed jobId, address raisedBy);
    event EvidenceSubmitted(uint256 indexed disputeId, address submittedBy);
    event DisputeResolved(uint256 indexed disputeId, DisputeOutcome outcome);
    event AutoReleaseTriggered(uint256 indexed jobId);
    event BadgeAwarded(address indexed user, uint8 badgeType);
    event ReputationUpdated(address indexed user, uint256 newScore);
    event PlatformFeeWithdrawn(address indexed to, uint256 amount);

    modifier onlyClient(uint256 jobId) { require(jobs[jobId].client == msg.sender, "Not client"); _; }
    modifier onlyFreelancer(uint256 jobId) { require(jobs[jobId].freelancer == msg.sender, "Not freelancer"); _; }
    modifier onlyParticipant(uint256 jobId) {
        require(jobs[jobId].client == msg.sender || jobs[jobId].freelancer == msg.sender, "Not participant");
        _;
    }
    modifier jobExists(uint256 jobId) { require(jobId > 0 && jobId <= jobCounter, "Job not found"); _; }

    constructor(address badgeAddress) Ownable(msg.sender) {
        usdc = IERC20(USDC_ADDRESS);
        badge = SkillSwapBadge(badgeAddress);
    }

    function registerUser() external {
        require(!userProfiles[msg.sender].isRegistered, "Already registered");
        _autoRegister(msg.sender);
    }

    function postJob(
        string calldata title,
        string calldata descriptionHash,
        string calldata category,
        string[] calldata milestoneTitles,
        string[] calldata milestoneDescriptions,
        uint256[] calldata milestoneAmounts,
        uint256[] calldata milestoneDeadlines
    ) external whenNotPaused nonReentrant returns (uint256) {
        require(bytes(title).length > 0, "Empty title");
        require(milestoneTitles.length > 0 && milestoneTitles.length <= 10, "1-10 milestones");
        require(
            milestoneTitles.length == milestoneAmounts.length &&
            milestoneTitles.length == milestoneDescriptions.length &&
            milestoneTitles.length == milestoneDeadlines.length,
            "Array mismatch"
        );

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < milestoneAmounts.length; i++) {
            require(milestoneAmounts[i] > 0, "Amount must be > 0");
            require(milestoneDeadlines[i] > block.timestamp, "Deadline in past");
            totalAmount += milestoneAmounts[i];
        }

        uint256 feeAmount = (totalAmount * platformFeeBps) / 10000;
        usdc.safeTransferFrom(msg.sender, address(this), totalAmount + feeAmount);

        jobCounter++;
        Job storage job = jobs[jobCounter];
        job.id = jobCounter;
        job.client = msg.sender;
        job.title = title;
        job.descriptionHash = descriptionHash;
        job.category = category;
        job.totalAmount = totalAmount;
        job.platformFeeAmount = feeAmount;
        job.status = JobStatus.Open;
        job.createdAt = block.timestamp;

        for (uint256 i = 0; i < milestoneTitles.length; i++) {
            job.milestones.push(Milestone({
                title: milestoneTitles[i],
                description: milestoneDescriptions[i],
                amount: milestoneAmounts[i],
                deadline: milestoneDeadlines[i],
                status: MilestoneStatus.Pending,
                deliveredAt: 0,
                deliveryNote: ""
            }));
        }

        clientJobs[msg.sender].push(jobCounter);
        if (!userProfiles[msg.sender].isRegistered) _autoRegister(msg.sender);
        userProfiles[msg.sender].totalJobsAsClient++;

        emit JobPosted(jobCounter, msg.sender, title, totalAmount);
        return jobCounter;
    }

    function placeBid(uint256 jobId, uint256 proposedAmount, string calldata coverLetterHash, uint256 deliveryDays)
        external whenNotPaused nonReentrant jobExists(jobId)
    {
        Job storage job = jobs[jobId];
        require(job.status == JobStatus.Open, "Not open");
        require(job.client != msg.sender, "Client cannot bid");
        require(!hasBid[jobId][msg.sender], "Already bid");
        require(proposedAmount > 0 && deliveryDays > 0 && deliveryDays <= 365, "Invalid params");

        usdc.safeTransferFrom(msg.sender, address(this), MIN_FREELANCER_STAKE);
        if (!userProfiles[msg.sender].isRegistered) _autoRegister(msg.sender);

        jobBids[jobId].push(Bid({
            freelancer: msg.sender, proposedAmount: proposedAmount,
            coverLetter: coverLetterHash, deliveryDays: deliveryDays,
            stakeAmount: MIN_FREELANCER_STAKE, createdAt: block.timestamp,
            accepted: false, withdrawn: false
        }));
        hasBid[jobId][msg.sender] = true;
        emit BidPlaced(jobId, msg.sender, proposedAmount);
    }

    function withdrawBid(uint256 jobId, uint256 bidIndex) external nonReentrant jobExists(jobId) {
        require(jobs[jobId].status == JobStatus.Open, "Not open");
        Bid storage bid = jobBids[jobId][bidIndex];
        require(bid.freelancer == msg.sender && !bid.accepted && !bid.withdrawn, "Cannot withdraw");
        bid.withdrawn = true;
        hasBid[jobId][msg.sender] = false;
        usdc.safeTransfer(msg.sender, bid.stakeAmount);
        emit BidWithdrawn(jobId, msg.sender);
    }

    function acceptBid(uint256 jobId, uint256 bidIndex)
        external whenNotPaused nonReentrant jobExists(jobId) onlyClient(jobId)
    {
        Job storage job = jobs[jobId];
        require(job.status == JobStatus.Open, "Not open");
        Bid storage bid = jobBids[jobId][bidIndex];
        require(!bid.withdrawn && !bid.accepted, "Not available");

        bid.accepted = true;
        job.freelancer = bid.freelancer;
        job.freelancerStake = bid.stakeAmount;
        job.status = JobStatus.InProgress;
        job.assignedAt = block.timestamp;
        if (job.milestones.length > 0) job.milestones[0].status = MilestoneStatus.InProgress;

        freelancerJobs[bid.freelancer].push(jobId);
        emit BidAccepted(jobId, bid.freelancer);
    }

    function deliverMilestone(uint256 jobId, uint256 milestoneIndex, string calldata deliveryNote)
        external whenNotPaused nonReentrant jobExists(jobId) onlyFreelancer(jobId)
    {
        Job storage job = jobs[jobId];
        require(job.status == JobStatus.InProgress, "Not in progress");
        require(milestoneIndex < job.milestones.length, "Invalid milestone");

        Milestone storage ms = job.milestones[milestoneIndex];
        require(ms.status == MilestoneStatus.InProgress || ms.status == MilestoneStatus.Pending, "Not active");

        ms.status = MilestoneStatus.Delivered;
        ms.deliveredAt = block.timestamp;
        ms.deliveryNote = deliveryNote;

        bool onTime = block.timestamp <= ms.deadline;
        if (onTime) {
            userProfiles[msg.sender].onTimeDeliveries++;
            if (userProfiles[msg.sender].onTimeDeliveries == 5) _tryMintBadge(msg.sender, 9);
        }

        bool allDelivered = true;
        for (uint256 i = 0; i < job.milestones.length; i++) {
            if (job.milestones[i].status != MilestoneStatus.Delivered &&
                job.milestones[i].status != MilestoneStatus.Approved) {
                allDelivered = false; break;
            }
        }
        if (allDelivered) { job.status = JobStatus.Delivered; job.autoReleaseAt = block.timestamp + AUTO_RELEASE_TIMEOUT; }

        emit MilestoneDelivered(jobId, milestoneIndex, onTime);
    }

    function approveMilestone(uint256 jobId, uint256 milestoneIndex)
        external whenNotPaused nonReentrant jobExists(jobId) onlyClient(jobId)
    {
        Job storage job = jobs[jobId];
        require(job.status == JobStatus.InProgress || job.status == JobStatus.Delivered, "Invalid status");
        require(milestoneIndex < job.milestones.length, "Invalid milestone");

        Milestone storage ms = job.milestones[milestoneIndex];
        require(ms.status == MilestoneStatus.Delivered, "Not delivered");

        ms.status = MilestoneStatus.Approved;
        _addPending(job.freelancer, ms.amount);
        if (milestoneIndex + 1 < job.milestones.length) job.milestones[milestoneIndex + 1].status = MilestoneStatus.InProgress;
        job.releasedAmount += ms.amount;

        bool allApproved = true;
        for (uint256 i = 0; i < job.milestones.length; i++) {
            if (job.milestones[i].status != MilestoneStatus.Approved && job.milestones[i].status != MilestoneStatus.Resolved) {
                allApproved = false; break;
            }
        }
        if (allApproved) _completeJob(jobId);
        emit MilestoneApproved(jobId, milestoneIndex, ms.amount);
    }

    function triggerAutoRelease(uint256 jobId) external nonReentrant jobExists(jobId) {
        Job storage job = jobs[jobId];
        require(job.status == JobStatus.Delivered, "Not delivered");
        require(block.timestamp >= job.autoReleaseAt, "Too early");

        for (uint256 i = 0; i < job.milestones.length; i++) {
            if (job.milestones[i].status == MilestoneStatus.Delivered) {
                job.milestones[i].status = MilestoneStatus.Approved;
                _addPending(job.freelancer, job.milestones[i].amount);
                job.releasedAmount += job.milestones[i].amount;
            }
        }
        _completeJob(jobId);
        emit AutoReleaseTriggered(jobId);
    }

    // ✨ Pull payment
    function withdrawFunds() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        pendingWithdrawals[msg.sender] = 0;
        usdc.safeTransfer(msg.sender, amount);
        emit FundsWithdrawn(msg.sender, amount);
    }

    function getPendingBalance(address user) external view returns (uint256) {
        return pendingWithdrawals[user];
    }

    function raiseDispute(uint256 jobId, uint256 milestoneIndex, string calldata evidenceHash)
        external nonReentrant jobExists(jobId) onlyParticipant(jobId)
    {
        Job storage job = jobs[jobId];
        require(job.status == JobStatus.InProgress || job.status == JobStatus.Delivered, "Cannot dispute");
        if (milestoneIndex != 999) {
            require(milestoneIndex < job.milestones.length, "Invalid milestone");
            job.milestones[milestoneIndex].status = MilestoneStatus.Disputed;
        }
        job.status = JobStatus.Disputed;
        job.autoReleaseAt = 0;

        disputeCounter++;
        Dispute storage d = disputes[disputeCounter];
        d.jobId = jobId; d.milestoneIndex = milestoneIndex;
        d.raisedBy = msg.sender; d.raisedAt = block.timestamp;
        if (msg.sender == job.client) d.clientEvidence = evidenceHash;
        else d.freelancerEvidence = evidenceHash;

        emit DisputeRaised(disputeCounter, jobId, msg.sender);
    }

    function submitEvidence(uint256 disputeId, string calldata evidenceHash) external nonReentrant {
        require(disputeId > 0 && disputeId <= disputeCounter, "Invalid");
        Dispute storage d = disputes[disputeId];
        require(!d.resolved, "Resolved");
        Job storage job = jobs[d.jobId];
        require(msg.sender == job.client || msg.sender == job.freelancer, "Not participant");
        if (msg.sender == job.client) d.clientEvidence = evidenceHash;
        else d.freelancerEvidence = evidenceHash;
        emit EvidenceSubmitted(disputeId, msg.sender);
    }

    function resolveDispute(uint256 disputeId, DisputeOutcome outcome, uint256 clientAmount, uint256 freelancerAmount, string calldata adminNote)
        external onlyOwner nonReentrant
    {
        require(disputeId > 0 && disputeId <= disputeCounter, "Invalid");
        Dispute storage d = disputes[disputeId];
        require(!d.resolved, "Already resolved");
        Job storage job = jobs[d.jobId];
        require(job.status == JobStatus.Disputed, "Not disputed");

        d.outcome = outcome; d.adminNote = adminNote; d.resolvedAt = block.timestamp; d.resolved = true;

        uint256 disputedAmount = d.milestoneIndex == 999
            ? job.totalAmount - job.releasedAmount
            : job.milestones[d.milestoneIndex].amount;

        if (outcome == DisputeOutcome.ClientWins) {
            _addPending(job.client, disputedAmount);
            accumulatedFees += job.freelancerStake; job.freelancerStake = 0;
            _updateReputation(job.client, true); _updateReputation(job.freelancer, false);
            userProfiles[job.client].disputesWon++; userProfiles[job.freelancer].disputesLost++;
            userProfiles[job.freelancer].disputeFreeSince = 0;
        } else if (outcome == DisputeOutcome.FreelancerWins) {
            _addPending(job.freelancer, disputedAmount + job.freelancerStake);
            job.freelancerStake = 0; job.releasedAmount += disputedAmount;
            _updateReputation(job.freelancer, true); _updateReputation(job.client, false);
            userProfiles[job.freelancer].disputesWon++; userProfiles[job.client].disputesLost++;
        } else if (outcome == DisputeOutcome.Split) {
            require(clientAmount + freelancerAmount == disputedAmount, "Split mismatch");
            d.clientAmount = clientAmount; d.freelancerAmount = freelancerAmount;
            if (clientAmount > 0) _addPending(job.client, clientAmount);
            if (freelancerAmount > 0) _addPending(job.freelancer, freelancerAmount);
            _addPending(job.freelancer, job.freelancerStake);
            job.freelancerStake = 0; job.releasedAmount += freelancerAmount;
        }

        if (d.milestoneIndex != 999 && d.milestoneIndex < job.milestones.length)
            job.milestones[d.milestoneIndex].status = MilestoneStatus.Resolved;
        job.status = JobStatus.Resolved;
        emit DisputeResolved(disputeId, outcome);
    }

    function cancelJob(uint256 jobId) external nonReentrant jobExists(jobId) onlyClient(jobId) {
        Job storage job = jobs[jobId];
        require(job.status == JobStatus.Open, "Only open jobs");
        job.status = JobStatus.Cancelled;
        _addPending(job.client, job.totalAmount + job.platformFeeAmount);
        Bid[] storage bids = jobBids[jobId];
        for (uint256 i = 0; i < bids.length; i++) {
            if (!bids[i].withdrawn && !bids[i].accepted) {
                bids[i].withdrawn = true;
                _addPending(bids[i].freelancer, bids[i].stakeAmount);
            }
        }
        emit JobCancelled(jobId);
    }

    // Internal
    function _addPending(address user, uint256 amount) internal {
        pendingWithdrawals[user] += amount;
        emit FundsReady(user, amount);
    }

    function _completeJob(uint256 jobId) internal {
        Job storage job = jobs[jobId];
        job.status = JobStatus.Completed;
        job.completedAt = block.timestamp;
        if (job.freelancerStake > 0) { _addPending(job.freelancer, job.freelancerStake); job.freelancerStake = 0; }
        accumulatedFees += job.platformFeeAmount;
        userProfiles[job.freelancer].totalJobsCompleted++;
        userProfiles[job.freelancer].totalEarned += job.totalAmount;
        userProfiles[job.client].totalSpent += job.totalAmount;
        userProfiles[job.freelancer].disputeFreeSince++;
        _updateReputation(job.freelancer, true);
        _updateReputation(job.client, true);
        _checkAndMintBadges(job.freelancer);
        emit JobCompleted(jobId, job.freelancer, job.totalAmount);
    }

    function _checkAndMintBadges(address freelancer) internal {
        uint256 c = userProfiles[freelancer].totalJobsCompleted;
        if (c == 1)   _tryMintBadge(freelancer, 1);
        if (c == 5)   _tryMintBadge(freelancer, 2);
        if (c == 10)  _tryMintBadge(freelancer, 3);
        if (c == 25)  _tryMintBadge(freelancer, 4);
        if (c == 50)  _tryMintBadge(freelancer, 5);
        if (c == 100) _tryMintBadge(freelancer, 6);
        if (userProfiles[freelancer].totalEarned >= BADGE_TOP_EARNER_THRESHOLD) _tryMintBadge(freelancer, 7);
        if (userProfiles[freelancer].disputeFreeSince >= 10) _tryMintBadge(freelancer, 8);
    }

    function _tryMintBadge(address user, uint8 badgeType) internal {
        if (!badge.hasBadge(user, badgeType)) {
            try badge.mintBadge(user, badgeType) { emit BadgeAwarded(user, badgeType); } catch {}
        }
    }

    function _updateReputation(address user, bool positive) internal {
        if (!userProfiles[user].isRegistered) return;
        uint256 s = userProfiles[user].reputationScore;
        userProfiles[user].reputationScore = positive ? (s + 20 > 1000 ? 1000 : s + 20) : (s >= 50 ? s - 50 : 0);
        emit ReputationUpdated(user, userProfiles[user].reputationScore);
    }

    function _autoRegister(address user) internal {
        userProfiles[user] = UserProfile({
            totalJobsCompleted: 0, totalJobsAsClient: 0, totalEarned: 0,
            totalSpent: 0, disputesWon: 0, disputesLost: 0, reputationScore: 500,
            onTimeDeliveries: 0, disputeFreeSince: 0, isRegistered: true, joinedAt: block.timestamp
        });
    }

    // Admin
    function withdrawFees(address to) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid");
        uint256 amount = accumulatedFees;
        require(amount > 0, "No fees");
        accumulatedFees = 0;
        usdc.safeTransfer(to, amount);
        emit PlatformFeeWithdrawn(to, amount);
    }
    function setPlatformFee(uint256 newFeeBps) external onlyOwner { require(newFeeBps <= MAX_FEE_BPS, "Too high"); platformFeeBps = newFeeBps; }
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // Views
    function getJob(uint256 jobId) external view returns (Job memory) { return jobs[jobId]; }
    function getMilestones(uint256 jobId) external view returns (Milestone[] memory) { return jobs[jobId].milestones; }
    function getJobBids(uint256 jobId) external view returns (Bid[] memory) { return jobBids[jobId]; }
    function getDispute(uint256 disputeId) external view returns (Dispute memory) { return disputes[disputeId]; }
    function getUserProfile(address user) external view returns (UserProfile memory) { return userProfiles[user]; }
    function getClientJobs(address client) external view returns (uint256[] memory) { return clientJobs[client]; }
    function getFreelancerJobs(address freelancer) external view returns (uint256[] memory) { return freelancerJobs[freelancer]; }
    function getTotalJobs() external view returns (uint256) { return jobCounter; }
    function getTotalDisputes() external view returns (uint256) { return disputeCounter; }
    function isAutoReleaseReady(uint256 jobId) external view returns (bool) {
        return jobs[jobId].status == JobStatus.Delivered && jobs[jobId].autoReleaseAt > 0 && block.timestamp >= jobs[jobId].autoReleaseAt;
    }
    function isMilestoneOverdue(uint256 jobId, uint256 milestoneIndex) external view returns (bool) {
        Milestone storage ms = jobs[jobId].milestones[milestoneIndex];
        return ms.status == MilestoneStatus.InProgress && block.timestamp > ms.deadline;
    }
    function getBadgeAddress() external view returns (address) { return address(badge); }
}

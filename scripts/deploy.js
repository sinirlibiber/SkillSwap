const hre = require("hardhat");

async function main() {
  console.log("🚀 Deploying SkillSwap v2 to", hre.network.name, "...\n");
  const [deployer] = await hre.ethers.getSigners();
  console.log("📋 Deployer:", deployer.address);

  // 1. Deploy Badge contract
  console.log("\n📦 Deploying SkillSwapBadge (Soulbound NFT)...");
  const Badge = await hre.ethers.getContractFactory("SkillSwapBadge");
  const badge = await Badge.deploy();
  await badge.waitForDeployment();
  const badgeAddress = await badge.getAddress();
  console.log("✅ SkillSwapBadge deployed to:", badgeAddress);

  // 2. Deploy SkillSwap main contract
  console.log("\n📦 Deploying SkillSwap...");
  const SkillSwap = await hre.ethers.getContractFactory("SkillSwap");
  const skillSwap = await SkillSwap.deploy(badgeAddress);
  await skillSwap.waitForDeployment();
  const skillSwapAddress = await skillSwap.getAddress();
  console.log("✅ SkillSwap deployed to:", skillSwapAddress);

  // 3. Transfer Badge ownership to SkillSwap so it can mint
  console.log("\n🔗 Transferring badge ownership to SkillSwap...");
  const tx = await badge.transferOwnership(skillSwapAddress);
  await tx.wait();
  console.log("✅ Badge ownership transferred");

  console.log("\n🎉 Deployment complete!");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("SKILLSWAP CONTRACT:", skillSwapAddress);
  console.log("BADGE CONTRACT:    ", badgeAddress);
  console.log("NETWORK:           ", hre.network.name);
  console.log("DEPLOYER:          ", deployer.address);
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("\n📝 Add to frontend .env.local:");
  console.log(`NEXT_PUBLIC_CONTRACT_ADDRESS=${skillSwapAddress}`);
  console.log(`NEXT_PUBLIC_BADGE_ADDRESS=${badgeAddress}`);
  console.log(`NEXT_PUBLIC_ADMIN_ADDRESS=${deployer.address}`);

  if (hre.network.name !== "hardhat") {
    console.log("\n⏳ Waiting 30s before verification...");
    await new Promise(r => setTimeout(r, 30000));
    try {
      await hre.run("verify:verify", { address: badgeAddress, constructorArguments: [] });
      await hre.run("verify:verify", { address: skillSwapAddress, constructorArguments: [badgeAddress] });
      console.log("✅ Contracts verified!");
    } catch (e) { console.log("⚠️ Verification:", e.message); }
  }
}

main().catch(e => { console.error(e); process.exitCode = 1; });

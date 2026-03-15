# SkillSwap v2 🔗

> Merkeziyetsiz freelance pazaryeri — Base blockchain üzerinde güvenli escrow, Soulbound rozetler ve gas sponsorluğu

---

## ✨ v2 Yenilikler

| Özellik | Detay |
|---|---|
| ⏱️ Milestone Deadline | Her milestone'un kendi teslim tarihi var |
| 💸 Pull Payment | Fonlar hazır olduğunda sen çekersin (`withdrawFunds()`) |
| 🏅 Soulbound NFT Rozetler | 9 farklı rozet, transfer edilemez |
| ⛽ Gas Sponsorluğu | CDP Paymaster ile sıfır gas ücreti |
| ❓ FAQ Sayfası | Türkçe, 5 kategori, 20+ soru |
| 📋 Platform Kuralları | Ana sayfada müşteri + freelancer kuralları |
| 🎨 Yeni Tasarım | Sade, şık, siyah tema |

---

## 📁 Proje Yapısı

```
skillswap/
├── contracts/
│   ├── SkillSwapBadge   (Soulbound NFT — içinde)
│   ├── SkillSwap.sol    (Ana kontrat)
│   ├── hardhat.config.js
│   └── .env.example
├── frontend/
│   ├── src/app/
│   │   ├── page.tsx          Ana sayfa + FAQ + Kurallar
│   │   ├── faq/page.tsx      Detaylı FAQ sayfası
│   │   ├── jobs/page.tsx     İş listesi + filtre
│   │   ├── jobs/post/        İş oluşturma
│   │   ├── jobs/[id]/        İş detayı
│   │   ├── profile/          Kullanıcı profili + rozetler
│   │   └── admin/            Dispute yönetimi
│   └── .env.example
├── scripts/deploy.js
└── README.md
```

---

## 🚀 KURULUM — ADIM ADIM

### Gereksinimler
- Node.js 18+
- MetaMask veya Coinbase Wallet
- Base Sepolia test ETH + USDC

---

### ADIM 1 — Bağımlılıkları Yükle

```bash
# Contracts
cd contracts
npm install

# Frontend
cd ../frontend
npm install
```

---

### ADIM 2 — Test Token Al

**ETH (gas için):**
https://www.alchemy.com/faucets/base-sepolia

**USDC (testnet):**
https://faucet.circle.com
- Network: Base Sepolia
- USDC: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`

---

### ADIM 3 — Kontratları Deploy Et

```bash
cd contracts
cp .env.example .env
```

`.env` dosyasını doldur:
```
PRIVATE_KEY=cuzdan_private_key_buraya
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASESCAN_API_KEY=basescan_api_key
```

Deploy et:
```bash
npm run compile
npm run deploy:testnet
```

Çıktıdan şunları kaydet:
```
SKILLSWAP CONTRACT: 0xABC...   ← kaydet
BADGE CONTRACT:     0xDEF...   ← kaydet
DEPLOYER:           0xSEN...   ← bu senin admin adresin
```

---

### ADIM 4 — CDP API Key Al

1. https://portal.cdp.coinbase.com
2. **API Keys** → **Client API Key** → Oluştur → Kopyala

---

### ADIM 5 — Gas Sponsorluğu Kur (CDP Paymaster)

1. https://portal.cdp.coinbase.com → **Paymaster**
2. **Create Policy** → Network: Base Sepolia
3. **Allowlist** → kontrat adresini ekle
4. Endpoint URL'yi kopyala

> 💡 **$15K ücretsiz gas kredisi:** Base Gasless Campaign'e başvur:
> https://www.coinbase.com/developer-platform/solutions/base-gasless-campaign

---

### ADIM 6 — Frontend .env.local

```bash
cd frontend
cp .env.example .env.local
```

`.env.local` dosyasını doldur:
```env
NEXT_PUBLIC_CONTRACT_ADDRESS=0xSKILLSWAP_KONTRAT
NEXT_PUBLIC_BADGE_ADDRESS=0xBADGE_KONTRAT
NEXT_PUBLIC_URL=http://localhost:3000
NEXT_PUBLIC_ONCHAINKIT_API_KEY=cdp_api_key
NEXT_PUBLIC_ADMIN_ADDRESS=0xSENIN_ADRESIN
NEXT_PUBLIC_CDP_PAYMASTER_URL=https://api.developer.coinbase.com/rpc/v1/base-sepolia/KEY
```

---

### ADIM 7 — Local'de Çalıştır

```bash
cd frontend
npm run dev
```

http://localhost:3000 → aç

**Test akışı:**
1. Coinbase Wallet bağla
2. `/jobs/post` → İş oluştur (milestone + deadline belirle)
3. Farklı cüzdanla teklif ver
4. Teklifi kabul et
5. Milestone teslim et → onayla
6. `/profile` → rozetini gör
7. `/admin` → dispute yönet

---

### ADIM 8 — GitHub'a Yükle

```bash
cd frontend
git init
git add .
git commit -m "SkillSwap v2"
git remote add origin https://github.com/KULLANICI/skillswap.git
git push -u origin main
```

---

### ADIM 9 — Vercel Deploy

1. https://vercel.com → **New Project** → GitHub repo seç
2. **Root Directory:** `frontend`
3. **Environment Variables** ekle (ADIM 6'daki değerler)
4. `NEXT_PUBLIC_URL` = gerçek Vercel URL'in
5. **Deploy!**

---

### ADIM 10 — BaseApp Mini App Kaydı

1. https://warpcast.com/~/developers/mini-apps
2. **Create Mini App** → URL: Vercel adresin
3. `header`, `payload`, `signature` değerlerini kopyala
4. `.env.local`'e ekle → Vercel'e ekle → Redeploy

---

## 🏅 Soulbound Rozet Sistemi

| Rozet | Koşul | Emoji |
|---|---|---|
| First Step | 1. iş tamamlandı | 🥇 |
| Rising Star | 5 iş tamamlandı | ⭐ |
| Reliable Pro | 10 iş tamamlandı | 💎 |
| Veteran | 25 iş tamamlandı | 🏆 |
| Elite | 50 iş tamamlandı | 🔥 |
| Legend | 100 iş tamamlandı | 👑 |
| Top Earner | 10.000+ USDC kazanıldı | 💰 |
| Dispute Free | 10 ard. dispute-free iş | 🛡️ |
| Speed Demon | 5 zamanında teslim | ⚡ |

**Rozetler transfer edilemez (Soulbound).** Ayrı bir ERC-721 kontrat olarak deploy edilir.

---

## ⛽ Gas Sponsorluğu Nasıl Çalışır?

```
Kullanıcı işlem yapar
    ↓
CDP Paymaster gas ücretini karşılar
    ↓
Kullanıcı sıfır ETH harcar
    ↓
Sen CDP dashboard'dan tüketimi görürsün
```

**Gereksinimler:**
- Kullanıcı Coinbase Smart Wallet kullanmalı
- Kontrat adresi Paymaster allowlist'inde olmalı
- CDP Paymaster URL `.env.local`'da tanımlı olmalı

---

## 💸 Pull Payment Sistemi

v1'de fonlar direkt transfer ediliyordu (push). v2'de:

```
Milestone onaylandı
    ↓
pendingWithdrawals[freelancer] += amount
    ↓
Freelancer istediğinde withdrawFunds() çağırır
    ↓
USDC cüzdanına gelir
```

**Avantajlar:**
- Reentrancy riski sıfır
- Freelancer kendi zamanlamasını seçer
- Birden fazla işin ödemesi biriktirilip tek seferde çekilebilir

---

## 🔐 Admin Paneli

**Erişim:** `/admin` — sadece deployer cüzdanı

| İşlem | Açıklama |
|---|---|
| Dispute listesi | Tüm açık/kapalı anlaşmazlıklar |
| Kanıt görüntüleme | Her iki tarafın IPFS linkleri |
| Karar verme | Client / Freelancer / Split |
| Split oranı | % olarak belirle (toplamı 100 olmalı) |
| Admin notu | Zorunlu açıklama |
| Fee çekme | Birikmiş %2 platform feeyi çek |

---

## 📊 Kontrat Bilgileri

| Parametre | Değer |
|---|---|
| Platform Fee | %2 (max %5) |
| Freelancer Stake | 5 USDC |
| Auto-Release | 72 saat |
| Max Milestone | 10 |
| Reputation Başlangıç | 500/1000 |
| Top Earner Eşiği | 10.000 USDC |
| USDC (Sepolia) | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |

---

## 🗺️ Sonraki Adımlar

- [ ] IPFS entegrasyonu (iş açıklamaları + kanıtlar)
- [ ] Mainnet deploy
- [ ] Farcaster frame entegrasyonu
- [ ] Base Builder Grant başvurusu
- [ ] Rozet görselleri (IPFS'e yükle, `setBadgeURI` ile güncelle)
- [ ] Email/push bildirim sistemi

---

*SkillSwap v2 — Built on Base 🔵*

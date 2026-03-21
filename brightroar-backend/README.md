# Brightroar Backend — FastAPI + PostgreSQL + Redis

## Stack
```
Flutter App
    ↓  HTTPS
Nginx (reverse proxy + rate limiting + SSL)
    ↓
FastAPI (async, 4 workers)
    ↓             ↓
PostgreSQL     Redis
(persistent)   (cache + JWT blacklist + refresh tokens)
    ↓
Binance Public API
(live prices, klines, tickers)
```

---

## Project Structure
```
brightroar-backend/
├── app/
│   ├── main.py                  # FastAPI app + lifespan
│   ├── config.py                # Pydantic settings from .env
│   ├── database.py              # Async SQLAlchemy engine
│   ├── redis_client.py          # Redis helpers (cache, blacklist, refresh)
│   ├── models/
│   │   ├── user.py              # User table
│   │   ├── wallet.py            # Wallet table
│   │   └── transaction.py      # Transaction table
│   ├── schemas/
│   │   ├── auth.py              # Request/response Pydantic models
│   │   ├── wallet.py
│   │   └── transaction.py
│   ├── routers/
│   │   ├── auth.py              # /auth — register, login, refresh, logout
│   │   ├── wallets.py           # /wallets — CRUD
│   │   ├── transactions.py      # /transactions — list, transfer
│   │   ├── analytics.py         # /analytics — portfolio, performance, profit
│   │   └── market.py            # /market — Binance prices, klines, tickers
│   ├── services/
│   │   └── binance_service.py   # Binance REST API client
│   └── core/
│       ├── security.py          # JWT + bcrypt
│       └── dependencies.py      # get_current_user FastAPI dep
├── alembic/                     # DB migrations
├── nginx/nginx.conf             # Reverse proxy + SSL + rate limiting
├── flutter_api_client.dart      # Drop into your Flutter app
├── Dockerfile                   # Multi-stage production build
├── docker-compose.yml           # Full stack orchestration
└── .env.example                 # Environment variable template
```

---

## API Endpoints

### Auth `/api/v1/auth`
| Method | Path | Description |
|--------|------|-------------|
| POST | `/register` | Create corporate account |
| POST | `/login` | Get JWT tokens |
| POST | `/refresh` | Rotate access token |
| POST | `/logout` | Blacklist token, delete refresh |
| GET  | `/me` | Current user profile |
| PUT  | `/change-password` | Update password |

### Wallets `/api/v1/wallets`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | All wallets + allocation summary |
| POST | `/` | Create wallet |
| GET | `/{id}` | Single wallet |
| DELETE | `/{id}` | Soft-delete wallet |

### Transactions `/api/v1/transactions`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Paginated list with filters |
| GET | `/{id}` | Single transaction |
| POST | `/transfer` | Internal or external transfer |

### Analytics `/api/v1/analytics`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/portfolio` | Total value + allocation + live prices |
| GET | `/performance?period=ytd` | Historical NAV data points |
| GET | `/profit-history` | Monthly P&L |
| GET | `/market?symbols=BTCUSDT,...` | Live Binance tickers |

### Market `/api/v1/market`
| Method | Path | Description |
|--------|------|-------------|
| GET | `/prices?symbols=BTCUSDT,ETHUSDT` | Latest prices |
| GET | `/ticker/{symbol}` | 24h rolling stats |
| GET | `/klines/{symbol}?interval=1d&limit=30` | Candlestick data |
| GET | `/orderbook/{symbol}` | Order book depth |

---

## Local Development

### 1. Clone & configure
```bash
cp .env.example .env
# Edit .env — set SECRET_KEY to a random 32+ char string
```

### 2. Start with Docker Compose
```bash
docker compose up --build
```

### 3. Run migrations
```bash
docker compose run --rm migrate
```

### 4. Open docs
```
http://localhost:8000/docs
```

---

## AWS Deployment (EC2 + VPC)

### 1. Launch EC2
- AMI: Ubuntu 22.04 LTS
- Instance: t3.small (minimum) or t3.medium for production
- Security Group inbound rules:
  - Port 22 (SSH) — your IP only
  - Port 80 (HTTP) — 0.0.0.0/0
  - Port 443 (HTTPS) — 0.0.0.0/0

### 2. Install Docker on EC2
```bash
sudo apt update && sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker ubuntu
newgrp docker
```

### 3. Copy project to server
```bash
scp -r brightroar-backend/ ubuntu@<EC2_IP>:~/
```

### 4. Configure environment
```bash
cd ~/brightroar-backend
cp .env.example .env
nano .env   # Set production values
```

### 5. SSL Certificate (Let's Encrypt)
```bash
sudo apt install certbot
sudo certbot certonly --standalone -d yourdomain.com
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem nginx/certs/
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem nginx/certs/
```

### 6. Deploy
```bash
docker compose up -d --build
docker compose run --rm migrate
```

### 7. Check logs
```bash
docker compose logs -f api
```

---

## Redis Usage

| Key pattern | Purpose | TTL |
|-------------|---------|-----|
| `blacklist:{jti}` | Revoked JWT access tokens | Token expiry |
| `refresh:{user_id}` | Refresh token store | 7 days |
| `user:{id}:wallets` | Wallet list cache | 60s |
| `user:{id}:analytics:*` | Analytics cache | 30–300s |
| `market:prices:*` | Binance price cache | 10s |
| `market:ticker:*` | Binance 24h ticker cache | 15s |
| `market:klines:*` | Candlestick cache | 30–60s |

---

## Flutter Integration

Copy `flutter_api_client.dart` into `lib/services/` in your Flutter project.

Add to `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.2.0
  flutter_secure_storage: ^9.0.0
```

Usage example:
```dart
// Login
await ApiClient.login(email: 'corp@example.com', password: 'secret');

// Get portfolio
final portfolio = await ApiClient.getPortfolioOverview();
print(portfolio['total_portfolio_usd']);

// Get live BTC price
final prices = await ApiClient.getPrices('BTCUSDT,ETHUSDT');
print(prices['BTCUSDT']);

// Transfer
await ApiClient.transfer(
  fromWalletId: 'uuid-here',
  toExternalAddress: '0xABC...',
  assetSymbol: 'USDT',
  amount: 1000000.0,
);
```

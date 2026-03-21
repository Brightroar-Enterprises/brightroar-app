# Brightroar Corp - Asset Manager Flutter App

A production-ready Flutter implementation of the Brightroar Corp institutional crypto asset management app.

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── theme/
│   └── app_theme.dart           # Global dark theme & color palette
├── screens/
│   ├── splash_screen.dart       # Onboarding & App Launch
│   ├── signin_screen.dart       # Sign In (with biometric auth)
│   ├── register_screen.dart     # Create Corporate Account (3 steps)
│   ├── main_shell.dart          # Bottom nav shell
│   ├── dashboard_screen.dart    # Portfolio dashboard with charts
│   ├── wallets_screen.dart      # Institutional & exchange wallets
│   ├── analytics_screen.dart    # Portfolio analytics & charts
│   ├── activity_screen.dart     # Transaction history
│   └── transfer_screen.dart     # Secure transfer confirmation
└── widgets/
    ├── lion_logo.dart           # Custom lion logo painter
    └── glass_card.dart          # Reusable card widget
```

## Screens Implemented

1. **Splash / Onboarding** — Brand launch screen with Sign In / Create Account CTAs
2. **Sign In** — Email + password, FaceID/TouchID & FIDO hardware key auth
3. **Create Account** — 3-step corporate registration wizard
4. **Dashboard** — Total portfolio value, daily performance line chart, donut allocation chart, recent activity
5. **Wallets** — Treasury wallet, internal company wallets, Binance exchange wallet with asset breakdown
6. **Analytics** — Portfolio performance area chart, Sharpe/Alpha/Beta/Volatility metrics, profit history bar chart, asset distribution donuts
7. **Activity** — Filterable transaction list with status badges (Confirmed/Pending/Failed)
8. **Secure Transfer** — Internal→External transfer form with biometric approval overlay

## Theme

- **Background**: `#0A0A0A` (near black)
- **Accent**: `#D4AF37` (institutional gold)
- **Positive**: `#00C896` (emerald green)
- **Negative**: `#FF4560` (red)
- **Font**: SF Pro Display (fallback: system sans)

## Setup

```bash
cd brightroar
flutter pub get
flutter run
```

## Optional Enhancements

- Add `fl_chart` package for richer charts
- Add `local_auth` for real biometric authentication
- Add `flutter_secure_storage` for credential storage
- Replace CustomPainter charts with `fl_chart` LineChart / BarChart
- Add state management (Riverpod/Bloc) for production

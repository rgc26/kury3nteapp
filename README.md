# ⚡ Kuryentahin — Waze for the Philippine Energy Crisis

<p align="center">
  <img src="assets/kuryentahin.png" alt="Kuryentahin Logo" width="120"/>
</p>

<p align="center">
  <strong>Real-time brownout tracking, fuel monitoring, energy auditing, and community mutual aid — built for Filipinos, by Filipinos.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase" alt="Firebase"/>
  <img src="https://img.shields.io/badge/Gemini_AI-2.0_Flash-4285F4?logo=google" alt="Gemini AI"/>
  <img src="https://img.shields.io/badge/Platform-Web_|_Android_|_iOS-green" alt="Platform"/>
</p>

---

## 📖 About

**Kuryentahin** is a community-powered Progressive Web App (PWA) designed to help Filipino households navigate power interruptions, track fuel availability, and reduce electricity costs through AI-powered energy auditing.

The app combines **real-time crowdsourced data**, **AI-powered appliance recognition**, and **Bayanihan-style community features** into a single platform.

---

## 🚀 Features

### 🗺️ Live Brownout Map
- Real-time brownout reporting with GPS location
- Community verification system (upvote/downvote reports)
- Color-coded status markers (No Power / Restored / Scheduled)
- Meralco scheduled maintenance alerts integration
- Interactive map powered by OpenStreetMap + Flutter Map

### ⛽ Fuel Tracker
- Real-time fuel station monitoring
- Community-reported prices with **3-report minimum** validation
- DOE official pricing integration
- Station status tracking (Available / Limited / Empty)
- Price history and trend charts

### ⚡ Energy Audit Calculator
- **AI-Powered Appliance Scanner** — Take a photo of any appliance and Gemini AI identifies it with wattage estimates
- Pre-built appliance database (Window Aircon, Inverter, Ref, Fan, etc.)
- Daily/Monthly consumption calculator
- Estimated bill computation based on Meralco rates
- **Makatipid Tips** — AI-generated energy-saving advice in Taglish
- Solar ROI Calculator

### 🔔 Alerts & Notifications
- Meralco scheduled maintenance scraper
- In-app real-time alerts for verified brownouts
- Fuel station status change notifications
- Push notification support via Firebase Cloud Messaging

### 🤝 Bayanihan Board
- Community mutual aid platform
- Post categories: Generator Sharing, Fuel Pool, Charging Station, Business SOS
- Reaction system (Interested / Salamat)
- Real-time comments with auto-syncing count
- Gamification: Bayani Points and ranking system

### 👤 Profile & Trust System
- Google Sign-In authentication
- Bayani ranking: Newbie → Bronze → Silver → Gold → Legendary
- Points earned through reporting, commenting, and community engagement
- Report history tracking

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter 3.10+ (Dart) |
| **Backend** | Firebase (Firestore, Auth, Cloud Messaging) |
| **AI/ML** | Google Gemini 2.0 Flash (Vision + Text) |
| **Maps** | OpenStreetMap + Flutter Map |
| **Hosting** | Vercel (Web), Firebase (Functions) |
| **Auth** | Firebase Auth + Google Sign-In |
| **State** | StatefulWidget + StreamBuilder |

---

## 📁 Project Structure

```
lib/
├── main.dart                  # App entry point
├── app.dart                   # App shell (navigation, drawer, bottom nav)
├── data/
│   ├── appliances_data.dart   # Default appliance database
│   └── energy_tips.dart       # Fallback energy-saving tips
├── models/
│   ├── app_models.dart        # Core models (Appliance, BayanihanPost, etc.)
│   ├── fuel_models.dart       # Fuel station models
│   ├── fuel_station.dart      # Fuel station entity
│   ├── outage_report.dart     # Brownout report model
│   └── trust_system.dart      # Bayani ranking system
├── screens/
│   ├── brownout_map_screen.dart   # Live brownout map
│   ├── fuel_tracker_screen.dart   # Fuel monitoring
│   ├── energy_audit_screen.dart   # Energy calculator + AI scan
│   ├── alerts_screen.dart         # Meralco maintenance alerts
│   ├── bayanihan_screen.dart      # Community board
│   ├── profile_screen.dart        # User profile
│   ├── history_screen.dart        # Report history
│   ├── login_screen.dart          # Google Sign-In
│   └── notifications_screen.dart  # Push notifications
├── services/
│   ├── firebase_service.dart      # Firestore CRUD operations
│   ├── gemini_service.dart        # Gemini AI integration
│   ├── meralco_scraper.dart       # Maintenance schedule scraper
│   └── storage_service.dart       # Local storage (SharedPreferences)
└── theme/
    ├── app_colors.dart            # Color palette
    └── app_theme.dart             # Material theme config
```

---

## ⚙️ Setup & Installation

### Prerequisites
- Flutter SDK 3.10+
- Firebase project with Firestore, Auth, and Cloud Messaging enabled
- Google Gemini API key

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/rgc26/kury3nteapp.git
   cd kury3nteapp
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   Create a `.env` file in the project root:
   ```
   GEMINI_API_KEY=your_gemini_api_key_here
   ```

4. **Run the app**
   ```bash
   flutter run -d chrome
   ```

---

## 🌐 Deployment

### Vercel (Web)
The app is deployed as a PWA on Vercel. Build output is from `build/web`.

### Firebase Functions
Cloud Functions handle server-side operations like Meralco schedule scraping.

---

## 👨‍💻 Author

**Romark Cacho**  
BS Information Technology  
Gordon College

---

## 📄 License

This project is developed as a capstone requirement for academic purposes.

---

<p align="center">
  <strong>⚡ Kuryentahin — Para sa Bayan, Para sa Bayanihan ⚡</strong>
</p>

# Monetization Plan: Omni Bridge

## Overview
Omni Bridge uses a 3-tier subscription model to balance server costs with user accessibility. 

## Subscription Tiers

| Feature | **Free** | **Weekly** | **Plus** | **Pro** |
| :--- | :--- | :--- | :--- | :--- |
| **Price** | ₹0 | ₹49/week | ₹149/month | ₹399/month |
| **Daily Quota** | 10,000 Chars | 50,000 Chars | 100,000 Chars | Unlimited Chars |
| **History Access** | ❌ None | 🕒 Same Session | 📅 3 Days | ✅ Unlimited Access |
| **Models** | Standard | High-Speed | Advanced AI | Premium Engines |
| **Live Captions** | Basic | Standard | Advanced | Active Auto-Correct |
| **Context Refresh** | ❌ No | ❌ No | ❌ No | ✅ **Intelligent (5s)** |
| **Support** | Community | Standard | Priority | 24/7 Priority |

### Detailed Feature Breakdown
- **Intelligent Context Refresh (5s)**: A high-end AI feature that retroactively corrects previous translation chunks (up to 5 seconds back) as more context becomes available during a live session.
- **Tiered History**:
    - **Free**: No history saved between sessions.
    - **Weekly**: History persists only for the current active window/session.
    - **Plus**: Full access to translations from the last 72 hours.
    - **Pro**: Lifetime access to all past translation logs and notes.
- **Priority Support**: Plus and Pro members get access to faster response times for technical issues.

## Quota Tracking
- Usage is tracked by **character count** of translated text.
- Quota resets daily at **00:00 IST**.
- Users who provide their own **NVIDIA API Key** in settings bypass the daily quota.

## Payment Integration
- **Primary Provider:** Razorpay (optimized for UPI and Indian market).
- **Secondary:** International cards/netbanking via Razorpay gateway.
- **Flow:** User clicks "Upgrade" -> Opens browser for secure checkout -> Webhook updates Firestore -> App reflects status instantly.

## Technical Implementation
- **Firestore:** Stores `tier`, `dailyCharsUsed`, and `dailyResetAt`.
- **WebSocket:** Server sends `input_chars` and `output_chars` in metadata; client increments Firestore counter.
- **Enforcement:** `SubscriptionService` checks quota before starting session and shows `UpgradeSheet` if limit reached.

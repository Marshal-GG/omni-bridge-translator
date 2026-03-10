# Admin Features & Logic Overview

This document provides a technical overview of the administrative code in the Omni Bridge project, detailing how administrative capabilities are managed and implemented.

## 1. Admin Identity & Authorization
**File**: [`lib/screens/account/components/admin_panel.dart`](file:///c:/Users/marsh/OneDrive/Desktop/New%20folder/omni_bridge/lib/screens/account/components/admin_panel.dart)

The application identifies administrators by checking their email against a whitelist stored in Firestore, completely localized to the `AdminPanel` widget.

### Key Logic:
- **`_checkAdminAccess()`**: Method called during `initState` of `AdminPanel`.
  - Fetches the `system/admins` document from Firestore.
  - If the active `FirebaseAuth` user's email is present in the `emails` array, they are confirmed as an admin.
  - If the user isn't an admin, the panel simply returns a `SizedBox.shrink()` making it completely invisible.
- **Admin Management**: Admins have an "Admin Identity" UI directly embedded within the panel that allows them to view, add, and remove admin emails from the `system/admins` list, propagating instantly.

## 2. Administrative Actions
**File**: [`lib/core/services/firebase/subscription_service.dart`](file:///c:/Users/marsh/OneDrive/Desktop/New%20folder/omni_bridge/lib/core/services/firebase/subscription_service.dart)

Administrators have the capability to manually override any user's subscription tier.

### Key Logic:
- **`setTierForOtherUser(String uid, SubscriptionTier tier)`**: Updates the `tier` field in the user's Firestore document.
  - This is triggered by the Admin UI ActionChips to promote or demote users in real-time.
  - **Note**: This logic relies on Firestore Security Rules to enforce that only verified admins can write to other users' documents.

## 3. Administrative User Interface
**File**: [`lib/screens/account/components/admin_panel.dart`](file:///c:/Users/marsh/OneDrive/Desktop/New%20folder/omni_bridge/lib/screens/account/components/admin_panel.dart)

The `AdminPanel` encapsulates all admin-related dashboards, accessible via the main Account settings if authorized.

### Key Components:
- **Internal `_isAdmin` state**: Determines whether to show the UI segments or collapse them.
- **Identity Manager Card**: A `_AdminIdentitySection` widget handling the reading and writing of the `system/admins` whitelist.
- **User List**: A `FutureBuilder` fetching all documents from the `users` collection.
- **User Search**: A `TextField` allowing admins to locally filter the fetched user list by name or email.
- **Plan Manager Card**: Displays once a user is selected from the list, offering interactive elements to update their subscription status instantly.

## 4. Security Architecture
The security of these features is enforced entirely at the database level via **Firestore Security Rules**. Even if the UI code is tampered with or circumvented, the database natively rejects unauthorized writes to the `system/admins` collection and guards other users' metadata, guaranteeing administrative integrity regardless of client-side logic.

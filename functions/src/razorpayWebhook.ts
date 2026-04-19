import {onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

const webhookSecret = defineSecret("RAZORPAY_WEBHOOK_SECRET");

// Valid paid tiers the webhook is allowed to assign.
const PAID_TIERS = new Set(["pro", "enterprise"]);

// Default tier to revert to on subscription termination.
const FREE_TIER = "free";

/**
 * Razorpay webhook endpoint.
 *
 * Configure in Razorpay Dashboard → Settings → Webhooks:
 *   URL    : https://us-central1-omni-bridge-ai-translator.cloudfunctions.net/razorpayWebhook
 *   Secret : same value set via: firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
 *
 * Active events to enable:
 *   payment.captured       — one-time payment succeeded
 *   payment.failed         — one-time payment failed
 *   subscription.activated — subscription started (first charge authorised)
 *   subscription.charged   — monthly renewal paid → extend access
 *   subscription.halted    — renewal failed after all retries → downgrade
 *   subscription.cancelled — user cancelled → downgrade at period end
 *   subscription.completed — subscription plan ended → downgrade
 */
export const razorpayWebhook = onRequest(
  {secrets: [webhookSecret], region: "us-central1"},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // ── Signature verification ────────────────────────────────────────────────
    const signature = req.headers["x-razorpay-signature"] as string | undefined;
    const secret = webhookSecret.value();

    if (!signature || !secret) {
      logger.warn("Missing signature or webhook secret");
      res.status(400).send("Bad Request");
      return;
    }

    const rawBody = (req as unknown as {rawBody: Buffer}).rawBody;
    const expected = crypto
      .createHmac("sha256", secret)
      .update(rawBody)
      .digest("hex");

    if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
      logger.warn("Razorpay signature mismatch — possible spoofed request");
      res.status(400).send("Invalid signature");
      return;
    }

    // ── Event routing ─────────────────────────────────────────────────────────
    const event: string = req.body.event ?? "";
    logger.info(`Razorpay event: ${event}`);

    switch (event) {
      // One-time payment flow (payment links without subscription)
      case "payment.captured":
        await handlePaymentCaptured(req.body);
        break;
      case "payment.failed":
        await handlePaymentFailed(req.body);
        break;

      // Subscription flow
      case "subscription.activated":
        await handleSubscriptionActivated(req.body);
        break;
      case "subscription.charged":
        await handleSubscriptionCharged(req.body);
        break;
      case "subscription.halted":
        await handleSubscriptionTerminated(req.body, "halted");
        break;
      case "subscription.cancelled":
        await handleSubscriptionCancelled(req.body);
        break;
      case "subscription.completed":
        await handleSubscriptionTerminated(req.body, "completed");
        break;

      default:
        logger.info(`Unhandled event type: ${event} — acknowledged`);
    }

    res.status(200).send("OK");
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Resolves the Firebase UID for a subscription or payment event.
 *
 * Strategy (in order):
 *  1. notes.uid — set when the link was opened from inside the app (fastest).
 *  2. razorpaySubscriptionId query — covers renewal events after activation.
 *  3. Email lookup — fallback when link was opened outside the app (e.g. direct URL).
 */
async function resolveUid(
  subEntity: Record<string, unknown>,
  email?: string
): Promise<string | null> {
  // 1. notes.uid
  const notes = subEntity.notes as Record<string, string> | undefined;
  if (notes?.uid) return notes.uid;

  // 2. razorpaySubscriptionId stored at activation
  const subId = subEntity.id as string | undefined;
  if (subId) {
    const snap = await admin
      .firestore()
      .collection("users")
      .where("razorpaySubscriptionId", "==", subId)
      .limit(1)
      .get();
    if (!snap.empty) return snap.docs[0].id;
  }

  // 3. Email fallback — Razorpay always captures payer email at checkout
  if (email) {
    const snap = await admin
      .firestore()
      .collection("users")
      .where("email", "==", email)
      .limit(1)
      .get();
    if (!snap.empty) {
      logger.info(`resolveUid: matched by email ${email}`);
      return snap.docs[0].id;
    }
  }

  return null;
}

function subscriptionEntity(body: unknown): Record<string, unknown> {
  return (
    (
      (body as Record<string, unknown>)?.payload as Record<string, unknown>
    )?.subscription as Record<string, unknown>
  )?.entity as Record<string, unknown> ?? {};
}

function paymentEntity(body: unknown): Record<string, unknown> {
  return (
    (
      (body as Record<string, unknown>)?.payload as Record<string, unknown>
    )?.payment as Record<string, unknown>
  )?.entity as Record<string, unknown> ?? {};
}

/** Resolves UID by email alone — used when notes are absent. */
async function resolveUidByEmail(email: string | undefined): Promise<string | null> {
  if (!email) return null;
  const snap = await admin.firestore()
    .collection("users")
    .where("email", "==", email)
    .limit(1)
    .get();
  if (!snap.empty) {
    logger.info(`resolveUidByEmail: matched uid for ${email}`);
    return snap.docs[0].id;
  }
  return null;
}

/**
 * Maps a Razorpay plan_id to a tier string.
 * Reads from system/monetization → plan_ids map if present, otherwise
 * falls back to matching the plan_id against known IDs hardcoded here.
 * Update this map whenever you create new Razorpay plans.
 */
function planIdToTier(planId: string | undefined): string | undefined {
  if (!planId) return undefined;
  const map: Record<string, string> = {
    "plan_SeBEou7uXFDDRT": "pro",        // Pro Monthly
    "plan_SeBFJKoDwsl158": "enterprise", // Enterprise Monthly
  };
  return map[planId];
}

function thirtyDaysFromNow(): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromMillis(
    Date.now() + 30 * 24 * 60 * 60 * 1000
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// payment.captured  (one-time payment link flow)
// ─────────────────────────────────────────────────────────────────────────────

async function handlePaymentCaptured(body: unknown): Promise<void> {
  const entity = paymentEntity(body);
  const notes = entity.notes as Record<string, string> | undefined;
  const email = entity.email as string | undefined;
  const paymentId = (entity.id as string) ?? "unknown";

  const uid = notes?.uid ?? await resolveUidByEmail(email);
  const tier = notes?.tier;

  if (!uid || !tier) {
    logger.error("payment.captured — could not resolve uid or tier", {paymentId, email});
    return;
  }
  if (!PAID_TIERS.has(tier)) {
    logger.error(`payment.captured — invalid tier "${tier}"`, {paymentId});
    return;
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const now = admin.firestore.Timestamp.now();

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(userRef);
    if (!snap.exists) throw new Error(`User not found: ${uid}`);

    const amountPaise = (entity.amount as number) ?? 0;

    const update: Record<string, unknown> = {
      tier,
      monthlyTokensUsed: 0,
      monthlyResetAt: thirtyDaysFromNow(),
      paymentProvider: "razorpay",
      lastPaymentId: paymentId,
      lastPaymentAt: now,
      ...(amountPaise > 0 && {lastPaymentAmountPaise: amountPaise}),
    };
    if (!snap.data()?.subscriptionSince) {
      update.subscriptionSince = now;
    }
    txn.update(userRef, update);

    txn.set(userRef.collection("subscription_events").doc(), {
      event: "upgraded",
      from: snap.data()?.tier ?? "",
      to: tier,
      via: "razorpay_payment_link",
      paymentId,
      ...(amountPaise > 0 && {amountPaise}),
      timestamp: now,
    });
  });

  logger.info(`payment.captured: uid=${uid} tier=${tier} paymentId=${paymentId}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// payment.failed  (one-time payment link flow)
// ─────────────────────────────────────────────────────────────────────────────

async function handlePaymentFailed(body: unknown): Promise<void> {
  const entity = paymentEntity(body);
  const notes = entity.notes as Record<string, string> | undefined;
  const paymentId = (entity.id as string) ?? "unknown";
  const reason = (entity.error_description as string) ?? (entity.error_code as string) ?? "unknown";

  // No Firestore write — the Flutter app handles the pending timeout itself.
  logger.info(
    `payment.failed: uid=${notes?.uid ?? "?"} tier=${notes?.tier ?? "?"} ` +
    `paymentId=${paymentId} reason=${reason}`
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// subscription.activated  — first charge authorised, subscription is live
// ─────────────────────────────────────────────────────────────────────────────

async function handleSubscriptionActivated(body: unknown): Promise<void> {
  const entity = subscriptionEntity(body);
  const payEntity = paymentEntity(body);
  const notes = entity.notes as Record<string, string> | undefined;
  const subId = entity.id as string | undefined;
  const planId = entity.plan_id as string | undefined;
  const firstPaymentId = payEntity.id as string | undefined;
  const firstPaymentAmount = (payEntity.amount as number) ?? 0;
  const email = (payEntity.email as string | undefined) ??
    (entity.customer_email as string | undefined);

  const uid = await resolveUid(entity, email);
  const tier = notes?.tier ?? planIdToTier(planId);

  if (!uid || !tier || !subId) {
    logger.error("subscription.activated — could not resolve uid, tier, or subId", {uid, tier, subId, email});
    return;
  }
  if (!PAID_TIERS.has(tier)) {
    logger.error(`subscription.activated — invalid tier "${tier}"`, {subId});
    return;
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const now = admin.firestore.Timestamp.now();

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(userRef);
    if (!snap.exists) throw new Error(`User not found: ${uid}`);

    const update: Record<string, unknown> = {
      tier,
      monthlyTokensUsed: 0,
      monthlyResetAt: thirtyDaysFromNow(),
      paymentProvider: "razorpay",
      razorpaySubscriptionId: subId,
      razorpayPlanId: planId ?? "",
      subscriptionStatus: "active",
      // First payment details
      ...(firstPaymentId && {lastPaymentId: firstPaymentId}),
      ...(firstPaymentAmount > 0 && {lastPaymentAmountPaise: firstPaymentAmount}),
      lastPaymentAt: now,
    };
    if (!snap.data()?.subscriptionSince) {
      update.subscriptionSince = now;
    }
    txn.update(userRef, update);

    txn.set(userRef.collection("subscription_events").doc(), {
      event: "subscription_activated",
      to: tier,
      via: "razorpay_subscription",
      subscriptionId: subId,
      ...(firstPaymentId && {paymentId: firstPaymentId}),
      ...(firstPaymentAmount > 0 && {amountPaise: firstPaymentAmount}),
      timestamp: now,
    });
  });

  logger.info(`subscription.activated: uid=${uid} tier=${tier} subId=${subId} paymentId=${firstPaymentId ?? "none"}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// subscription.charged  — monthly renewal paid, extend access
// ─────────────────────────────────────────────────────────────────────────────

async function handleSubscriptionCharged(body: unknown): Promise<void> {
  const subEntity = subscriptionEntity(body);
  const payEntity = paymentEntity(body);
  const subId = subEntity.id as string | undefined;
  const paymentId = (payEntity.id as string) ?? "unknown";
  const amountPaise = (payEntity.amount as number) ?? 0;

  if (!subId) {
    logger.error("subscription.charged — missing subId");
    return;
  }

  const email = payEntity.email as string | undefined;
  const uid = await resolveUid(subEntity, email);
  if (!uid) {
    logger.error(`subscription.charged — could not resolve uid for subId: ${subId}`);
    return;
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const now = admin.firestore.Timestamp.now();

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(userRef);
    if (!snap.exists) throw new Error(`User not found: ${uid}`);

    txn.update(userRef, {
      monthlyTokensUsed: 0,
      monthlyResetAt: thirtyDaysFromNow(),
      subscriptionStatus: "active",
      lastPaymentId: paymentId,
      lastPaymentAmountPaise: amountPaise,
      lastPaymentAt: now,
    });

    txn.set(userRef.collection("subscription_events").doc(), {
      event: "subscription_renewed",
      tier: snap.data()?.tier ?? "",
      via: "razorpay_subscription",
      subscriptionId: subId,
      paymentId,
      amountPaise,
      timestamp: now,
    });
  });

  logger.info(`subscription.charged: uid=${uid} subId=${subId} paymentId=${paymentId}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// subscription.cancelled — user cancelled; access continues until current_end
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Fired when a user cancels with cancel_at_cycle_end: 1.
 * The subscription is marked cancelled but the user KEEPS their paid tier
 * until the current billing period ends (entity.current_end).
 * Tier downgrade happens later when subscription.completed fires.
 */
async function handleSubscriptionCancelled(body: unknown): Promise<void> {
  const entity = subscriptionEntity(body);
  const subId = entity.id as string | undefined;
  // current_end is a Unix timestamp (seconds) — when the billing period ends
  const currentEndUnix = entity.current_end as number | undefined;

  if (!subId) {
    logger.error("subscription.cancelled — missing subId");
    return;
  }

  const uid = await resolveUid(entity);
  if (!uid) {
    logger.error(`subscription.cancelled — could not resolve uid for subId: ${subId}`);
    return;
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const now = admin.firestore.Timestamp.now();

  // accessEndsAt = end of current billing period (not the cancel request time)
  const accessEndsAt = currentEndUnix
    ? admin.firestore.Timestamp.fromMillis(currentEndUnix * 1000)
    : now;

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(userRef);
    if (!snap.exists) throw new Error(`User not found: ${uid}`);

    const prevTier = snap.data()?.tier ?? "";

    // Mark cancelled but DO NOT downgrade tier — user keeps access until accessEndsAt.
    // razorpaySubscriptionId is also kept for reference.
    txn.update(userRef, {
      subscriptionStatus: "cancelled",
      subscriptionEndedAt: accessEndsAt,
    });

    txn.set(userRef.collection("subscription_events").doc(), {
      event: "subscription_cancelled",
      from: prevTier,
      via: "razorpay_subscription",
      subscriptionId: subId,
      accessEndsAt,
      timestamp: now,
    });
  });

  logger.info(
    `subscription.cancelled: uid=${uid} subId=${subId} ` +
    `accessEndsAt=${accessEndsAt.toDate().toISOString()}`
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// subscription.halted / subscription.completed — immediate tier downgrade
// ─────────────────────────────────────────────────────────────────────────────

async function handleSubscriptionTerminated(
  body: unknown,
  reason: "halted" | "cancelled" | "completed"
): Promise<void> {
  const entity = subscriptionEntity(body);
  const subId = entity.id as string | undefined;

  if (!subId) {
    logger.error(`subscription.${reason} — missing subId`);
    return;
  }

  const uid = await resolveUid(entity);
  if (!uid) {
    logger.error(`subscription.${reason} — could not resolve uid for subId: ${subId}`);
    return;
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const now = admin.firestore.Timestamp.now();

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(userRef);
    if (!snap.exists) throw new Error(`User not found: ${uid}`);

    const prevTier = snap.data()?.tier ?? "";

    txn.update(userRef, {
      tier: FREE_TIER,
      subscriptionStatus: reason,
      subscriptionEndedAt: now,
      razorpaySubscriptionId: admin.firestore.FieldValue.delete(),
    });

    txn.set(userRef.collection("subscription_events").doc(), {
      event: `subscription_${reason}`,
      from: prevTier,
      to: FREE_TIER,
      via: "razorpay_subscription",
      subscriptionId: subId,
      timestamp: now,
    });
  });

  logger.info(`subscription.${reason}: uid=${uid} subId=${subId} → downgraded to ${FREE_TIER}`);
}

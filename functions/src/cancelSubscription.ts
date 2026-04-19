import {onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

const razorpayKeyId = defineSecret("RAZORPAY_KEY_ID");
const razorpayKeySecret = defineSecret("RAZORPAY_KEY_SECRET");

/**
 * Cancels the caller's Razorpay subscription at the end of the billing period.
 *
 * Uses cancel_at_cycle_end: 1 so the user keeps access until their current
 * period ends. The razorpayWebhook handles the resulting subscription.cancelled
 * event and downgrades the tier automatically.
 *
 * Auth: Firebase ID token in the Authorization: Bearer <token> header.
 *
 * Request body: { subscriptionId: "sub_XXXXX" }
 * Response:     { ok: true }
 */
export const cancelSubscription = onRequest(
  {
    secrets: [razorpayKeyId, razorpayKeySecret],
    region: "us-central1",
    cors: true,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // ── Authenticate caller ──────────────────────────────────────────────────
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({error: "Unauthorized"});
      return;
    }

    let uid: string;
    try {
      const token = authHeader.slice(7);
      const decoded = await admin.auth().verifyIdToken(token);
      uid = decoded.uid;
    } catch {
      logger.warn("cancelSubscription: invalid ID token");
      res.status(401).json({error: "Unauthorized"});
      return;
    }

    // ── Validate request ─────────────────────────────────────────────────────
    const {subscriptionId} = req.body as {subscriptionId?: string};
    if (!subscriptionId) {
      res.status(400).json({error: "Missing subscriptionId"});
      return;
    }

    // ── Security: verify subscription belongs to caller ──────────────────────
    const snap = await admin
      .firestore()
      .collection("users")
      .where("razorpaySubscriptionId", "==", subscriptionId)
      .limit(1)
      .get();

    if (snap.empty || snap.docs[0].id !== uid) {
      logger.warn(
        `cancelSubscription: uid=${uid} attempted to cancel subId=${subscriptionId} — not their subscription`
      );
      res.status(403).json({error: "Subscription does not belong to this account."});
      return;
    }

    // ── Cancel via Razorpay API ───────────────────────────────────────────────
    const keyId = razorpayKeyId.value();
    const keySecret = razorpayKeySecret.value();
    const credentials = Buffer.from(`${keyId}:${keySecret}`).toString("base64");

    let razorpayResponse: Response;
    try {
      razorpayResponse = await fetch(
        `https://api.razorpay.com/v1/subscriptions/${subscriptionId}/cancel`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Basic ${credentials}`,
          },
          // cancel_at_cycle_end: 1 → user keeps access until billing period ends.
          // Never use 0 — that revokes access immediately.
          body: JSON.stringify({cancel_at_cycle_end: 1}),
        }
      );
    } catch (err) {
      logger.error("cancelSubscription: network error calling Razorpay", err);
      res.status(502).json({error: "Payment provider unavailable. Please try again."});
      return;
    }

    const razorpayData = await razorpayResponse.json() as Record<string, unknown>;

    if (!razorpayResponse.ok) {
      const errDesc =
        (razorpayData.error as Record<string, unknown>)?.description as
          | string
          | undefined;
      logger.error("cancelSubscription: Razorpay error", {
        status: razorpayResponse.status,
        error: razorpayData,
      });
      res.status(502).json({error: errDesc ?? "Failed to cancel subscription."});
      return;
    }

    logger.info(`cancelSubscription: uid=${uid} subId=${subscriptionId} scheduled`);
    res.status(200).json({ok: true});
  }
);

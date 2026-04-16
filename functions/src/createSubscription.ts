import {onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

const razorpayKeyId = defineSecret("RAZORPAY_KEY_ID");
const razorpayKeySecret = defineSecret("RAZORPAY_KEY_SECRET");

/**
 * Creates a Razorpay subscription for the authenticated user.
 *
 * Called by the Flutter app when a user taps "Select Plan" on a paid tier.
 * Returns a Razorpay short_url the client opens in the system browser.
 *
 * Auth: Firebase ID token in the Authorization: Bearer <token> header.
 *
 * Request body: { tierId: "pro" | "enterprise" }
 * Response: { url: "https://rzp.io/..." }
 *
 * Reads plan_id from system/monetization → plan_ids map, so no code change
 * is needed when Razorpay plans are recreated.
 */
export const createSubscription = onRequest(
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
    let userEmail: string | undefined;
    try {
      const token = authHeader.slice(7);
      const decoded = await admin.auth().verifyIdToken(token);
      uid = decoded.uid;
      userEmail = decoded.email;
    } catch {
      logger.warn("createSubscription: invalid ID token");
      res.status(401).json({error: "Unauthorized"});
      return;
    }

    // ── Validate request ─────────────────────────────────────────────────────
    const {tierId} = req.body as {tierId?: string};
    if (!tierId) {
      res.status(400).json({error: "Missing tierId"});
      return;
    }

    // ── Resolve Razorpay plan ID from Firestore config ───────────────────────
    const monetizationDoc = await admin
      .firestore()
      .collection("system")
      .doc("monetization")
      .get();

    const planIds = monetizationDoc.data()?.plan_ids as
      | Record<string, string>
      | undefined;
    const planId = planIds?.[tierId];

    if (!planId) {
      logger.error(`createSubscription: no plan_id for tier "${tierId}"`);
      res.status(400).json({error: "Plan not configured for this tier."});
      return;
    }

    // ── Create subscription via Razorpay REST API ────────────────────────────
    const keyId = razorpayKeyId.value();
    const keySecret = razorpayKeySecret.value();
    const credentials = Buffer.from(`${keyId}:${keySecret}`).toString("base64");

    const subscriptionPayload: Record<string, unknown> = {
      plan_id: planId,
      total_count: 120, // 10 years — effectively unlimited
      quantity: 1,
      notes: {uid, tier: tierId},
    };
    if (userEmail) {
      subscriptionPayload.notify_info = {notify_email: userEmail};
    }

    let razorpayResponse: Response;
    try {
      razorpayResponse = await fetch("https://api.razorpay.com/v1/subscriptions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Basic ${credentials}`,
        },
        body: JSON.stringify(subscriptionPayload),
      });
    } catch (err) {
      logger.error("createSubscription: network error calling Razorpay", err);
      res.status(502).json({error: "Payment provider unavailable. Please try again."});
      return;
    }

    const razorpayData = await razorpayResponse.json() as Record<string, unknown>;

    if (!razorpayResponse.ok) {
      const errDesc =
        (razorpayData.error as Record<string, unknown>)?.description as
          | string
          | undefined;
      logger.error("createSubscription: Razorpay error", {
        status: razorpayResponse.status,
        error: razorpayData,
      });
      res.status(502).json({error: errDesc ?? "Failed to create payment session."});
      return;
    }

    const shortUrl = razorpayData.short_url as string | undefined;
    if (!shortUrl) {
      logger.error("createSubscription: Razorpay response missing short_url", razorpayData);
      res.status(502).json({error: "Payment provider returned no URL."});
      return;
    }

    logger.info(
      `createSubscription: uid=${uid} tier=${tierId} planId=${planId} url=${shortUrl}`
    );
    res.status(200).json({url: shortUrl});
  }
);

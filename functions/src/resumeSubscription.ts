import {onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

const razorpayKeyId = defineSecret("RAZORPAY_KEY_ID");
const razorpayKeySecret = defineSecret("RAZORPAY_KEY_SECRET");

/**
 * Resumes a Razorpay subscription that was cancelled with cancel_at_cycle_end:1.
 *
 * Calls POST /v1/subscriptions/{id}/resume with { resume_at: "now" }.
 * The subscription is reactivated on its original billing schedule — no new
 * subscription created, no double billing, no immediate charge.
 *
 * Also writes subscriptionStatus: "active" directly to Firestore so the
 * Flutter UI updates immediately without waiting for a webhook.
 *
 * Auth: Firebase ID token in the Authorization: Bearer <token> header.
 *
 * Request body: { subscriptionId: "sub_XXXXX" }
 * Response:     { ok: true }
 */
export const resumeSubscription = onRequest(
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
      logger.warn("resumeSubscription: invalid ID token");
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
    const userRef = admin.firestore().collection("users").doc(uid);
    const snap = await admin
      .firestore()
      .collection("users")
      .where("razorpaySubscriptionId", "==", subscriptionId)
      .limit(1)
      .get();

    if (snap.empty || snap.docs[0].id !== uid) {
      logger.warn(
        `resumeSubscription: uid=${uid} attempted to resume subId=${subscriptionId} — not their subscription`
      );
      res.status(403).json({error: "Subscription does not belong to this account."});
      return;
    }

    // ── Resume via Razorpay API ───────────────────────────────────────────────
    const keyId = razorpayKeyId.value();
    const keySecret = razorpayKeySecret.value();
    const credentials = Buffer.from(`${keyId}:${keySecret}`).toString("base64");

    let razorpayResponse: Response;
    try {
      razorpayResponse = await fetch(
        `https://api.razorpay.com/v1/subscriptions/${subscriptionId}/resume`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Basic ${credentials}`,
          },
          body: JSON.stringify({resume_at: "now"}),
        }
      );
    } catch (err) {
      logger.error("resumeSubscription: network error calling Razorpay", err);
      res.status(502).json({error: "Payment provider unavailable. Please try again."});
      return;
    }

    const razorpayData = await razorpayResponse.json() as Record<string, unknown>;

    if (!razorpayResponse.ok) {
      const errDesc =
        (razorpayData.error as Record<string, unknown>)?.description as
          | string
          | undefined;
      logger.error("resumeSubscription: Razorpay error", {
        status: razorpayResponse.status,
        error: razorpayData,
      });
      res.status(502).json({error: errDesc ?? "Failed to resume subscription."});
      return;
    }

    // ── Update Firestore directly ─────────────────────────────────────────────
    // Don't rely solely on a webhook — write the status now so the Flutter
    // UI reflects the change immediately via the Firestore snapshot listener.
    // We only update the status fields; monthlyResetAt and quota stay intact.
    await userRef.update({
      subscriptionStatus: "active",
      subscriptionEndedAt: admin.firestore.FieldValue.delete(),
    });

    logger.info(`resumeSubscription: uid=${uid} subId=${subscriptionId} reactivated`);
    res.status(200).json({ok: true});
  }
);

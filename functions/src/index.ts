import * as admin from "firebase-admin";

admin.initializeApp();

export {razorpayWebhook} from "./razorpayWebhook";
export {createSubscription} from "./createSubscription";

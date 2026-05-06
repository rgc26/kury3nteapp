const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

// Trigger when a new outage report is created or updated
exports.verifyCluster = functions.firestore
  .document("outages/{docId}")
  .onWrite(async (change, context) => {
    // If deleted, do nothing
    if (!change.after.exists) return null;
    
    const data = change.after.data();
    
    // Only verify unverified or nopower reports
    if (data.status !== "unverified" && data.status !== "nopower") return null;

    // We simulate the cluster threshold (3 points)
    const currentScore = data.upvotes || 1;
    
    // If the score is >= 3, and it's currently unverified, upgrade to 'nopower' (Red Confirmed)
    if (currentScore >= 3 && data.status === "unverified") {
      console.log(`Outage ${context.params.docId} reached 3 votes. Verifying...`);
      
      // Update the document to confirmed status
      await change.after.ref.update({
        status: "nopower",
        isVerified: true
      });
      
      // Here you would trigger FCM push notifications to nearby users
      // Example pseudo-code:
      /*
      const payload = {
        notification: {
          title: "🔴 Verified Brownout!",
          body: `A brownout has been confirmed in ${data.areaName || "your area"}.`
        }
      };
      await admin.messaging().sendToTopic(data.barangay_topic, payload);
      */
    }
    
    return null;
  });

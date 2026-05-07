const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

// Trigger when a new outage report is created or updated
exports.verifyCluster = functions.firestore
  .document("outages/{docId}")
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;
    
    const data = change.after.data();
    const oldData = change.before.exists ? change.before.data() : null;
    
    // Logic: If status just changed to 'nopower' (Verified Red Pin)
    if (data.status === "nopower" && (!oldData || oldData.status !== "nopower")) {
      console.log(`Outage ${context.params.docId} verified. Sending notification...`);
      
      const payload = {
        notification: {
          title: "🔴 Brownout Confirmed!",
          body: `Isang brownout ang nakumpirma sa ${data.barangay || data.areaName || "iyong lugar"}. Maging handa! ⚡`,
        },
        topic: "outages"
      };

      try {
        await admin.messaging().send(payload);
      } catch (error) {
        console.error("FCM Outage Error:", error);
      }
    }
    
    return null;
  });

// Trigger when a fuel station status is updated
exports.notifyFuelUpdate = functions.firestore
  .document("fuel_stations/{stationId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();

    // Notify only if the status changed (e.g., from unknown to available)
    if (newData.status !== oldData.status) {
      console.log(`Fuel update for ${newData.name}. Sending notification...`);

      const payload = {
        notification: {
          title: "⛽ Fuel Update!",
          body: `${newData.name} is now: ${newData.status.toUpperCase()}. Check the map for prices!`,
        },
        topic: "fuel"
      };

      try {
        await admin.messaging().send(payload);
      } catch (error) {
        console.error("FCM Fuel Error:", error);
      }
    }
    return null;
  });

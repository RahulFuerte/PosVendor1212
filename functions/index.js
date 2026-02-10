import { onCall, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";

// Initialize the app
initializeApp();

setGlobalOptions({ maxInstances: 10 });

export const registerSpecificAdmin = onCall({ invoker: "public" }, async (request) => {
  // 1. Auth Check
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login required.");
  }

  const uid = request.auth.uid;
  const phone = request.auth.token.phone_number;
  const { adminCode, package: selectedPlan, trialDays: trialDays } = request.data;

  // 2. Dynamic & Unique Admin Code Check
  if (!adminCode || adminCode.trim() === "") {
    return { success: false, message: "Admin Code is required." };
  }

  const db = getFirestore();
  const adminQuery = await db.collection("AllAdmins")
    .where("adminCode", "==", adminCode)
    .get();

  if (!adminQuery.empty) {
    return { success: false, message: "Admin Code already taken. Please choose another." };
  }

  // 3. Expiry Calculation
  const expiryDate = new Date();
  if (selectedPlan === "trial") expiryDate.setDate(expiryDate.getDate() + trialDays);
  else if (selectedPlan === "monthly") expiryDate.setMonth(expiryDate.getMonth() + 1);
  else if (selectedPlan === "half_year") expiryDate.setMonth(expiryDate.getMonth() + 6);
  else if (selectedPlan === "yearly") expiryDate.setFullYear(expiryDate.getFullYear() + 1);

  try {
    // 4. Set Custom Claim (Correct way in v13)
    await getAuth().setCustomUserClaims(uid, { admin: true });

    // 5. Save to Firestore
    const db = getFirestore();
    await db.collection("AllAdmins").doc(phone).set({
      uid: uid,
      phone: phone,
      adminCode: adminCode,
      role: "admin",
      package: selectedPlan,
      expiryDate: Timestamp.fromDate(expiryDate),
      createdAt: FieldValue.serverTimestamp(),
    });

    return { success: true, message: "Admin Registered!" };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});
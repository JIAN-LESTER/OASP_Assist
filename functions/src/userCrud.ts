import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onDocumentDeleted} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

const db = admin.firestore();

async function isAdmin(uid: string): Promise<boolean> {
  try {
    const userDoc = await db.collection("users").doc(uid).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      if (userData?.role === "admin") {
        return true;
      }
    }

    try {
      const userRecord = await admin.auth().getUser(uid);
      if (userRecord.customClaims?.admin === true) {
        return true;
      }
    } catch (authError) {
      console.error("Error checking custom claims:", authError);
    }

    return false;
  } catch (error) {
    console.error("Error checking admin status:", error);
    return false;
  }
}

export const createUser = onCall(
  {
    region: "asia-southeast1",
    cors: true,
    invoker: "private",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    console.log("========================================");
    console.log(" createUser function called");
    console.log(" Request auth:", JSON.stringify(request.auth, null, 2));
    console.log(" Request data:", JSON.stringify(request.data, null, 2));
    console.log("========================================");

    try {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "You must be logged in as an admin."
        );
      }

      const callerUid = request.auth.uid;
      const callerIsAdmin = await isAdmin(callerUid);

      if (!callerIsAdmin) {
        throw new HttpsError(
          "permission-denied",
          "Only admins can create users."
        );
      }

      const {
        email,
        password,
        displayName,
        role,
        affiliation,
        studentId,
        year,
        program,
        scholarship,
        lrn,
        serviceUnit,
      } = request.data;

      if (!email || !password) {
        throw new HttpsError(
          "invalid-argument",
          "Email and password are required."
        );
      }

      // Create user in Firebase Authentication
      const userRecord = await admin.auth().createUser({
        email: email,
        password: password,
        displayName: displayName || "",
        emailVerified: true,
      });

      // Prepare Firestore data based on role
      const firestoreData: any = {
        uid: userRecord.uid,
        email: email,
        displayName: displayName || "",
        name: displayName || email.split("@")[0],
        role: role || "user",
        profileComplete: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(), 
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(), 
        createdBy: callerUid,
        isActive: true,
        isVerified: true,
        emailVerified: true,
        hasSeenOnboardingGuide: false,
        profileCompleted: true,
        onboardingCompleted: true,

        verificationEmailSent: false,
        dailyMessageCount: 0,
        lastMessageResetDate: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Add role-specific fields
      if (role === "user") {
        firestoreData.affiliation = affiliation || "";

        if (affiliation === "CMU Student") {
          firestoreData.studentId = studentId || "";
          firestoreData.year = year || "";
          firestoreData.program = program || "";
          firestoreData.scholarship = scholarship || "";
        } else if (affiliation === "Incoming Freshman Applicant") {
          firestoreData.lrn = lrn || "";
        }
      } else if (role === "staff") {
        firestoreData.serviceUnit = serviceUnit || "";
      }

      // Save to Firestore
      await db.collection("users").doc(userRecord.uid).set(firestoreData);

      // Create log entry
      await db.collection("logs").add({
        user: displayName || email,
        action: `Admin created ${role || "user"} account (auto-verified, no email sent)`,
        time: admin.firestore.FieldValue.serverTimestamp(),
        userId: userRecord.uid,
        createdBy: callerUid,
      });

      return {
        success: true,
        uid: userRecord.uid,
        email: email,
        message: "User created successfully.",
      };
    } catch (error: any) {
      console.error(" Error creating user:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      if (error.code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "This email is already registered.");
      }

      if (error.code === "auth/invalid-email") {
        throw new HttpsError("invalid-argument", "Invalid email address.");
      }

      if (error.code === "auth/weak-password") {
        throw new HttpsError("invalid-argument", "Password must be at least 6 characters.");
      }

      throw new HttpsError("internal", error.message || "Failed to create user");
    }
  }
);

export const updateUser = onCall(
  {
    region: "asia-southeast1",
    cors: true,
    invoker: "private",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    console.log(" updateUser function called");
    console.log(" Update data:", JSON.stringify(request.data, null, 2));

    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "You must be logged in.");
      }

      const callerUid = request.auth.uid;
      const callerIsAdmin = await isAdmin(callerUid);

      if (!callerIsAdmin) {
        throw new HttpsError("permission-denied", "Only admins can update users.");
      }

      const {
        uid,
        email,
        password,
        displayName,
        role,
        affiliation,
        studentId,
        year,
        program,
        scholarship,
        lrn,
        serviceUnit,
        isActive,
      } = request.data;

      if (!uid) {
        throw new HttpsError("invalid-argument", "User ID (uid) is required.");
      }

      // Update Firebase Authentication
      const authUpdateData: admin.auth.UpdateRequest = {};
      if (email) {
        authUpdateData.email = email;
        authUpdateData.emailVerified = true;
      }
      if (password) authUpdateData.password = password;
      if (displayName) authUpdateData.displayName = displayName;

      if (Object.keys(authUpdateData).length > 0) {
        await admin.auth().updateUser(uid, authUpdateData);
      }

      // Prepare Firestore update based on role
      const firestoreUpdate: any = {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (displayName !== undefined) {
        firestoreUpdate.name = displayName;
        firestoreUpdate.displayName = displayName;
      }
      if (email !== undefined) firestoreUpdate.email = email;
      if (role !== undefined) firestoreUpdate.role = role;
      if (isActive !== undefined) firestoreUpdate.isActive = isActive;

      // Handle role-specific fields
      if (role === "user") {
        firestoreUpdate.affiliation = affiliation || "";

        if (affiliation === "CMU Student") {
          if (studentId !== undefined) firestoreUpdate.studentId = studentId;
          if (year !== undefined) firestoreUpdate.year = year;
          if (program !== undefined) firestoreUpdate.program = program;
          if (scholarship !== undefined) firestoreUpdate.scholarship = scholarship;

          // Remove fields that don't belong
          firestoreUpdate.lrn = admin.firestore.FieldValue.delete();
          firestoreUpdate.serviceUnit = admin.firestore.FieldValue.delete();
        } else if (affiliation === "Incoming Freshman Applicant") {
          if (lrn !== undefined) firestoreUpdate.lrn = lrn;

          // Remove fields that don't belong
          firestoreUpdate.studentId = admin.firestore.FieldValue.delete();
          firestoreUpdate.year = admin.firestore.FieldValue.delete();
          firestoreUpdate.program = admin.firestore.FieldValue.delete();
          firestoreUpdate.scholarship = admin.firestore.FieldValue.delete();
          firestoreUpdate.serviceUnit = admin.firestore.FieldValue.delete();
        } else {
          // Other affiliations - remove all specific fields
          firestoreUpdate.studentId = admin.firestore.FieldValue.delete();
          firestoreUpdate.year = admin.firestore.FieldValue.delete();
          firestoreUpdate.program = admin.firestore.FieldValue.delete();
          firestoreUpdate.scholarship = admin.firestore.FieldValue.delete();
          firestoreUpdate.lrn = admin.firestore.FieldValue.delete();
          firestoreUpdate.serviceUnit = admin.firestore.FieldValue.delete();
        }
      } else if (role === "staff") {
        if (serviceUnit !== undefined) firestoreUpdate.serviceUnit = serviceUnit;

        // Remove user-specific fields
        firestoreUpdate.affiliation = admin.firestore.FieldValue.delete();
        firestoreUpdate.studentId = admin.firestore.FieldValue.delete();
        firestoreUpdate.year = admin.firestore.FieldValue.delete();
        firestoreUpdate.program = admin.firestore.FieldValue.delete();
        firestoreUpdate.scholarship = admin.firestore.FieldValue.delete();
        firestoreUpdate.lrn = admin.firestore.FieldValue.delete();
      } else if (role === "admin") {
        // Remove all role-specific fields for admin
        firestoreUpdate.affiliation = admin.firestore.FieldValue.delete();
        firestoreUpdate.studentId = admin.firestore.FieldValue.delete();
        firestoreUpdate.year = admin.firestore.FieldValue.delete();
        firestoreUpdate.program = admin.firestore.FieldValue.delete();
        firestoreUpdate.scholarship = admin.firestore.FieldValue.delete();
        firestoreUpdate.lrn = admin.firestore.FieldValue.delete();
        firestoreUpdate.serviceUnit = admin.firestore.FieldValue.delete();
      }

      // Update Firestore
      await db.collection("users").doc(uid).update(firestoreUpdate);

      // Create log entry
      await db.collection("logs").add({
        user: displayName || email || "Unknown",
        action: `Admin updated ${role || "user"} account`,
        time: admin.firestore.FieldValue.serverTimestamp(),
        userId: uid,
        updatedBy: callerUid,
      });

      console.log(" User updated successfully:", uid);

      return {
        success: true,
        message: `User ${uid} updated successfully.`,
      };
    } catch (error: any) {
      console.error(" Error updating user:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError("internal", error.message || "Failed to update user");
    }
  }
);

export const deleteUser = onCall(
  {
    region: "asia-southeast1",
    cors: true,
    invoker: "private",
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (request) => {
    console.log(" deleteUser function called");

    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "You must be logged in.");
      }

      const callerUid = request.auth.uid;
      const callerIsAdmin = await isAdmin(callerUid);

      if (!callerIsAdmin) {
        throw new HttpsError("permission-denied", "Only admins can delete users.");
      }

      const uid = request.data.uid as string;
      if (!uid) {
        throw new HttpsError("invalid-argument", "User ID (uid) is required.");
      }

      console.log(` Starting cascade delete for user: ${uid}`);

      // Get user document
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) {
        console.warn(` User document not found: ${uid}`);
      }

      // Delete conversations and messages
      let conversationsSnapshot = await db
        .collection("conversations")
        .where("userID", "==", uid)
        .get();

      if (conversationsSnapshot.empty) {
        conversationsSnapshot = await db
          .collection("conversations")
          .where("userId", "==", uid)
          .get();
      }

      console.log(` Found ${conversationsSnapshot.size} conversations`);

      for (const doc of conversationsSnapshot.docs) {
        console.log(`➡ Deleting conversation: ${doc.id}`);
        try {
          await db.recursiveDelete(doc.ref);
        } catch (deleteError) {
          console.error(` Failed to delete conversation ${doc.id}:`, deleteError);
        }
      }

      console.log(` Deleted all conversations & messages for ${uid}`);

      // Delete escalations
      let escSnapshot = await db
        .collection("escalations")
        .where("userID", "==", uid)
        .get();

      if (escSnapshot.empty) {
        escSnapshot = await db
          .collection("escalations")
          .where("userId", "==", uid)
          .get();
      }

      if (!escSnapshot.empty) {
        const batch = db.batch();
        escSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        console.log(` Deleted ${escSnapshot.size} escalations`);
      } else {
        console.log(` No escalations found for ${uid}`);
      }

      // Delete Firebase Authentication user
      try {
        await admin.auth().deleteUser(uid);
        console.log(` Auth user deleted: ${uid}`);
      } catch (authError: any) {
        console.warn(` Could not delete auth user: ${authError.message}`);
      }

      // Delete user document from Firestore
      try {
        await db.collection("users").doc(uid).delete();
        console.log(` User document deleted: ${uid}`);
      } catch (firestoreError) {
        console.warn(" Could not delete user from Firestore:", firestoreError);
      }

      // Create log entry
      await db.collection("logs").add({
        action: "Admin deleted user account (cascade)",
        userId: uid,
        deletedConversations: conversationsSnapshot.size,
        deletedEscalations: escSnapshot.size,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        deletedBy: callerUid,
      });

      console.log(` Completed cascade delete for user: ${uid}`);

      return {
        success: true,
        message: `User ${uid} and all related data deleted successfully.`,
        deletedConversations: conversationsSnapshot.size,
        deletedEscalations: escSnapshot.size,
      };
    } catch (error: any) {
      console.error(" Error deleting user:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError("internal", error.message || "Failed to delete user");
    }
  }
);

export const setAdminRole = onCall(
  {
    region: "asia-southeast1",
    cors: true,
    invoker: "private",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    console.log(" setAdminRole function called");

    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "You must be logged in.");
      }

      const callerUid = request.auth.uid;
      const callerIsAdmin = await isAdmin(callerUid);

      if (!callerIsAdmin) {
        throw new HttpsError("permission-denied", "Only admins can change admin roles.");
      }

      const uid = request.data.uid as string;
      const makeAdmin = request.data.isAdmin as boolean;

      if (!uid) {
        throw new HttpsError("invalid-argument", "User ID (uid) is required.");
      }

      await db.collection("users").doc(uid).update({
        role: makeAdmin ? "admin" : "user",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await admin.auth().setCustomUserClaims(uid, {
        admin: makeAdmin,
      });

      return {
        success: true,
        message: `User ${uid} ${makeAdmin ? "promoted to" : "removed from"} admin role.`,
      };
    } catch (error: any) {
      console.error(" Error setting admin role:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError("internal", error.message || "Failed to set admin role");
    }
  }
);

export const onUserDelete = onDocumentDeleted(
  "users/{userId}",
  async (event) => {
    const userId = event.params.userId;
    const db = admin.firestore();

    console.log(` [TRIGGER] Starting cascade delete for user: ${userId}`);

    try {
      // Delete Firebase Authentication user IF still present
      try {
        await admin.auth().deleteUser(userId);
        console.log(` [TRIGGER] Auth user deleted: ${userId}`);
      } catch (authErr) {
        console.log(` [TRIGGER] Auth user not found or already deleted: ${userId}`);
      }

      // Delete conversations
      let conversationsSnapshot = await db
        .collection("conversations")
        .where("userID", "==", userId)
        .get();

      if (conversationsSnapshot.empty) {
        conversationsSnapshot = await db
          .collection("conversations")
          .where("userId", "==", userId)
          .get();
      }

      console.log(` [TRIGGER] Found ${conversationsSnapshot.size} conversations`);

      for (const doc of conversationsSnapshot.docs) {
        console.log(`➡ [TRIGGER] Deleting conversation: ${doc.id}`);
        await db.recursiveDelete(doc.ref);
      }

      console.log(` [TRIGGER] Deleted all conversations & messages for ${userId}`);

      // Delete escalations
      let escSnapshot = await db
        .collection("escalations")
        .where("userID", "==", userId)
        .get();

      if (escSnapshot.empty) {
        escSnapshot = await db
          .collection("escalations")
          .where("userId", "==", userId)
          .get();
      }

      if (!escSnapshot.empty) {
        const batch = db.batch();
        escSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        console.log(` [TRIGGER] Deleted ${escSnapshot.size} escalations`);
      } else {
        console.log(` [TRIGGER] No escalations found for ${userId}`);
      }

      // Create a log entry
      await db.collection("logs").add({
        action: "Cascade user delete (trigger)",
        userId,
        deletedConversations: conversationsSnapshot.size,
        deletedEscalations: escSnapshot.size,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(` [TRIGGER] Completed cascade delete for user: ${userId}`);

      return true;
    } catch (error) {
      console.error(` [TRIGGER] Cascade delete error for ${userId}:`, error);
      throw error;
    }
  }
);

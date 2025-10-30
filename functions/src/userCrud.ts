import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

const db = admin.firestore();

// ============================================================================
// HELPER FUNCTION
// ============================================================================

async function isAdmin(uid: string): Promise<boolean> {
  try {
    console.log(`🔍 Checking admin status for UID: ${uid}`);
    
    const userDoc = await db.collection("users").doc(uid).get();
    
    if (userDoc.exists) {
      const userData = userDoc.data();
      const firestoreRole = userData?.role;
      console.log(`📊 Firestore role: ${firestoreRole}`);
      
      if (firestoreRole === "admin") {
        console.log("✅ User is admin (from Firestore)");
        return true;
      }
    }
    
    try {
      const userRecord = await admin.auth().getUser(uid);
      const customClaims = userRecord.customClaims;
      
      if (customClaims?.admin === true) {
        console.log("✅ User is admin (from custom claims)");
        return true;
      }
    } catch (authError) {
      console.error("❌ Error checking custom claims:", authError);
    }
    
    console.log("❌ User is NOT admin");
    return false;
  } catch (error) {
    console.error("Error checking admin status:", error);
    return false;
  }
}

// ============================================================================
// USER CRUD FUNCTIONS
// ============================================================================

export const createUser = onCall(
  {
    cors: true,
  },
  async (request) => {
    console.log("========================================");
    console.log("🔥 createUser function called");
    console.log("📊 Request auth:", JSON.stringify(request.auth, null, 2));
    console.log("📊 Request data:", JSON.stringify(request.data, null, 2));
    console.log("========================================");

    try {
      if (!request.auth) {
        console.error("❌ No auth context - user not authenticated");
        throw new HttpsError(
          "unauthenticated",
          "You must be logged in as an admin."
        );
      }

      const callerUid = request.auth.uid;
      console.log(`✅ User is authenticated: ${callerUid}`);
      console.log(`📧 User email: ${request.auth.token.email || "unknown"}`);

      const callerIsAdmin = await isAdmin(callerUid);
      
      if (!callerIsAdmin) {
        console.error(`❌ User ${callerUid} is not an admin`);
        throw new HttpsError(
          "permission-denied",
          "Only admins can create users."
        );
      }

      console.log(`✅ User ${callerUid} is confirmed admin`);

      const email = request.data.email as string;
      const password = request.data.password as string;
      const displayName = request.data.displayName as string | undefined;
      const affiliation = request.data.affiliation as string | undefined;
      const scholarship = request.data.scholarship as string | undefined;

      if (!email || !password) {
        throw new HttpsError(
          "invalid-argument",
          "Email and password are required."
        );
      }

      console.log(`🔄 Creating user with email: ${email}`);
      
      const userRecord = await admin.auth().createUser({
        email: email,
        password: password,
        displayName: displayName || "",
        emailVerified: true,
      });

      console.log(`✅ User created in Auth with UID: ${userRecord.uid}`);

      await db.collection("users").doc(userRecord.uid).set({
        uid: userRecord.uid,
        email: email,
        displayName: displayName || "",
        name: displayName || email.split("@")[0],
        role: "user",
        affiliation: affiliation || "",
        scholarship: scholarship || "",
        profileComplete: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: callerUid,
        isActive: true,
        isVerified: true,
        emailVerified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        verificationEmailSent: false,
      });

      console.log(`✅ User document created in Firestore for UID: ${userRecord.uid}`);

      await db.collection("logs").add({
        user: displayName || email,
        action: "Admin created user account (auto-verified, no email sent)",
        time: admin.firestore.FieldValue.serverTimestamp(),
        userId: userRecord.uid,
        createdBy: callerUid,
      });

      console.log("✅ User creation complete - No verification email sent (admin-created)");

      return {
        success: true,
        uid: userRecord.uid,
        email: email,
        message: "User created successfully. Account is already verified and ready to use.",
      };
    } catch (error: any) {
      console.error("❌ Error creating user:", error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      if (error.code === "auth/email-already-exists") {
        throw new HttpsError(
          "already-exists",
          "This email is already registered."
        );
      }
      
      if (error.code === "auth/invalid-email") {
        throw new HttpsError(
          "invalid-argument",
          "Invalid email address."
        );
      }
      
      if (error.code === "auth/weak-password") {
        throw new HttpsError(
          "invalid-argument",
          "Password must be at least 6 characters."
        );
      }
      
      console.error("❌ Unhandled error:", error);
      throw new HttpsError(
        "internal",
        error.message || "Failed to create user"
      );
    }
  }
);

export const deleteUser = onCall(
  {
    cors: true,
  },
  async (request) => {
    console.log("========================================");
    console.log("🔥 deleteUser function called");
    console.log("📊 Request auth:", JSON.stringify(request.auth, null, 2));
    console.log("📊 Request data:", JSON.stringify(request.data, null, 2));
    console.log("========================================");
    
    try {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "You must be logged in."
        );
      }

      const callerUid = request.auth.uid;
      const callerIsAdmin = await isAdmin(callerUid);
      
      if (!callerIsAdmin) {
        throw new HttpsError(
          "permission-denied",
          "Only admins can delete users."
        );
      }

      const uid = request.data.uid as string;
      if (!uid) {
        throw new HttpsError(
          "invalid-argument",
          "User ID (uid) is required."
        );
      }

      console.log(`🔄 Deleting user: ${uid}`);

      await admin.auth().deleteUser(uid);
      console.log(`✅ User ${uid} deleted from Authentication`);

      try {
        await db.collection("users").doc(uid).delete();
        console.log(`✅ User ${uid} deleted from Firestore`);
      } catch (firestoreError) {
        console.warn("⚠️ Could not delete user from Firestore:", firestoreError);
      }

      return {
        success: true,
        message: `User ${uid} deleted successfully.`,
      };
    } catch (error: any) {
      console.error("❌ Error deleting user:", error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError("internal", error.message || "Failed to delete user");
    }
  }
);

export const updateUser = onCall(
  {
    cors: true,
  },
  async (request) => {
    console.log("🔥 updateUser function called");
    
    try {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "You must be logged in."
        );
      }

      const callerUid = request.auth.uid;
      const callerIsAdmin = await isAdmin(callerUid);
      
      if (!callerIsAdmin) {
        throw new HttpsError(
          "permission-denied",
          "Only admins can update users."
        );
      }

      const uid = request.data.uid as string;
      const email = request.data.email as string | undefined;
      const password = request.data.password as string | undefined;
      const displayName = request.data.displayName as string | undefined;

      if (!uid) {
        throw new HttpsError(
          "invalid-argument",
          "User ID (uid) is required."
        );
      }

      const updateData: admin.auth.UpdateRequest = {};
      if (email) {
        updateData.email = email;
        updateData.emailVerified = true;
      }
      if (password) updateData.password = password;
      if (displayName) updateData.displayName = displayName;

      await admin.auth().updateUser(uid, updateData);
      console.log(`✅ User ${uid} updated successfully`);
      
      return {
        success: true,
        message: `User ${uid} updated successfully.`,
      };
    } catch (error: any) {
      console.error("❌ Error updating user:", error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError("internal", error.message || "Failed to update user");
    }
  }
);

export const setAdminRole = onCall(
  {
    cors: true,
  },
  async (request) => {
    console.log("🔥 setAdminRole function called");
    
    try {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "You must be logged in."
        );
      }

      const callerUid = request.auth.uid;
      const callerIsAdmin = await isAdmin(callerUid);
      
      if (!callerIsAdmin) {
        throw new HttpsError(
          "permission-denied",
          "Only admins can change admin roles."
        );
      }

      const uid = request.data.uid as string;
      const makeAdmin = request.data.isAdmin as boolean;

      if (!uid) {
        throw new HttpsError(
          "invalid-argument",
          "User ID (uid) is required."
        );
      }

      await db.collection("users").doc(uid).update({
        role: makeAdmin ? "admin" : "user",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await admin.auth().setCustomUserClaims(uid, { 
        admin: makeAdmin 
      });

      console.log(`✅ User ${uid} role updated to ${makeAdmin ? "admin" : "user"}`);

      return {
        success: true,
        message: `User ${uid} ${makeAdmin ? "promoted to" : "removed from"} admin role.`,
      };
    } catch (error: any) {
      console.error("❌ Error setting admin role:", error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError("internal", error.message || "Failed to set admin role");
    }
  }
);
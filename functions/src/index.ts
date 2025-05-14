import { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import { onCall } from 'firebase-functions/v2/https';

admin.initializeApp();

export const createUser = onDocumentCreated('user_creation_requests/{requestId}', async (event) => {
  try {
    const data = event.data?.data();
    if (!data) {
      throw new Error('No data available');
    }

    const { uid, email, password } = data;

    // Create the user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      uid,
      email,
      password,
    });

    // Delete the request document
    await event.data?.ref.delete();

    // Delete the token document
    await admin.firestore().collection('tokens').doc(uid).delete();

    return { success: true, uid: userRecord.uid };
  } catch (error) {
    console.error('Error creating user:', error);
    throw error;
  }
});

export const deleteAuthUser = onDocumentDeleted('users/{userId}', async (event) => {
  // Try to get the UID from the deleted document's data
  const uid = event.data?.data()?.uid || event.params.userId;
  try {
    await admin.auth().deleteUser(uid);
    console.log('Successfully deleted user:', uid);
    return { success: true, uid };
  } catch (error) {
    console.error('Error deleting user:', uid, error);
    throw error;
  }
});

export const syncAuthEmail = onDocumentUpdated('users/{userId}', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  const uid = after?.uid || event.params.userId;

  if (!before || !after) return;

  // Only update if the email has changed
  if (before.email !== after.email) {
    try {
      await admin.auth().updateUser(uid, { email: after.email });
      console.log(`Updated Auth email for user: ${uid}`);
    } catch (error) {
      console.error(`Error updating Auth email for user: ${uid}`, error);
      throw error;
    }
  }
});

export const adminSetUserPassword = onCall(async (request) => {
  const { uid, newPassword } = request.data;
  if (!uid || !newPassword) {
    throw new Error('Missing uid or newPassword');
  }
  try {
    await admin.auth().updateUser(uid, { password: newPassword });
    return { success: true };
  } catch (error) {
    console.error('Error updating user password:', error);
    throw new Error('Failed to update password');
  }
}); 
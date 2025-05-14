"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.adminSetUserPassword = exports.syncAuthEmail = exports.deleteAuthUser = exports.createUser = exports.getServerTime = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const https_1 = require("firebase-functions/v2/https");
const cors = require("cors");
admin.initializeApp();
// Initialize CORS middleware
const corsHandler = cors({ origin: true });
// Helper function to wrap HTTP functions with CORS
const corsEnabledFunction = (handler) => {
    return (0, https_1.onRequest)(async (req, res) => {
        return corsHandler(req, res, () => {
            return handler(req, res);
        });
    });
};
// Example HTTP function with CORS
exports.getServerTime = corsEnabledFunction(async (req, res) => {
    res.json({ timestamp: new Date().toISOString() });
});
exports.createUser = (0, firestore_1.onDocumentCreated)('user_creation_requests/{requestId}', async (event) => {
    var _a, _b;
    try {
        const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
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
        await ((_b = event.data) === null || _b === void 0 ? void 0 : _b.ref.delete());
        // Delete the token document
        await admin.firestore().collection('tokens').doc(uid).delete();
        return { success: true, uid: userRecord.uid };
    }
    catch (error) {
        console.error('Error creating user:', error);
        throw error;
    }
});
exports.deleteAuthUser = (0, firestore_1.onDocumentDeleted)('users/{userId}', async (event) => {
    var _a, _b;
    // Try to get the UID from the deleted document's data
    const uid = ((_b = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data()) === null || _b === void 0 ? void 0 : _b.uid) || event.params.userId;
    try {
        await admin.auth().deleteUser(uid);
        console.log('Successfully deleted user:', uid);
        return { success: true, uid };
    }
    catch (error) {
        console.error('Error deleting user:', uid, error);
        throw error;
    }
});
exports.syncAuthEmail = (0, firestore_1.onDocumentUpdated)('users/{userId}', async (event) => {
    var _a, _b, _c, _d;
    const before = (_b = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before) === null || _b === void 0 ? void 0 : _b.data();
    const after = (_d = (_c = event.data) === null || _c === void 0 ? void 0 : _c.after) === null || _d === void 0 ? void 0 : _d.data();
    const uid = (after === null || after === void 0 ? void 0 : after.uid) || event.params.userId;
    if (!before || !after)
        return;
    // Only update if the email has changed
    if (before.email !== after.email) {
        try {
            await admin.auth().updateUser(uid, { email: after.email });
            console.log(`Updated Auth email for user: ${uid}`);
        }
        catch (error) {
            console.error(`Error updating Auth email for user: ${uid}`, error);
            throw error;
        }
    }
});
exports.adminSetUserPassword = (0, https_1.onCall)(async (request) => {
    const { uid, newPassword } = request.data;
    if (!uid || !newPassword) {
        throw new Error('Missing uid or newPassword');
    }
    try {
        await admin.auth().updateUser(uid, { password: newPassword });
        return { success: true };
    }
    catch (error) {
        console.error('Error updating user password:', error);
        throw new Error('Failed to update password');
    }
});
//# sourceMappingURL=index.js.map
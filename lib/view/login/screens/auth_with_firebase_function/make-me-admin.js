const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Put your own UID from the Firebase Console here
const uid = 'KJT9vmLsmPZcNIJGpjJdlLU1eg42';

admin.auth().setCustomUserClaims(uid, { admin: true, superAdmin: true })
  .then(() => {
    console.log('Success! User is now a Super Admin.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('Error setting custom claims:', err);
    process.exit(1);
  });
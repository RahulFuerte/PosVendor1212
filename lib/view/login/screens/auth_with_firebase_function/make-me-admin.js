const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Get this from Firebase Console Settings

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

// Put your own UID from the Firebase Console here
const uid = 'kRB9InhcDEeCTL4ZgVwdLMqfK4B2'; 

admin.auth().setCustomUserClaims(uid, { admin: true })
  .then(() => console.log('Successfully made admin!'))
  .catch(err => console.error(err));
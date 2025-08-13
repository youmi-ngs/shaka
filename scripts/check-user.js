const admin = require('firebase-admin');
const serviceAccount = require('../firebase/secrets/shaka-shakatsu-firebase-adminsdk-fbsvc-3228372ad7.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function checkUser(uid) {
  console.log(`\nChecking user: ${uid}`);
  const doc = await db.collection('users').doc(uid).get();
  
  if (doc.exists) {
    const data = doc.data();
    console.log('User exists!');
    console.log('Data structure:', JSON.stringify(data, null, 2));
    
    // Check specific fields
    if (data.public) {
      console.log('\n✅ Has public data:');
      console.log('  - displayName:', data.public.displayName);
      console.log('  - photoURL:', data.public.photoURL);
    } else if (data.displayName) {
      console.log('\n⚠️  Has old structure (displayName at root level)');
      console.log('  - displayName:', data.displayName);
      console.log('  - photoURL:', data.photoURL);
    }
  } else {
    console.log('❌ User document does not exist');
  }
}

// Check the specific user
checkUser('SRF0jsggzwMUmS4JTBpZYHZYUX82').then(() => {
  console.log('\n--- Checking another user ---');
  return checkUser('sztwWCmTcebHZ2QGIQijHIjoHLx2');
}).then(() => process.exit());
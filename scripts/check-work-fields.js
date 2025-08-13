const admin = require('firebase-admin');
const serviceAccount = require('../firebase/secrets/shaka-shakatsu-firebase-adminsdk-fbsvc-3228372ad7.json');

if (\!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function checkWorkFields() {
  console.log('\n=== Checking Work Fields ===\n');
  
  const snapshot = await db.collection('works').limit(1).get();
  
  if (snapshot.empty) {
    console.log('No works found');
  } else {
    snapshot.forEach(doc => {
      console.log('Document ID:', doc.id);
      console.log('Fields:', Object.keys(doc.data()));
      console.log('Data:', JSON.stringify(doc.data(), null, 2));
    });
  }
}

checkWorkFields().then(() => process.exit()).catch(console.error);

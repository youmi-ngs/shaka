const admin = require('firebase-admin');
const serviceAccount = require('../firebase/secrets/shaka-shakatsu-firebase-adminsdk-fbsvc-3228372ad7.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function testUserRead() {
  console.log('\n=== Testing User Profile Read ===\n');
  
  const testUids = [
    'sztwWCmTcebHZ2QGIQijHIjoHLx2',
    'SRF0jsggzwMUmS4JTBpZYHZYUX82'
  ];
  
  for (const uid of testUids) {
    console.log(`\nReading profile for ${uid}:`);
    try {
      const doc = await db.collection('users').doc(uid).get();
      if (doc.exists) {
        const data = doc.data();
        console.log('✅ Profile found:');
        console.log('  Display Name:', data.public?.displayName || 'N/A');
        console.log('  Bio:', data.public?.bio || 'N/A');
        console.log('  Works Count:', data.stats?.worksCount || 0);
        console.log('  Questions Count:', data.stats?.questionsCount || 0);
      } else {
        console.log('❌ Profile not found');
      }
    } catch (error) {
      console.log('❌ Error reading profile:', error.message);
    }
  }
}

testUserRead().then(() => process.exit()).catch(console.error);
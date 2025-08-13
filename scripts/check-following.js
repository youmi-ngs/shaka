const admin = require('firebase-admin');
const serviceAccount = require('../firebase/secrets/shaka-shakatsu-firebase-adminsdk-fbsvc-3228372ad7.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function checkFollowing() {
  console.log('\n=== Checking Following Collection ===\n');
  
  // Check sztwWCmTcebHZ2QGIQijHIjoHLx2's following list
  const uid = 'sztwWCmTcebHZ2QGIQijHIjoHLx2';
  console.log(`Checking following list for user: ${uid}`);
  
  const followingSnapshot = await db.collection('following')
    .doc(uid)
    .collection('users')
    .get();
  
  if (followingSnapshot.empty) {
    console.log('❌ No following data found');
  } else {
    console.log(`✅ Found ${followingSnapshot.size} following:`);
    followingSnapshot.forEach(doc => {
      console.log(`  - ${doc.id}:`, doc.data());
    });
  }
  
  // Also check the old friends collection
  console.log('\n=== Checking Friends Collection (old) ===\n');
  const friendsSnapshot = await db.collection('friends')
    .doc(uid)
    .collection('list')
    .get();
    
  if (friendsSnapshot.empty) {
    console.log('❌ No friends data found');
  } else {
    console.log(`✅ Found ${friendsSnapshot.size} friends:`);
    friendsSnapshot.forEach(doc => {
      console.log(`  - ${doc.id}:`, doc.data());
    });
  }
}

checkFollowing().then(() => process.exit()).catch(console.error);
#!/usr/bin/env node

/**
 * 投稿数を正しくカウントして更新するスクリプト
 */

const admin = require('firebase-admin');
const path = require('path');

// サービスアカウントキー
const serviceAccount = require('../firebase/secrets/shaka-shakatsu-firebase-adminsdk-fbsvc-3228372ad7.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updateUserStats() {
  console.log('📊 Checking and updating user stats...\n');
  
  try {
    const usersSnapshot = await db.collection('users').get();
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const uid = userDoc.id;
      
      // 実際の投稿数をカウント
      const [worksSnapshot, questionsSnapshot] = await Promise.all([
        db.collection('works').where('userID', '==', uid).get(),
        db.collection('questions').where('userID', '==', uid).get()
      ]);
      
      const actualWorksCount = worksSnapshot.size;
      const actualQuestionsCount = questionsSnapshot.size;
      const savedWorksCount = userData.stats?.worksCount || 0;
      const savedQuestionsCount = userData.stats?.questionsCount || 0;
      
      const displayName = userData.public?.displayName || userData.displayName || `User_${uid.substring(0, 6)}`;
      
      console.log(`👤 ${displayName} (${uid})`);
      console.log(`   📷 Works: saved=${savedWorksCount}, actual=${actualWorksCount}`);
      console.log(`   ❓ Questions: saved=${savedQuestionsCount}, actual=${actualQuestionsCount}`);
      
      // 不一致があれば更新
      if (actualWorksCount !== savedWorksCount || actualQuestionsCount !== savedQuestionsCount) {
        console.log(`   ⚠️  Mismatch detected! Updating...`);
        
        await db.collection('users').doc(uid).update({
          'stats.worksCount': actualWorksCount,
          'stats.questionsCount': actualQuestionsCount
        });
        
        console.log(`   ✅ Updated successfully!`);
      } else {
        console.log(`   ✅ Already correct`);
      }
      
      console.log('');
    }
    
    console.log('✨ All stats have been checked and updated!');
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

// 実行
updateUserStats().then(() => {
  console.log('\n🎉 Done!');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
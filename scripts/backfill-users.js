#!/usr/bin/env node

/**
 * ユーザーデータのバックフィルスクリプト
 * 既存の users/{uid} データを新しい public/private/stats 構造に移行
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// ========== 設定 ==========
const DRY_RUN = process.argv.includes('--dry-run'); // ドライラン（実際の更新を行わない）
const BATCH_SIZE = 500; // Firestoreの1バッチあたりの最大操作数
const RATE_LIMIT_DELAY = 1000; // バッチ間の待機時間（ミリ秒）

// サービスアカウントキーのパス
const serviceAccountPath = path.join(__dirname, '../firebase/secrets/shaka-shakatsu-firebase-adminsdk-fbsvc-3228372ad7.json');

// ========== 初期化 ==========
if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ Service account key not found:', serviceAccountPath);
  console.error('Please download from Firebase Console > Project Settings > Service Accounts');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'shaka-shakatsu.appspot.com'
});

const db = admin.firestore();
const auth = admin.auth();

// ========== バックアップ ==========
async function backupUsers() {
  console.log('📦 Starting backup...');
  const backup = {};
  const usersSnapshot = await db.collection('users').get();
  
  usersSnapshot.forEach(doc => {
    backup[doc.id] = doc.data();
  });
  
  const backupPath = path.join(__dirname, `backup-users-${Date.now()}.json`);
  fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2));
  console.log(`✅ Backup saved to: ${backupPath}`);
  
  return backup;
}

// ========== ユーザー統計の計算 ==========
async function calculateUserStats(userId) {
  const [worksSnapshot, questionsSnapshot] = await Promise.all([
    db.collection('works').where('userID', '==', userId).count().get(),
    db.collection('questions').where('userID', '==', userId).count().get()
  ]);
  
  return {
    worksCount: worksSnapshot.data().count || 0,
    questionsCount: questionsSnapshot.data().count || 0
  };
}

// ========== バックフィル処理 ==========
async function backfillUser(userId, existingData, authUser) {
  const updates = {
    public: {},
    private: {},
    stats: {}
  };
  
  // public.displayName の設定
  if (existingData?.displayName) {
    updates.public.displayName = existingData.displayName;
  } else if (existingData?.public?.displayName) {
    updates.public.displayName = existingData.public.displayName;
  } else if (authUser?.displayName) {
    updates.public.displayName = authUser.displayName;
  } else {
    // デフォルト値を設定
    updates.public.displayName = `User_${userId.substring(0, 6)}`;
  }
  
  // その他のpublicフィールド
  updates.public.photoURL = existingData?.public?.photoURL || existingData?.photoURL || authUser?.photoURL || null;
  updates.public.bio = existingData?.public?.bio || existingData?.bio || null;
  updates.public.links = existingData?.public?.links || existingData?.links || null;
  
  // privateフィールド
  if (existingData?.private?.joinedAt) {
    updates.private.joinedAt = existingData.private.joinedAt;
  } else if (existingData?.joinedAt) {
    updates.private.joinedAt = existingData.joinedAt;
  } else if (authUser?.metadata?.creationTime) {
    updates.private.joinedAt = admin.firestore.Timestamp.fromDate(new Date(authUser.metadata.creationTime));
  } else {
    updates.private.joinedAt = admin.firestore.Timestamp.now();
  }
  
  updates.private.email = existingData?.private?.email || existingData?.email || authUser?.email || null;
  
  // stats の計算
  if (existingData?.stats) {
    updates.stats = existingData.stats;
  } else {
    updates.stats = await calculateUserStats(userId);
  }
  
  return updates;
}

// ========== メイン処理 ==========
async function main() {
  console.log('🚀 Starting user data backfill...');
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN' : 'PRODUCTION'}`);
  
  try {
    // 1. バックアップ
    const backup = await backupUsers();
    console.log(`📊 Found ${Object.keys(backup).length} users to process`);
    
    // 2. Authユーザーの取得
    console.log('🔐 Fetching Auth users...');
    const authUsers = {};
    let nextPageToken;
    
    do {
      const listResult = await auth.listUsers(1000, nextPageToken);
      listResult.users.forEach(user => {
        authUsers[user.uid] = user;
      });
      nextPageToken = listResult.pageToken;
    } while (nextPageToken);
    
    console.log(`📊 Found ${Object.keys(authUsers).length} Auth users`);
    
    // 3. バックフィル処理
    const userIds = Object.keys(backup);
    const results = {
      success: [],
      failed: [],
      skipped: []
    };
    
    // バッチ処理
    for (let i = 0; i < userIds.length; i += BATCH_SIZE) {
      const batch = db.batch();
      const batchUserIds = userIds.slice(i, i + BATCH_SIZE);
      
      console.log(`\n📝 Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(userIds.length / BATCH_SIZE)}`);
      
      for (const userId of batchUserIds) {
        try {
          const existingData = backup[userId];
          const authUser = authUsers[userId];
          
          // すでに新構造になっているかチェック
          if (existingData?.public?.displayName && existingData?.private?.joinedAt && existingData?.stats) {
            console.log(`⏭  Skipping ${userId} (already migrated)`);
            results.skipped.push(userId);
            continue;
          }
          
          const updates = await backfillUser(userId, existingData, authUser);
          
          console.log(`✨ Processing ${userId}:`);
          console.log(`   displayName: ${updates.public.displayName}`);
          console.log(`   stats: works=${updates.stats.worksCount}, questions=${updates.stats.questionsCount}`);
          
          if (!DRY_RUN) {
            const docRef = db.collection('users').doc(userId);
            batch.set(docRef, updates, { merge: true });
          }
          
          results.success.push(userId);
        } catch (error) {
          console.error(`❌ Failed to process ${userId}:`, error.message);
          results.failed.push({ userId, error: error.message });
        }
      }
      
      if (!DRY_RUN && results.success.length > 0) {
        await batch.commit();
        console.log(`✅ Batch committed`);
      }
      
      // レート制限対策
      if (i + BATCH_SIZE < userIds.length) {
        console.log(`⏳ Waiting ${RATE_LIMIT_DELAY}ms before next batch...`);
        await new Promise(resolve => setTimeout(resolve, RATE_LIMIT_DELAY));
      }
    }
    
    // 4. 結果の表示
    console.log('\n' + '='.repeat(50));
    console.log('📊 RESULTS:');
    console.log(`✅ Success: ${results.success.length} users`);
    console.log(`⏭  Skipped: ${results.skipped.length} users (already migrated)`);
    console.log(`❌ Failed: ${results.failed.length} users`);
    
    if (results.failed.length > 0) {
      console.log('\n❌ Failed users:');
      results.failed.forEach(({ userId, error }) => {
        console.log(`  - ${userId}: ${error}`);
      });
    }
    
    // 5. 検証
    if (!DRY_RUN) {
      console.log('\n🔍 Verifying migration...');
      let missingDisplayName = 0;
      
      for (const userId of results.success) {
        const doc = await db.collection('users').doc(userId).get();
        const data = doc.data();
        
        if (!data?.public?.displayName) {
          missingDisplayName++;
          console.log(`⚠️  User ${userId} is missing displayName`);
        }
      }
      
      console.log(`\n✅ Verification complete: ${missingDisplayName} users missing displayName`);
    }
    
    if (DRY_RUN) {
      console.log('\n⚠️  DRY RUN COMPLETE - No changes were made');
      console.log('Run without --dry-run flag to perform actual migration');
    }
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  }
}

// ========== Cloud Functions用の統計更新関数（将来実装用） ==========
const statsUpdateFunction = `
// Cloud Functions での統計自動更新（functions/index.js に追加）

exports.updateWorksCount = functions.firestore
  .document('works/{workId}')
  .onWrite(async (change, context) => {
    const userId = change.after.exists ? 
      change.after.data().userID : 
      change.before.data().userID;
    
    if (!userId) return;
    
    const worksCount = await admin.firestore()
      .collection('works')
      .where('userID', '==', userId)
      .count()
      .get();
    
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        'stats.worksCount': worksCount.data().count || 0
      });
  });

exports.updateQuestionsCount = functions.firestore
  .document('questions/{questionId}')
  .onWrite(async (change, context) => {
    const userId = change.after.exists ? 
      change.after.data().userID : 
      change.before.data().userID;
    
    if (!userId) return;
    
    const questionsCount = await admin.firestore()
      .collection('questions')
      .where('userID', '==', userId)
      .count()
      .get();
    
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        'stats.questionsCount': questionsCount.data().count || 0
      });
  });
`;

// ========== 実行 ==========
main().then(() => {
  console.log('\n✨ Script completed successfully');
  process.exit(0);
}).catch(error => {
  console.error('\n❌ Script failed:', error);
  process.exit(1);
});
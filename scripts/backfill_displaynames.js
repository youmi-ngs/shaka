#!/usr/bin/env node

/**
 * displayNameバックフィルスクリプト
 * 既存の投稿にdisplayNameを追加または更新
 */

const admin = require('firebase-admin');
const serviceAccount = require('../path-to-your-service-account-key.json');

// Firebaseの初期化
admin.initializeApp({
  credential: admin.cert(serviceAccount)
});

const db = admin.firestore();

async function backfillDisplayNames() {
  console.log('🚀 Starting displayName backfill...');
  
  const stats = {
    users: 0,
    worksUpdated: 0,
    questionsUpdated: 0,
    errors: []
  };

  try {
    // 全ユーザーを取得
    const usersSnapshot = await db.collection('users').get();
    stats.users = usersSnapshot.size;
    console.log(`📊 Found ${stats.users} users`);

    // バッチサイズ設定（Firestoreの制限）
    const BATCH_SIZE = 500;
    let batch = db.batch();
    let operationCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      const displayName = userData.displayName || `User_${userId.substring(0, 6)}`;
      
      console.log(`\n👤 Processing user: ${userId}`);
      console.log(`   Display name: ${displayName}`);

      // Works コレクションの更新
      const worksQuery = await db.collection('works')
        .where('userID', '==', userId)
        .get();
      
      console.log(`   Found ${worksQuery.size} works`);

      for (const workDoc of worksQuery.docs) {
        const currentData = workDoc.data();
        
        // displayNameが異なる場合のみ更新
        if (currentData.displayName !== displayName) {
          batch.update(workDoc.ref, {
            displayName: displayName,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          
          operationCount++;
          stats.worksUpdated++;
          
          // バッチが満杯になったらコミット
          if (operationCount >= BATCH_SIZE - 1) {
            await batch.commit();
            console.log(`   ✅ Committed batch (${operationCount} operations)`);
            batch = db.batch();
            operationCount = 0;
          }
        }
      }

      // Questions コレクションの更新
      const questionsQuery = await db.collection('questions')
        .where('userID', '==', userId)
        .get();
      
      console.log(`   Found ${questionsQuery.size} questions`);

      for (const questionDoc of questionsQuery.docs) {
        const currentData = questionDoc.data();
        
        if (currentData.displayName !== displayName) {
          batch.update(questionDoc.ref, {
            displayName: displayName,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          
          operationCount++;
          stats.questionsUpdated++;
          
          if (operationCount >= BATCH_SIZE - 1) {
            await batch.commit();
            console.log(`   ✅ Committed batch (${operationCount} operations)`);
            batch = db.batch();
            operationCount = 0;
          }
        }
      }
    }

    // 残りのバッチをコミット
    if (operationCount > 0) {
      await batch.commit();
      console.log(`✅ Committed final batch (${operationCount} operations)`);
    }

    // 結果レポート
    console.log('\n' + '='.repeat(50));
    console.log('📊 BACKFILL COMPLETED');
    console.log('='.repeat(50));
    console.log(`Total users processed: ${stats.users}`);
    console.log(`Works updated: ${stats.worksUpdated}`);
    console.log(`Questions updated: ${stats.questionsUpdated}`);
    console.log(`Total posts updated: ${stats.worksUpdated + stats.questionsUpdated}`);
    
    if (stats.errors.length > 0) {
      console.log('\n⚠️ Errors encountered:');
      stats.errors.forEach(err => console.log(`  - ${err}`));
    }

  } catch (error) {
    console.error('❌ Fatal error during backfill:', error);
    process.exit(1);
  }

  process.exit(0);
}

// ドライラン機能
async function dryRun() {
  console.log('🔍 DRY RUN MODE - No changes will be made');
  
  const usersSnapshot = await db.collection('users').get();
  console.log(`Found ${usersSnapshot.size} users`);

  let totalWorks = 0;
  let totalQuestions = 0;
  let needsUpdate = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const userData = userDoc.data();
    const displayName = userData.displayName || `User_${userId.substring(0, 6)}`;

    const worksQuery = await db.collection('works')
      .where('userID', '==', userId)
      .get();
    
    const questionsQuery = await db.collection('questions')
      .where('userID', '==', userId)
      .get();

    totalWorks += worksQuery.size;
    totalQuestions += questionsQuery.size;

    // 更新が必要な投稿をカウント
    worksQuery.forEach(doc => {
      if (doc.data().displayName !== displayName) needsUpdate++;
    });
    
    questionsQuery.forEach(doc => {
      if (doc.data().displayName !== displayName) needsUpdate++;
    });
  }

  console.log('\n📊 DRY RUN RESULTS:');
  console.log(`Total works: ${totalWorks}`);
  console.log(`Total questions: ${totalQuestions}`);
  console.log(`Posts needing update: ${needsUpdate}`);
  console.log(`Estimated Firestore writes: ${needsUpdate}`);
  console.log(`Estimated cost: $${(needsUpdate * 0.00002).toFixed(4)} USD`);
}

// コマンドライン引数の処理
const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');

if (isDryRun) {
  dryRun().catch(console.error);
} else {
  console.log('⚠️  This will update all posts in your Firestore database.');
  console.log('   Run with --dry-run flag to preview changes.');
  console.log('   Press Ctrl+C to cancel, or wait 5 seconds to continue...\n');
  
  setTimeout(() => {
    backfillDisplayNames().catch(console.error);
  }, 5000);
}
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

/**
 * ユーザーのdisplayName変更時に、全投稿のdisplayNameを更新
 */
exports.syncDisplayName = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const newData = change.after.data();
    const oldData = change.before.data();

    // displayNameが変更されていない場合はスキップ
    if (newData.displayName === oldData.displayName) {
      console.log(`No displayName change for user ${userId}`);
      return null;
    }

    const newDisplayName = newData.displayName;
    console.log(`Updating displayName for user ${userId} to: ${newDisplayName}`);

    // バッチ処理の準備
    const batchArray = [];
    batchArray.push(db.batch());
    let operationCounter = 0;
    let batchIndex = 0;

    try {
      // Works コレクションの更新
      const worksQuery = await db.collection('works')
        .where('userID', '==', userId)
        .get();

      worksQuery.forEach((doc) => {
        batchArray[batchIndex].update(doc.ref, {
          displayName: newDisplayName,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        operationCounter++;

        // Firestoreのバッチは最大500操作
        if (operationCounter === 499) {
          batchArray.push(db.batch());
          batchIndex++;
          operationCounter = 0;
        }
      });

      // Questions コレクションの更新
      const questionsQuery = await db.collection('questions')
        .where('userID', '==', userId)
        .get();

      questionsQuery.forEach((doc) => {
        batchArray[batchIndex].update(doc.ref, {
          displayName: newDisplayName,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        operationCounter++;

        if (operationCounter === 499) {
          batchArray.push(db.batch());
          batchIndex++;
          operationCounter = 0;
        }
      });

      // 全バッチをコミット
      const commitPromises = batchArray.map((batch) => batch.commit());
      await Promise.all(commitPromises);

      const totalUpdated = worksQuery.size + questionsQuery.size;
      console.log(`Successfully updated ${totalUpdated} posts for user ${userId}`);
      
      return { success: true, updated: totalUpdated };

    } catch (error) {
      console.error('Error updating displayName:', error);
      throw new functions.https.HttpsError('internal', 'Failed to update displayName', error);
    }
  });

/**
 * 既存データのバックフィル用HTTPトリガー（手動実行用）
 */
exports.backfillDisplayNames = functions.https.onRequest(async (req, res) => {
  // セキュリティ：管理者のみ実行可能にする場合はトークン検証を追加
  const secretToken = req.headers.authorization;
  if (secretToken !== 'Bearer YOUR-SECRET-TOKEN') {
    res.status(401).send('Unauthorized');
    return;
  }

  try {
    const usersSnapshot = await db.collection('users').get();
    let totalUpdated = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const displayName = userDoc.data().displayName || `User_${userId.substring(0, 6)}`;

      // Works更新
      const worksBatch = db.batch();
      const worksQuery = await db.collection('works')
        .where('userID', '==', userId)
        .get();

      worksQuery.forEach((doc) => {
        if (doc.data().displayName !== displayName) {
          worksBatch.update(doc.ref, {
            displayName: displayName,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      });

      if (worksQuery.size > 0) {
        await worksBatch.commit();
        totalUpdated += worksQuery.size;
      }

      // Questions更新
      const questionsBatch = db.batch();
      const questionsQuery = await db.collection('questions')
        .where('userID', '==', userId)
        .get();

      questionsQuery.forEach((doc) => {
        if (doc.data().displayName !== displayName) {
          questionsBatch.update(doc.ref, {
            displayName: displayName,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      });

      if (questionsQuery.size > 0) {
        await questionsBatch.commit();
        totalUpdated += questionsQuery.size;
      }
    }

    res.json({
      success: true,
      message: `Backfill completed. Updated ${totalUpdated} posts.`
    });

  } catch (error) {
    console.error('Backfill error:', error);
    res.status(500).json({ error: error.message });
  }
});
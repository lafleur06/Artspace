const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

initializeApp();
const db = getFirestore();

exports.sendOfferNotification = onDocumentCreated("offers/{offerId}", async (event) => {
  const offerData = event.data.data();

  const toUserId = offerData.toUserId;
  const amount = offerData.amount?.toFixed(2) ?? '0.00';
  const artworkTitle = offerData.artworkTitle ?? 'bir eser';

  const userDoc = await db.collection('users').doc(toUserId).get();
  const fcmToken = userDoc.data()?.fcmToken;

  if (!fcmToken) {
    logger.warn("❌ Kullanıcının fcmToken'ı yok");
    return;
  }

  const message = {
    notification: {
      title: "Yeni Teklif",
      body: `'${artworkTitle}' adlı eser için ₺${amount} teklif verildi.`,
    },
    token: fcmToken,
  };

  try {
    const response = await getMessaging().send(message);
    logger.info("✅ Bildirim gönderildi:", response);
  } catch (error) {
    logger.error("❌ Bildirim gönderilirken hata:", error);
  }
});

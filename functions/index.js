const express = require('express');
const bodyParser = require('body-parser');
const stripe = require('stripe')('sk_test_51RY61mH5lK8DjHeUNKvhvjoYKbLNsLkS2pcqNEzosTu5mp6GgMFuATHjm6VPppWWFIqXpJympCSMUvpPUqMsK0bg00KES97bDM'); // Stripe Secret Key
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const logger = require('firebase-functions/logger');
const functions = require('firebase-functions');

const app = express();

initializeApp();
const db = getFirestore();

app.use(bodyParser.json());

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

app.post('/create-payment-intent', async (req, res) => {
  try {
    const { amount, currency } = req.body;
    
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount, 
      currency: currency,
    });

    res.json({
      client_secret: paymentIntent.client_secret,
    });
  } catch (error) {
    console.error("Error creating PaymentIntent:", error);
    res.status(500).send({ error: error.message });
  }
});

exports.api = functions.https.onRequest(app);

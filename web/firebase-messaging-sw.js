importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker
firebase.initializeApp({
  apiKey: 'AIzaSyA0A9UT9YieVXf1h-lzPcq5djsjoGYSwJQ',
  appId: '1:237461278663:web:be1c0869ef58ca9dea53e2',
  messagingSenderId: '237461278663',
  projectId: 'kuryenteapp',
  authDomain: 'kuryenteapp.firebaseapp.com',
  storageBucket: 'kuryenteapp.firebasestorage.app',
});

// Retrieve an instance of Firebase Messaging
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png',
    badge: '/favicon.png',
    data: payload.data
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

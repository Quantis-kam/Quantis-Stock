// Quantis Stock — Service Worker léger (zéro cache figé)
// Active l'installation native PWA / WebAPK sur Android, iOS et PC
// tout en garantissant des mises à jour instantanées à chaque ouverture.

self.addEventListener('install', function() {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(keys.map(function(k) { return caches.delete(k); }));
    }).then(function() {
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', function() {
  // Passage direct au réseau : aucune ressource JS/HTML n'est mise en cache par le SW.
});


self.addEventListener("fetch",function(e){e.respondWith(fetch(e.request).catch(function(){return caches.match(e.request)}))});self.addEventListener("install",function(e){self.skipWaiting()});

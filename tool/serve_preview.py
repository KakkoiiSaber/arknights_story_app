"""Serve local Flutter previews without stale offline-worker snapshots.

Only the development preview entry is changed; production build files stay intact.
"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1] / 'build' / 'web'

class PreviewHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def do_GET(self):
        if urlsplit(self.path).path in ('/', '/index.html'):
            source = (ROOT / 'index.html').read_text(encoding='utf-8')
            # Retire only Flutter's caches on this local preview origin. A
            # previously installed worker can otherwise serve last build's JS.
            loader = """<script>
(async () => {
  if ('serviceWorker' in navigator) {
    const workers = await navigator.serviceWorker.getRegistrations();
    await Promise.all(workers.map(worker => worker.unregister()));
  }
  if ('caches' in window) {
    await Promise.all(['flutter-app-cache','flutter-temp-cache','flutter-app-manifest'].map(key => caches.delete(key)));
  }
  const script = document.createElement('script');
  script.src = 'flutter_bootstrap.js?preview=BUILD_STAMP';
  document.body.appendChild(script);
})();
</script>""".replace('BUILD_STAMP', str((ROOT / 'main.dart.js').stat().st_mtime_ns))
            source = source.replace('<script src="flutter_bootstrap.js" async></script>', loader)
            payload = source.encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        super().do_GET()

if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 8766), partial(PreviewHandler, directory=str(ROOT))).serve_forever()

import React from 'react';
import ReactDOM from 'react-dom/client';
import '@fontsource/gveret-levin/index.css';
import App from './App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

if (
  typeof window !== 'undefined' &&
  'serviceWorker' in navigator &&
  !window.electronAPI &&
  (window.location.protocol === 'https:' ||
    (window.location.protocol === 'http:' && window.location.hostname === 'localhost'))
) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {
      // Ignore registration errors in unsupported contexts
    });
  });
}

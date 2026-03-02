(function () {
  if (!window.betaConfig || !window.betaConfig.isBeta) return;

  var version = window.betaConfig.version || '';
  var timestamp = window.betaConfig.timestamp || '';
  var label = 'Beta / Prerelease Documentation - Subject to change.';
  if (version || timestamp) {
    label += ' (Api version ' + version + ' | Published on ' + timestamp + ')';
  }

  // Push navbar down so it sits below the fixed banner
  var style = document.createElement('style');
  style.textContent = '.navbar { top: 50px !important; } body { padding-top: 100px !important; }';
  document.head.appendChild(style);

  // Insert the fixed banner as the very first child of <body>
  var banner = document.createElement('div');
  banner.id = 'beta-banner';
  banner.setAttribute('style',
    'background:#fff3cd;border-bottom:3px solid #ffc107;padding:12px 15px;' +
    'width:100%;box-sizing:border-box;text-align:center;color:#856404;' +
    'font-weight:700;font-size:14px;position:fixed;top:0;left:0;right:0;z-index:99999;'
  );
  banner.textContent = '\u26a0\ufe0f ' + label;
  document.body.insertBefore(banner, document.body.firstChild);
})();

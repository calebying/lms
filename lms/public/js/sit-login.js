/* SIT branding injected on login/signup pages */
(function () {
	var path = window.location.pathname;
	var isAuthPage = path === '/login' || path === '/login/' ||
		path.startsWith('/new-sign-up') || path === '/signup';

	if (!isAuthPage) return;

	frappe.ready(function () {
		injectHeader();
		injectFooter();
		stylePageTitle();
	});

	function injectHeader() {
		if (document.querySelector('.sit-login-header')) return;

		var header = document.createElement('div');
		header.className = 'sit-login-header';
		header.innerHTML =
			'<div class="sit-logo-block">' +
				'<div class="sit-logo-box">' +
					'<span class="sit-text">SiT</span>' +
					'<span class="sit-red-dot"></span>' +
				'</div>' +
				'<div>' +
					'<div class="sit-brand-name">SIT Learning Portal</div>' +
					'<div class="sit-brand-sub">Singapore Institute of Technology</div>' +
				'</div>' +
			'</div>';

		document.body.insertBefore(header, document.body.firstChild);
	}

	function injectFooter() {
		if (document.querySelector('.sit-login-footer')) return;

		var footer = document.createElement('div');
		footer.className = 'sit-login-footer';
		footer.innerHTML =
			'<span>&copy; 2025 Singapore Institute of Technology. All rights reserved.</span>' +
			'<div class="sit-footer-links">' +
				'<a href="https://www.singaporetech.edu.sg/terms-of-use" target="_blank" rel="noopener">Terms of Use</a>' +
				'<span class="sit-footer-sep">|</span>' +
				'<a href="https://www.singaporetech.edu.sg/privacy-statement" target="_blank" rel="noopener">Privacy Policy</a>' +
				'<span class="sit-footer-sep">|</span>' +
				'<a href="https://www.singaporetech.edu.sg/accessibility" target="_blank" rel="noopener">Accessibility</a>' +
			'</div>';

		document.body.appendChild(footer);

		/* Add bottom padding so the login form isn't hidden behind footer */
		document.body.style.paddingBottom = '48px';
	}

	function stylePageTitle() {
		/* Replace generic page title with SIT-specific wording */
		var title = document.querySelector('.for-login h4, .login-content h4, .page-card h4, h1.title');
		if (title && title.textContent.trim().toLowerCase() === 'login') {
			title.textContent = 'Sign in to SIT Learning';
		}
	}
})();

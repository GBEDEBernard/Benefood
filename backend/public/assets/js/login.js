(() => {
    'use strict';

    const passwordInput = document.getElementById('password');
    const passwordToggle = document.querySelector('[data-password-toggle]');

    if (passwordInput && passwordToggle) {
        passwordToggle.hidden = false;

        passwordToggle.addEventListener('click', () => {
            const isVisible = passwordInput.type === 'text';

            passwordInput.type = isVisible ? 'password' : 'text';
            passwordToggle.classList.toggle('is-visible', !isVisible);
            passwordToggle.setAttribute('aria-pressed', String(!isVisible));
            passwordToggle.setAttribute(
                'aria-label',
                isVisible ? 'Afficher le mot de passe' : 'Masquer le mot de passe'
            );
            passwordInput.focus({ preventScroll: true });
        });
    }

    const form = document.querySelector('[data-login-form]');
    const submitButton = document.querySelector('[data-submit-button]');
    const submitLabel = document.querySelector('[data-submit-label]');

    if (!form || !submitButton || !submitLabel) {
        return;
    }

    let submitting = false;

    const resetSubmitState = () => {
        submitting = false;
        submitButton.disabled = false;
        submitButton.classList.remove('is-loading');
        submitButton.removeAttribute('aria-busy');
        submitLabel.textContent = 'Se connecter';
    };

    form.addEventListener('submit', (event) => {
        if (submitting) {
            event.preventDefault();
            return;
        }

        submitting = true;
        submitButton.disabled = true;
        submitButton.classList.add('is-loading');
        submitButton.setAttribute('aria-busy', 'true');
        submitLabel.textContent = 'Connexion en cours…';
    });

    window.addEventListener('pageshow', (event) => {
        if (event.persisted) {
            resetSubmitState();
        }
    });
})();

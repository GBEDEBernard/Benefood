(function () {
    'use strict';

    const page = document.querySelector('.orders-page');

    if (!page) {
        return;
    }

    let toast;
    let toastTimer;

    function showToast(message) {
        if (!toast) {
            toast = document.createElement('div');
            toast.className = 'orders-toast';

            const icon = document.createElement('i');
            icon.className = 'ti ti-circle-check';
            icon.setAttribute('aria-hidden', 'true');

            const label = document.createElement('span');

            toast.append(icon, label);
            document.body.appendChild(toast);
        }

        const label = toast.querySelector('span');

        if (label) {
            label.textContent = message;
        }

        window.requestAnimationFrame(function () {
            toast.classList.add('is-visible');
        });

        window.clearTimeout(toastTimer);
        toastTimer = window.setTimeout(function () {
            toast.classList.remove('is-visible');
        }, 2400);
    }

    function legacyCopy(value) {
        const textarea = document.createElement('textarea');
        textarea.value = value;
        textarea.setAttribute('readonly', '');
        textarea.style.position = 'fixed';
        textarea.style.top = '-9999px';
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        textarea.remove();
    }

    async function copyValue(value) {
        if (navigator.clipboard && window.isSecureContext) {
            await navigator.clipboard.writeText(value);

            return;
        }

        legacyCopy(value);
    }

    page.addEventListener('click', async function (event) {
        const button = event.target.closest('[data-copy-order]');

        if (!button) {
            return;
        }

        const value = button.getAttribute('data-copy-order');

        if (!value) {
            return;
        }

        try {
            await copyValue(value);
        } catch (error) {
            legacyCopy(value);
        }

        const icon = button.querySelector('i');
        const previousIcon = icon ? icon.className : '';

        if (icon) {
            icon.className = 'ti ti-check';
        }

        button.classList.add('is-copied');

        window.setTimeout(function () {
            button.classList.remove('is-copied');

            if (icon) {
                icon.className = previousIcon;
            }
        }, 1800);

        showToast(button.getAttribute('data-copy-label') || 'Référence copiée');
    });

    page.querySelectorAll('[data-dismiss-flash]').forEach(function (button) {
        button.addEventListener('click', function () {
            const flash = button.closest('[data-orders-flash]');

            if (flash) {
                flash.remove();
            }
        });
    });

    page.querySelectorAll('[data-orders-page-size]').forEach(function (select) {
        select.addEventListener('change', function () {
            if (select.form) {
                select.form.requestSubmit();
            }
        });
    });

    const filterForm = page.querySelector('[data-orders-filter]');

    if (filterForm) {
        const submitButton = filterForm.querySelector('[data-orders-submit]');
        const fromInput = filterForm.elements.namedItem('from');
        const toInput = filterForm.elements.namedItem('to');

        function validateDates() {
            if (!(fromInput instanceof HTMLInputElement) || !(toInput instanceof HTMLInputElement)) {
                return true;
            }

            if (fromInput.value && toInput.value && fromInput.value > toInput.value) {
                toInput.setCustomValidity('La date de fin doit être postérieure ou égale à la date de début.');

                return false;
            }

            toInput.setCustomValidity('');

            return true;
        }

        if (fromInput instanceof HTMLInputElement) {
            fromInput.addEventListener('change', validateDates);
        }

        if (toInput instanceof HTMLInputElement) {
            toInput.addEventListener('change', validateDates);
        }

        filterForm.addEventListener('submit', function (event) {
            if (!validateDates()) {
                event.preventDefault();

                if (toInput instanceof HTMLInputElement) {
                    toInput.reportValidity();
                }

                return;
            }

            if (submitButton) {
                submitButton.classList.add('is-loading');
                submitButton.setAttribute('aria-busy', 'true');
            }
        });
    }
})();

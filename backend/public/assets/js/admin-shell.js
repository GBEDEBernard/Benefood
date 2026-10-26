(function (window, document) {
    'use strict';

    var root = document.documentElement;
    var body = document.body;
    var storageKey = 'bf.sidebar.collapsed';
    var desktopQuery = window.matchMedia('(min-width: 992px)');
    var mobileQuery = window.matchMedia('(max-width: 991px)');
    var sidebar = document.getElementById('bfSidebar');
    var sidebarToggle = document.getElementById('bfSidebarToggle');
    var mobileToggle = document.getElementById('bfMobileSidebarToggle');
    var labelledLinks = sidebar ? Array.prototype.slice.call(sidebar.querySelectorAll('[data-bf-label]')) : [];
    var collapsed = false;

    try {
        collapsed = window.localStorage.getItem(storageKey) === '1';
    } catch (error) {
        collapsed = false;
    }

    function saveCollapsed(value) {
        try {
            window.localStorage.setItem(storageKey, value ? '1' : '0');
        } catch (error) {}
    }

    function syncSidebarTitles(isCollapsed) {
        labelledLinks.forEach(function (link) {
            if (isCollapsed) {
                link.setAttribute('title', link.getAttribute('data-bf-label') || '');
            } else {
                link.removeAttribute('title');
            }
        });
    }

    function syncSidebarToggle() {
        if (!sidebarToggle) {
            return;
        }

        sidebarToggle.setAttribute('aria-expanded', String(!collapsed));
        sidebarToggle.setAttribute('aria-label', collapsed ? 'Déplier la navigation' : 'Réduire la navigation');
    }

    function setCollapsed(next, persist) {
        collapsed = next;

        if (desktopQuery.matches) {
            root.classList.toggle('bf-sidebar-collapsed', collapsed);
            syncSidebarTitles(collapsed);
        } else {
            root.classList.remove('bf-sidebar-collapsed');
            syncSidebarTitles(false);
        }

        if (persist) {
            saveCollapsed(collapsed);
        }

        syncSidebarToggle();
    }

    function setMobileSidebar(open) {
        body.classList.toggle('sidebar-toggled', open);

        if (mobileToggle) {
            mobileToggle.setAttribute('aria-expanded', String(open));
            mobileToggle.setAttribute('aria-label', open ? 'Fermer la navigation' : 'Ouvrir la navigation');
        }
    }

    function closeMobileSidebar() {
        if (body.classList.contains('sidebar-toggled')) {
            setMobileSidebar(false);
        }
    }

    if (sidebarToggle) {
        sidebarToggle.addEventListener('click', function (event) {
            event.preventDefault();

            if (!desktopQuery.matches) {
                return;
            }

            setCollapsed(!collapsed, true);
        });
    }

    if (mobileToggle) {
        mobileToggle.addEventListener('click', function (event) {
            event.preventDefault();
            setMobileSidebar(!body.classList.contains('sidebar-toggled'));
        });
    }

    labelledLinks.forEach(function (link) {
        if (!link.classList.contains('has-arrow')) {
            return;
        }

        link.addEventListener('click', function () {
            if (desktopQuery.matches && root.classList.contains('bf-sidebar-collapsed')) {
                setCollapsed(false, true);
            }
        });
    });

    function syncViewport() {
        if (desktopQuery.matches) {
            closeMobileSidebar();
            setCollapsed(collapsed, false);
            return;
        }

        root.classList.remove('bf-sidebar-collapsed');
        syncSidebarTitles(false);
        syncSidebarToggle();
    }

    if (typeof desktopQuery.addEventListener === 'function') {
        desktopQuery.addEventListener('change', syncViewport);
    } else if (typeof desktopQuery.addListener === 'function') {
        desktopQuery.addListener(syncViewport);
    }

    syncViewport();

    var search = document.querySelector('[data-bf-search]');

    if (search) {
        var input = search.querySelector('input[name="q"]');
        var panel = search.querySelector('.bf-search-panel');
        var clearButton = search.querySelector('.bf-search-clear');
        var closeButton = search.querySelector('.bf-search-close');
        var shortcut = search.querySelector('.bf-search-kbd');
        var mobileSearchToggle = document.querySelector('.bf-mobile-search-toggle');
        var state = {
            items: [],
            activeIndex: -1,
            timer: null,
            controller: null,
            lastQuery: null,
            lastGroups: null
        };

        var make = function (tag, className, text) {
            var node = document.createElement(tag);

            if (className) {
                node.className = className;
            }

            if (text !== undefined) {
                node.textContent = text;
            }

            return node;
        };

        var icon = function (name, className) {
            return make('i', 'ti ' + name + (className ? ' ' + className : ''));
        };

        var resultsUrl = function (query) {
            var url = new URL(search.action, window.location.origin);

            if (query === '') {
                url.searchParams.delete('q');
            } else {
                url.searchParams.set('q', query);
            }

            return url;
        };

        var openPanel = function () {
            panel.hidden = false;
            input.setAttribute('aria-expanded', 'true');
            search.classList.add('is-open');
        };

        var closePanel = function () {
            panel.hidden = true;
            input.setAttribute('aria-expanded', 'false');
            input.removeAttribute('aria-activedescendant');
            search.classList.remove('is-open');
            setActive(-1);
        };

        var setActive = function (index) {
            if (state.activeIndex >= 0 && state.items[state.activeIndex]) {
                state.items[state.activeIndex].classList.remove('is-active');
                state.items[state.activeIndex].setAttribute('aria-selected', 'false');
            }

            state.activeIndex = index;

            if (index < 0 || !state.items[index]) {
                input.removeAttribute('aria-activedescendant');
                return;
            }

            state.items[index].classList.add('is-active');
            state.items[index].setAttribute('aria-selected', 'true');
            input.setAttribute('aria-activedescendant', state.items[index].id);
            state.items[index].scrollIntoView({ block: 'nearest' });
        };

        var renderMessage = function (iconName, title, description, spinning) {
            state.items = [];
            state.activeIndex = -1;
            panel.textContent = '';

            var wrap = make('div', 'bf-search-empty-state');
            var mark = make('span', 'bf-search-empty-state__icon');
            mark.appendChild(icon(iconName, spinning ? 'bf-spin' : ''));
            wrap.appendChild(mark);
            wrap.appendChild(make('strong', '', title));

            if (description) {
                wrap.appendChild(make('span', '', description));
            }

            panel.appendChild(wrap);
            openPanel();
        };

        var renderResults = function (groups, query) {
            state.items = [];
            state.activeIndex = -1;
            panel.textContent = '';

            if (!Array.isArray(groups) || groups.length === 0) {
                renderMessage('ti-search', 'Aucun résultat', 'Essayez une référence, un nom, un téléphone ou une page.');
                return;
            }

            groups.forEach(function (group) {
                var section = make('section', 'bf-search-group');
                var head = make('div', 'bf-search-group__head');
                var groupIcon = make('span', 'bf-search-group__icon');
                groupIcon.appendChild(icon(group.icon || 'ti-search'));
                head.appendChild(groupIcon);
                head.appendChild(make('h3', '', group.label));
                head.appendChild(make('span', 'bf-search-group__count', String(group.items.length)));
                section.appendChild(head);

                var list = make('div', 'bf-search-group__items');

                group.items.forEach(function (item) {
                    var index = state.items.length;
                    var link = make('a', 'bf-search-result');
                    link.href = item.url;
                    link.id = 'bf-search-option-' + index;
                    link.setAttribute('role', 'option');
                    link.setAttribute('aria-selected', 'false');

                    var mark = make('span', 'bf-search-result__icon');
                    mark.appendChild(icon(item.icon || 'ti-arrow-right'));
                    link.appendChild(mark);

                    var content = make('span', 'bf-search-result__body');
                    content.appendChild(make('strong', '', item.label));

                    if (item.description) {
                        content.appendChild(make('small', '', item.description));
                    }

                    link.appendChild(content);
                    link.appendChild(icon('ti-arrow-right', 'bf-search-result__arrow'));
                    link.addEventListener('mouseenter', function () {
                        setActive(index);
                    });
                    link.addEventListener('focus', function () {
                        setActive(index);
                    });

                    state.items.push(link);
                    list.appendChild(link);
                });

                section.appendChild(list);
                panel.appendChild(section);
            });

            if (query !== '') {
                var all = make('a', 'bf-search-all');
                all.href = resultsUrl(query).toString();
                all.appendChild(make('span', '', 'Voir tous les résultats'));
                all.appendChild(make('strong', '', '« ' + query + ' »'));
                all.appendChild(icon('ti-arrow-right'));
                panel.appendChild(all);
            }

            openPanel();
        };

        var updateClear = function () {
            var hasValue = input.value.trim() !== '';
            clearButton.hidden = !hasValue;
            shortcut.hidden = hasValue;
        };

        var fetchResults = function (query) {
            if (state.controller) {
                state.controller.abort();
            }

            var controller = new AbortController();
            state.controller = controller;
            search.classList.add('is-loading');
            renderMessage('ti-reload', 'Recherche en cours…', '', true);

            fetch(resultsUrl(query).toString(), {
                credentials: 'same-origin',
                headers: {
                    'Accept': 'application/json',
                    'X-Requested-With': 'XMLHttpRequest'
                },
                signal: controller.signal
            })
                .then(function (response) {
                    if (!response.ok) {
                        throw new Error('Search request failed');
                    }

                    return response.json();
                })
                .then(function (data) {
                    if (input.value.trim() !== query) {
                        return;
                    }

                    state.lastQuery = query;
                    state.lastGroups = data.groups || [];
                    renderResults(state.lastGroups, query);
                })
                .catch(function (error) {
                    if (error.name === 'AbortError') {
                        return;
                    }

                    renderMessage('ti-alert', 'Recherche indisponible', 'Vérifiez votre connexion et réessayez.');
                })
                .finally(function () {
                    if (state.controller === controller) {
                        state.controller = null;
                        search.classList.remove('is-loading');
                    }
                });
        };

        var scheduleSearch = function () {
            var query = input.value.trim();
            window.clearTimeout(state.timer);
            updateClear();

            if (query.length === 1) {
                renderMessage('ti-search', 'Saisissez au moins 2 caractères', 'La recherche devient plus précise dès deux caractères.');
                return;
            }

            if (query !== '' && query === state.lastQuery && state.lastGroups !== null) {
                renderResults(state.lastGroups, query);
                return;
            }

            state.timer = window.setTimeout(function () {
                fetchResults(query);
            }, query === '' ? 0 : 180);
        };

        var setMobileSearch = function (open) {
            body.classList.toggle('bf-search-open', open);

            if (mobileSearchToggle) {
                mobileSearchToggle.setAttribute('aria-expanded', String(open));
                mobileSearchToggle.setAttribute('aria-label', open ? 'Fermer la recherche' : 'Ouvrir la recherche');
            }

            if (open) {
                setMobileSidebar(false);
                window.setTimeout(function () {
                    input.focus();
                    input.select();
                    scheduleSearch();
                }, 30);
            } else {
                closePanel();
            }
        };

        input.addEventListener('focus', function () {
            scheduleSearch();
        });

        input.addEventListener('input', scheduleSearch);

        input.addEventListener('keydown', function (event) {
            if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
                if (panel.hidden) {
                    scheduleSearch();
                }

                if (state.items.length === 0) {
                    return;
                }

                event.preventDefault();

                if (event.key === 'ArrowDown') {
                    setActive((state.activeIndex + 1) % state.items.length);
                } else {
                    setActive(state.activeIndex <= 0 ? state.items.length - 1 : state.activeIndex - 1);
                }

                return;
            }

            if (event.key === 'Enter' && state.activeIndex >= 0 && state.items[state.activeIndex]) {
                event.preventDefault();
                window.location.href = state.items[state.activeIndex].href;
                return;
            }

            if (event.key === 'Escape') {
                event.preventDefault();
                closePanel();

                if (mobileQuery.matches && body.classList.contains('bf-search-open')) {
                    setMobileSearch(false);
                } else {
                    input.blur();
                }
            }
        });

        clearButton.addEventListener('click', function () {
            input.value = '';
            updateClear();
            input.focus();
            scheduleSearch();
        });

        if (closeButton) {
            closeButton.addEventListener('click', function () {
                if (mobileQuery.matches) {
                    setMobileSearch(false);
                } else {
                    closePanel();
                    input.blur();
                }
            });
        }

        if (mobileSearchToggle) {
            mobileSearchToggle.addEventListener('click', function () {
                setMobileSearch(!body.classList.contains('bf-search-open'));
            });
        }

        search.addEventListener('submit', function (event) {
            if (state.activeIndex >= 0 && state.items[state.activeIndex]) {
                event.preventDefault();
                window.location.href = state.items[state.activeIndex].href;
            }
        });

        document.addEventListener('keydown', function (event) {
            if ((event.ctrlKey || event.metaKey) && String(event.key).toLowerCase() === 'k') {
                event.preventDefault();

                if (mobileQuery.matches) {
                    setMobileSearch(true);
                } else {
                    input.focus();
                    input.select();
                    scheduleSearch();
                }
            }
        });

        document.addEventListener('click', function (event) {
            if (!search.contains(event.target) && !(mobileSearchToggle && mobileSearchToggle.contains(event.target))) {
                closePanel();

                if (mobileQuery.matches && body.classList.contains('bf-search-open')) {
                    setMobileSearch(false);
                }
            }

            if (mobileQuery.matches && body.classList.contains('sidebar-toggled')
                && sidebar && !sidebar.contains(event.target)
                && mobileToggle && !mobileToggle.contains(event.target)) {
                closeMobileSidebar();
            }
        });

        updateClear();
    }
})(window, document);

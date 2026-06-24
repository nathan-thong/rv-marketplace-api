(function(){
  "use strict";

  // Empty string = same-origin. This page is served by the same Rails app
  // it talks to (from public/frontend), so a relative /listings request
  // always hits the right host and port, in dev or production alike.
  // ?api=<absolute-url> in the address bar still overrides it for the rare
  // case of pointing this at a different, deployed instance.
  var DEFAULT_BASE_URL = "";

  // Auth persists in localStorage so a page refresh doesn't log you out.
  // Note: this only works when the page is actually served by the Rails
  // app (public/frontend) and opened in a real browser. It will silently
  // no-op inside a sandboxed preview (e.g. Claude's in-chat artifact view),
  // since browser storage APIs aren't available there — auth still works
  // for the current session, it just won't survive a refresh in that case.
  var AUTH_STORAGE_KEY = 'waypoint_auth_v1';

  var state = {
    baseUrl: DEFAULT_BASE_URL,
    listings: [],
    listingsById: {},
    searchTerm: "",
    sortKey: "newest",
    status: "idle", // idle | loading | success | error
    auth: { token: null, user: null },
    view: "marketplace", // marketplace | bookings
    editingListingId: null,
    bookings: [],
    bookingsStatus: "idle", // idle | loading | success | error
    bookingsError: ""
  };

  var els = {
    navActions: document.getElementById('wp-nav-actions'),
    refreshBtn: document.getElementById('wp-refresh-btn'),
    statusDot: document.getElementById('wp-status-dot'),
    statusText: document.getElementById('wp-status-text'),

    viewMarketplace: document.getElementById('wp-view-marketplace'),
    viewBookings: document.getElementById('wp-view-bookings'),

    grid: document.getElementById('wp-grid'),
    resultCount: document.getElementById('wp-result-count'),
    search: document.getElementById('wp-search-input'),
    sort: document.getElementById('wp-sort-select'),
    statCount: document.getElementById('wp-stat-count'),
    statLocations: document.getElementById('wp-stat-locations'),
    statRange: document.getElementById('wp-stat-range'),

    bookingsRefresh: document.getElementById('wp-bookings-refresh'),
    bookingsCount: document.getElementById('wp-bookings-count'),
    bookingsList: document.getElementById('wp-bookings-list'),

    overlay: document.getElementById('wp-overlay'),
    modal: document.getElementById('wp-modal'),
    modalBody: document.getElementById('wp-modal-body'),
    modalClose: document.getElementById('wp-modal-close'),

    authOverlay: document.getElementById('wp-auth-overlay'),
    authClose: document.getElementById('wp-auth-close'),
    tabLogin: document.getElementById('wp-tab-login'),
    tabRegister: document.getElementById('wp-tab-register'),
    loginForm: document.getElementById('wp-login-form'),
    loginEmail: document.getElementById('wp-login-email'),
    loginPassword: document.getElementById('wp-login-password'),
    loginError: document.getElementById('wp-login-error'),
    loginSubmit: document.getElementById('wp-login-submit'),
    registerForm: document.getElementById('wp-register-form'),
    registerName: document.getElementById('wp-register-name'),
    registerEmail: document.getElementById('wp-register-email'),
    registerPassword: document.getElementById('wp-register-password'),
    registerPasswordConfirm: document.getElementById('wp-register-password-confirmation'),
    registerError: document.getElementById('wp-register-error'),
    registerSubmit: document.getElementById('wp-register-submit'),

    listingOverlay: document.getElementById('wp-listing-overlay'),
    listingClose: document.getElementById('wp-listing-close'),
    listingHeading: document.getElementById('wp-listing-title'),
    listingForm: document.getElementById('wp-listing-form'),
    listingTitleInput: document.getElementById('wp-listing-title-input'),
    listingLocationInput: document.getElementById('wp-listing-location-input'),
    listingPriceInput: document.getElementById('wp-listing-price-input'),
    listingDescriptionInput: document.getElementById('wp-listing-description-input'),
    listingError: document.getElementById('wp-listing-error'),
    listingSubmit: document.getElementById('wp-listing-submit')
  };

  var lastFocusedEl = null;
  var reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ============================== STORAGE ============================== */

  function loadStoredAuth(){
    try {
      var raw = window.localStorage.getItem(AUTH_STORAGE_KEY);
      if (!raw) return null;
      var parsed = JSON.parse(raw);
      if (parsed && parsed.token && parsed.user) return parsed;
    } catch (e) { /* storage unavailable — fall back to in-memory only */ }
    return null;
  }

  function persistAuth(auth){
    try { window.localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(auth)); }
    catch (e) { /* ignore — session still works, just won't survive a refresh */ }
  }

  function clearStoredAuth(){
    try { window.localStorage.removeItem(AUTH_STORAGE_KEY); } catch (e) {}
  }

  function setAuth(auth){
    state.auth = auth;
    persistAuth(auth);
    renderNavActions();
  }

  function clearAuth(){
    state.auth = { token: null, user: null };
    clearStoredAuth();
    if (state.view === 'bookings') switchView('marketplace');
    renderNavActions();
    render();
  }

  /* =============================== API =================================== */

  function apiFetch(path, options){
    options = options || {};
    var headers = { 'Accept': 'application/json' };
    if (options.headers){
      Object.keys(options.headers).forEach(function(k){ headers[k] = options.headers[k]; });
    }
    if (options.body) headers['Content-Type'] = 'application/json';
    if (state.auth.token) headers['Authorization'] = 'Bearer ' + state.auth.token;

    var url = (state.baseUrl || '') + path;

    return fetch(url, {
      method: options.method || 'GET',
      headers: headers,
      body: options.body
    }).then(function(res){
      return res.text().then(function(text){
        var data = null;
        if (text){
          try { data = JSON.parse(text); } catch (e) { data = null; }
        }
        if (res.status === 401 && state.auth.token){
          clearAuth();
        }
        if (!res.ok){
          var err = new Error('Request failed with status ' + res.status);
          err.status = res.status;
          err.data = data;
          throw err;
        }
        return data;
      });
    });
  }

  function describeError(err){
    if (err && err.data){
      if (typeof err.data.error === 'string') return err.data.error;
      if (err.data.errors && typeof err.data.errors === 'object'){
        var parts = [];
        Object.keys(err.data.errors).forEach(function(field){
          var msgs = err.data.errors[field];
          if (Array.isArray(msgs)){
            msgs.forEach(function(m){
              parts.push(field === 'base' ? m : field.replace(/_/g, ' ') + ' ' + m);
            });
          }
        });
        if (parts.length) return parts.join('; ');
      }
    }
    if (err && err.status === 401) return 'Your session has expired. Please log in again.';
    if (err && err.status === 403) return "You're not allowed to do that.";
    if (err && err.status === 404) return 'That record no longer exists.';
    return 'Something went wrong. Please try again.';
  }

  /* ============================ FORMATTERS =============================== */

  function setStatus(state_, text){
    els.statusDot.setAttribute('data-state', state_);
    els.statusText.textContent = text;
  }

  function formatPrice(value){
    var n = Math.round(parseFloat(value));
    if (isNaN(n)) return "$—";
    return "$" + n.toLocaleString('en-US');
  }

  function formatRelative(dateStr){
    var d = new Date(dateStr);
    if (isNaN(d.getTime())) return "unknown date";
    var diffMs = Date.now() - d.getTime();
    var mins = Math.round(diffMs / 60000);
    if (mins < 1) return "just now";
    if (mins < 60) return mins + (mins === 1 ? " minute ago" : " minutes ago");
    var hours = Math.round(mins / 60);
    if (hours < 24) return hours + (hours === 1 ? " hour ago" : " hours ago");
    var days = Math.round(hours / 24);
    if (days < 30) return days + (days === 1 ? " day ago" : " days ago");
    return d.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
  }

  function parseDateOnly(str){
    if (!str) return null;
    var parts = str.split('-');
    if (parts.length !== 3) {
      var fallback = new Date(str);
      return isNaN(fallback.getTime()) ? null : fallback;
    }
    return new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
  }

  function formatDateRange(start, end){
    var s = parseDateOnly(start), e = parseDateOnly(end);
    if (!s || !e) return 'Dates unavailable';
    var startStr = s.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    var endStr = e.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    return startStr + ' – ' + endStr;
  }

  function isoDate(d){
    var y = d.getFullYear();
    var m = String(d.getMonth() + 1).padStart(2, '0');
    var day = String(d.getDate()).padStart(2, '0');
    return y + '-' + m + '-' + day;
  }

  function addYears(d, n){
    var copy = new Date(d.getTime());
    copy.setFullYear(copy.getFullYear() + n);
    return copy;
  }

  function pinIcon(){
    var span = document.createElement('span');
    span.innerHTML = '<svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
      '<path d="M8 1.5C5.5 1.5 3.5 3.5 3.5 6c0 3.5 4.5 8 4.5 8s4.5-4.5 4.5-8c0-2.5-2-4.5-4.5-4.5Z" stroke="currentColor" stroke-width="1.3"/>' +
      '<circle cx="8" cy="6" r="1.6" stroke="currentColor" stroke-width="1.2"/></svg>';
    return span.firstChild;
  }

  function escapeForCode(str){
    var d = document.createElement('div');
    d.textContent = str;
    return d.innerHTML;
  }

  function countUp(el, target){
    var display = function(v){ el.textContent = String(v).padStart(3, '0'); };
    if (reducedMotion || target === 0){ display(target); return; }
    var start = 0;
    var duration = 500;
    var startTime = null;
    function step(ts){
      if (startTime === null) startTime = ts;
      var progress = Math.min((ts - startTime) / duration, 1);
      var value = Math.round(start + (target - start) * progress);
      display(value);
      if (progress < 1) requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
  }

  /* ============================ NAV / AUTH UI ============================ */

  function renderNavActions(){
    els.navActions.innerHTML = '';

    if (!state.auth.token){
      var loginBtn = document.createElement('button');
      loginBtn.type = 'button';
      loginBtn.className = 'wp-btn wp-btn--ghost wp-btn--sm';
      loginBtn.textContent = 'Log in';
      loginBtn.addEventListener('click', function(){ openAuthModal('login'); });

      var signupBtn = document.createElement('button');
      signupBtn.type = 'button';
      signupBtn.className = 'wp-btn wp-btn--rust wp-btn--sm';
      signupBtn.textContent = 'Sign up';
      signupBtn.addEventListener('click', function(){ openAuthModal('register'); });

      els.navActions.appendChild(loginBtn);
      els.navActions.appendChild(signupBtn);
      return;
    }

    var toggle = document.createElement('div');
    toggle.className = 'wp-view-toggle';
    [['marketplace', 'Marketplace'], ['bookings', 'My bookings']].forEach(function(pair){
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'wp-view-toggle__btn' + (state.view === pair[0] ? ' is-active' : '');
      btn.textContent = pair[1];
      btn.addEventListener('click', function(){ switchView(pair[0]); });
      toggle.appendChild(btn);
    });
    els.navActions.appendChild(toggle);

    var newListingBtn = document.createElement('button');
    newListingBtn.type = 'button';
    newListingBtn.className = 'wp-btn wp-btn--ghost wp-btn--sm';
    newListingBtn.textContent = 'List your RV';
    newListingBtn.addEventListener('click', function(){ openListingModal(null); });
    els.navActions.appendChild(newListingBtn);

    var divider = document.createElement('span');
    divider.className = 'wp-nav__divider';
    els.navActions.appendChild(divider);

    var user = document.createElement('span');
    user.className = 'wp-nav__user wp-mono';
    user.textContent = state.auth.user.name;
    els.navActions.appendChild(user);

    var logoutBtn = document.createElement('button');
    logoutBtn.type = 'button';
    logoutBtn.className = 'wp-btn wp-btn--ghost wp-btn--sm';
    logoutBtn.textContent = 'Log out';
    logoutBtn.addEventListener('click', clearAuth);
    els.navActions.appendChild(logoutBtn);
  }

  function switchView(view){
    state.view = view;
    els.viewMarketplace.hidden = view !== 'marketplace';
    els.viewBookings.hidden = view !== 'bookings';
    renderNavActions();
    if (view === 'bookings') fetchBookings();
  }

  /* ============================== STATS / GRID ============================ */

  function updateStats(list){
    countUp(els.statCount, list.length);
    var uniqueLocations = new Set(list.map(function(l){ return (l.location || '').trim().toLowerCase(); }).filter(Boolean));
    els.statLocations.textContent = String(uniqueLocations.size).padStart(2, '0');
    if (list.length === 0){
      els.statRange.textContent = "$0–0";
    } else {
      var prices = list.map(function(l){ return parseFloat(l.price_per_day); }).filter(function(n){ return !isNaN(n); });
      var min = Math.round(Math.min.apply(null, prices));
      var max = Math.round(Math.max.apply(null, prices));
      els.statRange.textContent = "$" + min + "–" + max;
    }
  }

  function getFilteredSorted(){
    var term = state.searchTerm.trim().toLowerCase();
    var list = state.listings.filter(function(l){
      if (!term) return true;
      var title = (l.title || '').toLowerCase();
      var loc = (l.location || '').toLowerCase();
      return title.indexOf(term) !== -1 || loc.indexOf(term) !== -1;
    });
    list = list.slice();
    switch (state.sortKey){
      case 'price-asc':
        list.sort(function(a, b){ return parseFloat(a.price_per_day) - parseFloat(b.price_per_day); });
        break;
      case 'price-desc':
        list.sort(function(a, b){ return parseFloat(b.price_per_day) - parseFloat(a.price_per_day); });
        break;
      case 'title':
        list.sort(function(a, b){ return (a.title || '').localeCompare(b.title || ''); });
        break;
      default: // newest
        list.sort(function(a, b){ return new Date(b.created_at) - new Date(a.created_at); });
    }
    return list;
  }

  function rebuildListingsIndex(){
    state.listingsById = {};
    state.listings.forEach(function(l){ state.listingsById[l.id] = l; });
  }

  function buildCard(listing, index){
    var card = document.createElement('article');
    card.className = 'wp-card';

    var no = document.createElement('span');
    no.className = 'wp-card__no wp-mono';
    no.textContent = 'No. ' + String(index + 1).padStart(2, '0');
    card.appendChild(no);

    if (state.auth.user && listing.user_id === state.auth.user.id){
      var mine = document.createElement('span');
      mine.className = 'wp-card__mine wp-mono';
      mine.textContent = 'Hosted by you';
      card.appendChild(mine);
    }

    var title = document.createElement('h3');
    title.className = 'wp-card__title';
    title.textContent = listing.title || 'Untitled listing';
    card.appendChild(title);

    var loc = document.createElement('div');
    loc.className = 'wp-card__loc';
    loc.appendChild(pinIcon());
    var locText = document.createElement('span');
    locText.textContent = listing.location || 'Location not set';
    loc.appendChild(locText);
    card.appendChild(loc);

    var desc = document.createElement('p');
    desc.className = 'wp-card__desc';
    var rawDesc = listing.description || '';
    desc.textContent = rawDesc.length > 120 ? rawDesc.slice(0, 117).trim() + '…' : rawDesc;
    card.appendChild(desc);

    var rule = document.createElement('hr');
    rule.className = 'wp-card__rule';
    card.appendChild(rule);

    var foot = document.createElement('div');
    foot.className = 'wp-card__foot';

    var price = document.createElement('span');
    price.className = 'wp-card__price wp-mono';
    price.textContent = formatPrice(listing.price_per_day);
    var small = document.createElement('small');
    small.textContent = '/day';
    price.appendChild(small);
    foot.appendChild(price);

    var link = document.createElement('button');
    link.type = 'button';
    link.className = 'wp-card__link';
    link.textContent = 'Details →';
    link.addEventListener('click', function(){ openModal(listing); });
    foot.appendChild(link);

    card.appendChild(foot);

    card.addEventListener('click', function(e){
      if (e.target === link) return;
      openModal(listing);
    });

    return card;
  }

  function renderPanel(kind, title, bodyEl){
    els.grid.innerHTML = '';
    var panel = document.createElement('div');
    panel.className = 'wp-panel' + (kind === 'error' ? ' wp-panel--error' : '');
    var h = document.createElement('h3');
    h.textContent = title;
    panel.appendChild(h);
    panel.appendChild(bodyEl);
    els.grid.appendChild(panel);
  }

  function renderSkeleton(){
    els.grid.innerHTML = '';
    els.resultCount.textContent = '';
    for (var i = 0; i < 6; i++){
      var skel = document.createElement('div');
      skel.className = 'wp-skel';
      skel.setAttribute('aria-hidden', 'true');
      skel.innerHTML =
        '<div class="wp-skel__bar" style="width:60px;height:20px;margin-bottom:14px;"></div>' +
        '<div class="wp-skel__bar" style="width:70%;height:16px;margin-bottom:10px;"></div>' +
        '<div class="wp-skel__bar" style="width:45%;height:12px;margin-bottom:18px;"></div>' +
        '<div class="wp-skel__bar" style="width:90%;height:12px;margin-bottom:8px;"></div>' +
        '<div class="wp-skel__bar" style="width:80%;height:12px;"></div>';
      els.grid.appendChild(skel);
    }
  }

  function wrapWithButton(textEl, buttonEl){
    var wrap = document.createElement('div');
    wrap.appendChild(textEl);
    wrap.appendChild(buttonEl);
    return wrap;
  }

  function render(){
    if (state.status === 'loading'){
      renderSkeleton();
      return;
    }

    if (state.status === 'error'){
      var p = document.createElement('p');
      var attempted = (state.baseUrl || '') + '/listings';
      p.innerHTML = 'Could not load <code>' + escapeForCode(attempted) + '</code>. ' +
        'Check that <code>rails s</code> is still running and the database is migrated ' +
        '(<code>bin/rails db:create db:migrate</code>). If you just started the server, give it a moment and retry.';
      var retry = document.createElement('button');
      retry.type = 'button';
      retry.className = 'wp-btn wp-btn--ghost';
      retry.style.border = '1px solid var(--hairline)';
      retry.textContent = 'Retry';
      retry.addEventListener('click', fetchListings);
      renderPanel('error', 'Couldn\u2019t load listings', wrapWithButton(p, retry));
      els.resultCount.textContent = '';
      updateStats([]);
      return;
    }

    var list = getFilteredSorted();
    updateStats(state.listings);

    if (state.listings.length === 0 && state.status === 'success'){
      var p2 = document.createElement('p');
      p2.textContent = 'There are no listings yet. Log in and list an RV to get started.';
      renderPanel('empty', 'No listings yet', p2);
      els.resultCount.textContent = '';
      return;
    }

    if (list.length === 0){
      var p3 = document.createElement('p');
      p3.textContent = 'No listings match "' + state.searchTerm + '". Try a different location or title.';
      var clear = document.createElement('button');
      clear.type = 'button';
      clear.className = 'wp-btn wp-btn--ghost';
      clear.style.border = '1px solid var(--hairline)';
      clear.textContent = 'Clear search';
      clear.addEventListener('click', function(){
        els.search.value = '';
        state.searchTerm = '';
        render();
      });
      renderPanel('empty', 'No matching listings', wrapWithButton(p3, clear));
      els.resultCount.textContent = '';
      return;
    }

    els.grid.innerHTML = '';
    list.forEach(function(listing, idx){
      els.grid.appendChild(buildCard(listing, idx));
    });
    els.resultCount.textContent = list.length + (list.length === 1 ? ' listing' : ' listings') +
      (state.searchTerm ? ' matching "' + state.searchTerm + '"' : '');
  }

  function fetchListings(){
    state.status = 'loading';
    setStatus('busy', 'Connecting…');
    els.refreshBtn.disabled = true;
    render();

    apiFetch('/listings')
      .then(function(data){
        state.listings = Array.isArray(data) ? data : [];
        rebuildListingsIndex();
        state.status = 'success';
        setStatus('ok', 'Connected · ' + state.listings.length + ' listing' + (state.listings.length === 1 ? '' : 's'));
        render();
      })
      .catch(function(){
        state.status = 'error';
        setStatus('bad', 'Connection failed');
        render();
      })
      .finally(function(){
        els.refreshBtn.disabled = false;
      });
  }

  /* ========================= LISTING DETAIL MODAL ========================= */

  function buildModalActions(listing){
    var wrap = document.createElement('div');
    wrap.className = 'wp-modal__actions';

    if (!state.auth.token){
      var p = document.createElement('p');
      p.textContent = 'Log in to request a booking or manage your own listings.';
      var loginBtn = document.createElement('button');
      loginBtn.type = 'button';
      loginBtn.className = 'wp-btn wp-btn--rust';
      loginBtn.textContent = 'Log in';
      loginBtn.addEventListener('click', function(){
        closeModal();
        openAuthModal('login');
      });
      wrap.appendChild(p);
      wrap.appendChild(loginBtn);
      return wrap;
    }

    var isOwner = listing.user_id === state.auth.user.id;

    if (isOwner){
      var row = document.createElement('div');
      row.className = 'wp-modal__actions-row';

      var editBtn = document.createElement('button');
      editBtn.type = 'button';
      editBtn.className = 'wp-btn wp-btn--ghost';
      editBtn.style.border = '1px solid var(--hairline)';
      editBtn.textContent = 'Edit listing';
      editBtn.addEventListener('click', function(){
        closeModal();
        openListingModal(listing);
      });

      var deleteBtn = document.createElement('button');
      deleteBtn.type = 'button';
      deleteBtn.className = 'wp-btn wp-btn--danger';
      deleteBtn.textContent = 'Delete listing';

      row.appendChild(editBtn);
      row.appendChild(deleteBtn);
      wrap.appendChild(row);

      var confirmRow = document.createElement('div');
      confirmRow.hidden = true;
      confirmRow.className = 'wp-inline-confirm';
      confirmRow.style.marginTop = '12px';

      var confirmLabel = document.createElement('span');
      confirmLabel.className = 'wp-inline-confirm__label';
      confirmLabel.textContent = 'Delete this listing permanently?';

      var yesBtn = document.createElement('button');
      yesBtn.type = 'button';
      yesBtn.className = 'wp-btn wp-btn--danger';
      yesBtn.textContent = 'Yes, delete';

      var cancelBtn = document.createElement('button');
      cancelBtn.type = 'button';
      cancelBtn.className = 'wp-btn wp-btn--ghost';
      cancelBtn.style.border = '1px solid var(--hairline)';
      cancelBtn.textContent = 'Cancel';

      confirmRow.appendChild(confirmLabel);
      confirmRow.appendChild(yesBtn);
      confirmRow.appendChild(cancelBtn);
      wrap.appendChild(confirmRow);

      deleteBtn.addEventListener('click', function(){
        row.hidden = true;
        confirmRow.hidden = false;
      });
      cancelBtn.addEventListener('click', function(){
        confirmRow.hidden = true;
        row.hidden = false;
      });
      yesBtn.addEventListener('click', function(){
        yesBtn.disabled = true;
        cancelBtn.disabled = true;
        yesBtn.textContent = 'Deleting…';
        apiFetch('/listings/' + listing.id, { method: 'DELETE' })
          .then(function(){
            state.listings = state.listings.filter(function(l){ return l.id !== listing.id; });
            rebuildListingsIndex();
            closeModal();
            render();
          })
          .catch(function(err){
            confirmLabel.textContent = describeError(err);
            yesBtn.disabled = false;
            cancelBtn.disabled = false;
            yesBtn.textContent = 'Yes, delete';
          });
      });

      return wrap;
    }

    // logged in, not the owner: booking request mini-form
    var note = document.createElement('p');
    note.textContent = 'Pick your dates and send a request to the owner.';
    wrap.appendChild(note);

    var form = document.createElement('form');
    form.className = 'wp-form wp-booking-form';

    var dateRow = document.createElement('div');
    dateRow.className = 'wp-field-row';

    function dateField(labelText, idSuffix){
      var field = document.createElement('div');
      field.className = 'wp-field';
      var inputId = 'wp-booking-' + idSuffix + '-' + listing.id;
      var label = document.createElement('label');
      label.textContent = labelText;
      label.setAttribute('for', inputId);
      var input = document.createElement('input');
      input.type = 'date';
      input.id = inputId;
      input.required = true;
      input.min = isoDate(new Date());
      input.max = isoDate(addYears(new Date(), 2));
      field.appendChild(label);
      field.appendChild(input);
      return { field: field, input: input };
    }

    var startField = dateField('Start date', 'start');
    var endField = dateField('End date', 'end');
    startField.input.addEventListener('change', function(){
      if (startField.input.value) endField.input.min = startField.input.value;
    });
    dateRow.appendChild(startField.field);
    dateRow.appendChild(endField.field);
    form.appendChild(dateRow);

    var bookingError = document.createElement('p');
    bookingError.className = 'wp-form__error';
    form.appendChild(bookingError);

    var bookingSuccess = document.createElement('p');
    bookingSuccess.className = 'wp-form__success';
    form.appendChild(bookingSuccess);

    var submitBtn = document.createElement('button');
    submitBtn.type = 'submit';
    submitBtn.className = 'wp-btn wp-btn--rust';
    submitBtn.textContent = 'Request booking';
    form.appendChild(submitBtn);

    form.addEventListener('submit', function(e){
      e.preventDefault();
      bookingError.textContent = '';
      bookingSuccess.textContent = '';
      submitBtn.disabled = true;
      submitBtn.textContent = 'Sending…';
      apiFetch('/listings/' + listing.id + '/bookings', {
        method: 'POST',
        body: JSON.stringify({ booking: { start_date: startField.input.value, end_date: endField.input.value } })
      }).then(function(data){
        state.bookings.unshift(data);
        bookingSuccess.textContent = 'Requested — find it under My bookings.';
        form.reset();
        submitBtn.disabled = false;
        submitBtn.textContent = 'Request booking';
      }).catch(function(err){
        bookingError.textContent = describeError(err);
        submitBtn.disabled = false;
        submitBtn.textContent = 'Request booking';
      });
    });

    wrap.appendChild(form);
    return wrap;
  }

  function openModal(listing){
    lastFocusedEl = document.activeElement;
    els.modalBody.innerHTML = '';

    var no = document.createElement('div');
    no.className = 'wp-card__no wp-mono wp-modal__no';
    no.textContent = 'Listing #' + listing.id;
    els.modalBody.appendChild(no);

    var h2 = document.createElement('h2');
    h2.id = 'wp-modal-title';
    h2.textContent = listing.title || 'Untitled listing';
    els.modalBody.appendChild(h2);

    var loc = document.createElement('div');
    loc.className = 'wp-modal__loc';
    loc.appendChild(pinIcon());
    var locText = document.createElement('span');
    locText.textContent = listing.location || 'Location not set';
    loc.appendChild(locText);
    els.modalBody.appendChild(loc);

    var desc = document.createElement('p');
    desc.className = 'wp-modal__desc';
    desc.textContent = listing.description || 'No description provided.';
    els.modalBody.appendChild(desc);

    var meta = document.createElement('div');
    meta.className = 'wp-modal__meta';

    function metaItem(label, value, isPrice){
      var item = document.createElement('div');
      var l = document.createElement('div');
      l.className = 'wp-modal__meta-label';
      l.textContent = label;
      var v = document.createElement('div');
      v.className = 'wp-modal__meta-val wp-mono' + (isPrice ? ' wp-modal__meta-val--price' : '');
      v.textContent = value;
      item.appendChild(l);
      item.appendChild(v);
      meta.appendChild(item);
    }

    metaItem('Price', formatPrice(listing.price_per_day) + ' / day', true);
    metaItem('Listed', formatRelative(listing.created_at));
    metaItem('Last updated', formatRelative(listing.updated_at));
    metaItem('Owner ref', '#' + listing.user_id);

    els.modalBody.appendChild(meta);
    els.modalBody.appendChild(buildModalActions(listing));

    els.overlay.hidden = false;
    els.modalClose.focus();
    document.addEventListener('keydown', onModalKeydown);
  }

  function closeModal(){
    els.overlay.hidden = true;
    document.removeEventListener('keydown', onModalKeydown);
    if (lastFocusedEl && typeof lastFocusedEl.focus === 'function') lastFocusedEl.focus();
  }

  function onModalKeydown(e){
    if (e.key === 'Escape') closeModal();
  }

  /* ============================== AUTH MODAL =============================== */

  function setAuthTab(tab){
    var isLogin = tab === 'login';
    els.tabLogin.classList.toggle('is-active', isLogin);
    els.tabLogin.setAttribute('aria-selected', String(isLogin));
    els.tabRegister.classList.toggle('is-active', !isLogin);
    els.tabRegister.setAttribute('aria-selected', String(!isLogin));
    els.loginForm.hidden = !isLogin;
    els.registerForm.hidden = isLogin;
  }

  function openAuthModal(tab){
    lastFocusedEl = document.activeElement;
    setAuthTab(tab || 'login');
    els.loginError.textContent = '';
    els.registerError.textContent = '';
    els.authOverlay.hidden = false;
    document.addEventListener('keydown', onAuthModalKeydown);
    (tab === 'register' ? els.registerName : els.loginEmail).focus();
  }

  function closeAuthModal(){
    els.authOverlay.hidden = true;
    document.removeEventListener('keydown', onAuthModalKeydown);
    if (lastFocusedEl && typeof lastFocusedEl.focus === 'function') lastFocusedEl.focus();
  }

  function onAuthModalKeydown(e){
    if (e.key === 'Escape') closeAuthModal();
  }

  /* ============================ LISTING FORM MODAL ========================= */

  function openListingModal(listing){
    lastFocusedEl = document.activeElement;
    state.editingListingId = listing ? listing.id : null;
    els.listingHeading.textContent = listing ? 'Edit listing' : 'List your RV';
    els.listingSubmit.textContent = listing ? 'Save changes' : 'Publish listing';
    els.listingTitleInput.value = listing ? listing.title : '';
    els.listingLocationInput.value = listing ? listing.location : '';
    els.listingPriceInput.value = listing ? Math.round(parseFloat(listing.price_per_day)) : '';
    els.listingDescriptionInput.value = listing ? listing.description : '';
    els.listingError.textContent = '';
    els.listingOverlay.hidden = false;
    document.addEventListener('keydown', onListingModalKeydown);
    els.listingTitleInput.focus();
  }

  function closeListingModal(){
    els.listingOverlay.hidden = true;
    document.removeEventListener('keydown', onListingModalKeydown);
    if (lastFocusedEl && typeof lastFocusedEl.focus === 'function') lastFocusedEl.focus();
  }

  function onListingModalKeydown(e){
    if (e.key === 'Escape') closeListingModal();
  }

  /* =============================== BOOKINGS =============================== */

  function fetchBookings(){
    state.bookingsStatus = 'loading';
    renderBookingsView();
    apiFetch('/bookings')
      .then(function(data){
        state.bookings = Array.isArray(data) ? data : [];
        state.bookingsStatus = 'success';
        renderBookingsView();
      })
      .catch(function(err){
        state.bookingsStatus = 'error';
        state.bookingsError = describeError(err);
        renderBookingsView();
      });
  }

  function buildBookingRow(booking){
    var listing = state.listingsById[booking.rv_listing_id];
    var isOwner = !!(listing && state.auth.user && listing.user_id === state.auth.user.id);

    var row = document.createElement('div');
    row.className = 'wp-booking-row';

    var left = document.createElement('div');

    var title = document.createElement('p');
    title.className = 'wp-booking-row__title';
    title.textContent = listing ? listing.title : ('Listing #' + booking.rv_listing_id);
    left.appendChild(title);

    if (listing){
      var meta = document.createElement('p');
      meta.className = 'wp-booking-row__meta';
      meta.textContent = listing.location;
      left.appendChild(meta);
    }

    var dates = document.createElement('p');
    dates.className = 'wp-booking-row__dates';
    dates.textContent = formatDateRange(booking.start_date, booking.end_date);
    left.appendChild(dates);

    row.appendChild(left);

    var right = document.createElement('div');
    right.className = 'wp-booking-row__right';

    var role = document.createElement('span');
    role.className = 'wp-booking-row__role';
    role.textContent = isOwner ? "You're hosting" : 'You requested this';
    right.appendChild(role);

    var pill = document.createElement('span');
    pill.className = 'wp-pill wp-pill--' + booking.status;
    pill.textContent = booking.status;
    right.appendChild(pill);

    if (isOwner && booking.status === 'pending'){
      var actions = document.createElement('div');
      actions.className = 'wp-booking-row__actions';

      var confirmBtn = document.createElement('button');
      confirmBtn.type = 'button';
      confirmBtn.className = 'wp-btn wp-btn--ok wp-btn--sm';
      confirmBtn.textContent = 'Confirm';

      var rejectBtn = document.createElement('button');
      rejectBtn.type = 'button';
      rejectBtn.className = 'wp-btn wp-btn--danger wp-btn--sm';
      rejectBtn.textContent = 'Reject';

      var rowError = document.createElement('p');
      rowError.className = 'wp-form__error';
      rowError.style.width = '100%';

      function actOn(action, btn, restoreLabel){
        confirmBtn.disabled = true;
        rejectBtn.disabled = true;
        btn.textContent = action === 'confirm' ? 'Confirming…' : 'Rejecting…';
        rowError.textContent = '';
        apiFetch('/bookings/' + booking.id + '/' + action, { method: 'PATCH' })
          .then(function(data){
            var idx = state.bookings.findIndex(function(b){ return b.id === booking.id; });
            if (idx !== -1) state.bookings[idx] = data;
            renderBookingsView();
          })
          .catch(function(err){
            confirmBtn.disabled = false;
            rejectBtn.disabled = false;
            btn.textContent = restoreLabel;
            rowError.textContent = describeError(err);
          });
      }

      confirmBtn.addEventListener('click', function(){ actOn('confirm', confirmBtn, 'Confirm'); });
      rejectBtn.addEventListener('click', function(){ actOn('reject', rejectBtn, 'Reject'); });

      actions.appendChild(confirmBtn);
      actions.appendChild(rejectBtn);
      right.appendChild(actions);
      right.appendChild(rowError);
    }

    row.appendChild(right);
    return row;
  }

  function renderBookingsView(){
    els.bookingsList.innerHTML = '';
    els.bookingsCount.textContent = '';

    if (state.bookingsStatus === 'loading'){
      for (var i = 0; i < 3; i++){
        var skel = document.createElement('div');
        skel.className = 'wp-skel';
        skel.style.height = '92px';
        skel.setAttribute('aria-hidden', 'true');
        skel.innerHTML = '<div class="wp-skel__bar" style="width:55%;height:16px;margin-bottom:10px;"></div>' +
          '<div class="wp-skel__bar" style="width:35%;height:12px;"></div>';
        els.bookingsList.appendChild(skel);
      }
      return;
    }

    if (state.bookingsStatus === 'error'){
      var panel = document.createElement('div');
      panel.className = 'wp-panel wp-panel--error';
      var h3 = document.createElement('h3');
      h3.textContent = 'Couldn\u2019t load your bookings';
      var p = document.createElement('p');
      p.textContent = state.bookingsError || 'Something went wrong.';
      var retry = document.createElement('button');
      retry.type = 'button';
      retry.className = 'wp-btn wp-btn--ghost';
      retry.style.border = '1px solid var(--hairline)';
      retry.textContent = 'Retry';
      retry.addEventListener('click', fetchBookings);
      panel.appendChild(h3);
      panel.appendChild(p);
      panel.appendChild(retry);
      els.bookingsList.appendChild(panel);
      return;
    }

    if (state.bookings.length === 0){
      var panel2 = document.createElement('div');
      panel2.className = 'wp-panel';
      var h3b = document.createElement('h3');
      h3b.textContent = 'No bookings yet';
      var p2 = document.createElement('p');
      p2.textContent = 'Requests you send, and requests sent to you as an owner, will show up here.';
      panel2.appendChild(h3b);
      panel2.appendChild(p2);
      els.bookingsList.appendChild(panel2);
      return;
    }

    var sorted = state.bookings.slice().sort(function(a, b){ return new Date(b.created_at) - new Date(a.created_at); });
    els.bookingsCount.textContent = sorted.length + (sorted.length === 1 ? ' booking' : ' bookings');
    sorted.forEach(function(booking){
      els.bookingsList.appendChild(buildBookingRow(booking));
    });
  }

  /* =============================== WIRING ================================= */

  els.modalClose.addEventListener('click', closeModal);

  els.authClose.addEventListener('click', closeAuthModal);
  els.tabLogin.addEventListener('click', function(){ setAuthTab('login'); els.loginEmail.focus(); });
  els.tabRegister.addEventListener('click', function(){ setAuthTab('register'); els.registerName.focus(); });

  els.loginForm.addEventListener('submit', function(e){
    e.preventDefault();
    els.loginError.textContent = '';
    els.loginSubmit.disabled = true;
    els.loginSubmit.textContent = 'Logging in…';
    apiFetch('/login', {
      method: 'POST',
      body: JSON.stringify({ user: { email: els.loginEmail.value.trim(), password: els.loginPassword.value } })
    }).then(function(data){
      setAuth({ token: data.token, user: data.user });
      closeAuthModal();
      els.loginForm.reset();
      render();
    }).catch(function(err){
      els.loginError.textContent = describeError(err);
    }).finally(function(){
      els.loginSubmit.disabled = false;
      els.loginSubmit.textContent = 'Log in';
    });
  });

  els.registerForm.addEventListener('submit', function(e){
    e.preventDefault();
    els.registerError.textContent = '';
    if (els.registerPassword.value !== els.registerPasswordConfirm.value){
      els.registerError.textContent = 'Passwords don\u2019t match.';
      return;
    }
    els.registerSubmit.disabled = true;
    els.registerSubmit.textContent = 'Creating account…';
    apiFetch('/register', {
      method: 'POST',
      body: JSON.stringify({ user: {
        name: els.registerName.value.trim(),
        email: els.registerEmail.value.trim(),
        password: els.registerPassword.value,
        password_confirmation: els.registerPasswordConfirm.value
      } })
    }).then(function(data){
      setAuth({ token: data.token, user: data.user });
      closeAuthModal();
      els.registerForm.reset();
      render();
    }).catch(function(err){
      els.registerError.textContent = describeError(err);
    }).finally(function(){
      els.registerSubmit.disabled = false;
      els.registerSubmit.textContent = 'Create account';
    });
  });

  els.listingClose.addEventListener('click', closeListingModal);

  els.listingForm.addEventListener('submit', function(e){
    e.preventDefault();
    els.listingError.textContent = '';
    var editingId = state.editingListingId;
    var isEdit = !!editingId;
    var payload = { rv_listing: {
      title: els.listingTitleInput.value.trim(),
      location: els.listingLocationInput.value.trim(),
      price_per_day: els.listingPriceInput.value,
      description: els.listingDescriptionInput.value.trim()
    } };

    els.listingSubmit.disabled = true;
    els.listingSubmit.textContent = isEdit ? 'Saving…' : 'Publishing…';

    apiFetch(isEdit ? ('/listings/' + editingId) : '/listings', {
      method: isEdit ? 'PATCH' : 'POST',
      body: JSON.stringify(payload)
    }).then(function(data){
      if (isEdit){
        var idx = state.listings.findIndex(function(l){ return l.id === editingId; });
        if (idx !== -1) state.listings[idx] = data;
      } else {
        state.listings.unshift(data);
      }
      rebuildListingsIndex();
      closeListingModal();
      render();
    }).catch(function(err){
      els.listingError.textContent = describeError(err);
    }).finally(function(){
      els.listingSubmit.disabled = false;
      els.listingSubmit.textContent = isEdit ? 'Save changes' : 'Publish listing';
    });
  });

  els.refreshBtn.addEventListener('click', fetchListings);
  els.bookingsRefresh.addEventListener('click', fetchBookings);

  var searchDebounce = null;
  els.search.addEventListener('input', function(){
    clearTimeout(searchDebounce);
    searchDebounce = setTimeout(function(){
      state.searchTerm = els.search.value;
      render();
    }, 120);
  });

  els.sort.addEventListener('change', function(){
    state.sortKey = els.sort.value;
    render();
  });

  /* ================================ INIT =================================== */

  // quiet escape hatch: ?api=<url> in the address bar overrides the fixed
  // local endpoint, e.g. for a one-off check against a deployed instance
  (function applyApiParamFromUrl(){
    var params = new URLSearchParams(window.location.search);
    var fromUrl = params.get('api');
    if (fromUrl) state.baseUrl = fromUrl.trim();
  })();

  state.auth = loadStoredAuth() || { token: null, user: null };
  renderNavActions();
  fetchListings();
})();

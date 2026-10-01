/* DearDiary dashboard behaviour.
   Inlined at the end of every page by src/ui/app.jl. No dependencies.
   Responsibilities: theme toggle, sortable/filterable tables, copy buttons,
   metric charts drawn from data-chart JSON payloads, and the live-refresh pill. */
(function () {
  "use strict";

  var doc = document;
  var root = doc.documentElement;

  /* ---------- theme ---------- */

  function prefersDark() {
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
  }
  function effectiveTheme() {
    var t = root.getAttribute("data-theme");
    if (t === "dark" || t === "light") return t;
    return prefersDark() ? "dark" : "light";
  }
  function setTheme(theme) {
    root.setAttribute("data-theme", theme);
    try { localStorage.setItem("dd-theme", theme); } catch (e) { /* storage unavailable */ }
  }
  var toggle = doc.querySelector("[data-theme-toggle]");
  if (toggle) {
    toggle.addEventListener("click", function () {
      setTheme(effectiveTheme() === "dark" ? "light" : "dark");
      doc.querySelectorAll("[data-chart]").forEach(function (el) {
        if (el.__redraw) el.__redraw();
      });
    });
  }

  /* ---------- helpers ---------- */

  function fmtNumber(v) {
    if (v === null || v === undefined || !isFinite(v)) return "–";
    var a = Math.abs(v);
    if (a !== 0 && (a >= 1e6 || a < 1e-4)) return v.toExponential(2);
    return String(Number(v.toPrecision(4)));
  }
  function fmtTick(v) {
    var a = Math.abs(v);
    if (a !== 0 && (a >= 1e6 || a < 1e-3)) return v.toExponential(1);
    return String(Number(v.toPrecision(3)));
  }
  function el(tag, attrs, children) {
    var node = doc.createElement(tag);
    if (attrs) Object.keys(attrs).forEach(function (k) { node.setAttribute(k, attrs[k]); });
    (children || []).forEach(function (c) {
      node.appendChild(typeof c === "string" ? doc.createTextNode(c) : c);
    });
    return node;
  }
  var SVG_NS = "http://www.w3.org/2000/svg";
  function svgEl(tag, attrs) {
    var node = doc.createElementNS(SVG_NS, tag);
    if (attrs) Object.keys(attrs).forEach(function (k) { node.setAttribute(k, attrs[k]); });
    return node;
  }
  function niceStep(range, count) {
    var rough = range / Math.max(1, count - 1);
    var mag = Math.pow(10, Math.floor(Math.log10(rough)));
    var r = rough / mag;
    var nice = r >= 7.5 ? 10 : r >= 3.5 ? 5 : r >= 1.5 ? 2 : 1;
    return nice * mag;
  }
  function ticksBetween(min, max, count, integer) {
    if (max <= min) return [min];
    var step = niceStep(max - min, count);
    if (integer) step = Math.max(1, Math.round(step));
    var start = Math.ceil(min / step) * step;
    var out = [];
    for (var v = start; v <= max + step * 1e-9; v += step) out.push(Number(v.toFixed(10)));
    return out.length ? out : [min, max];
  }
  function niceDomain(min, max, count) {
    if (max === min) {
      var pad = Math.abs(min) * 0.05 || 0.5;
      return [min - pad, max + pad];
    }
    var step = niceStep(max - min, count);
    return [Math.floor(min / step) * step, Math.ceil(max / step) * step];
  }

  /* ---------- sortable tables ---------- */

  function cellValue(td) {
    if (!td) return "";
    var v = td.getAttribute("data-value");
    return v !== null ? v : td.textContent.trim();
  }
  function sortTable(table, th) {
    var idx = th.hasAttribute("data-col")
      ? parseInt(th.getAttribute("data-col"), 10)
      : Array.prototype.indexOf.call(th.parentNode.children, th);
    var dir = th.getAttribute("aria-sort") === "ascending" ? "descending" : "ascending";
    table.querySelectorAll("th[aria-sort]").forEach(function (h) { h.setAttribute("aria-sort", "none"); });
    th.setAttribute("aria-sort", dir);
    var sign = dir === "ascending" ? 1 : -1;
    var tbody = table.tBodies[0];
    if (!tbody) return;
    var rows = Array.prototype.slice.call(tbody.rows);
    rows.sort(function (a, b) {
      var va = cellValue(a.cells[idx]), vb = cellValue(b.cells[idx]);
      var ea = va === "", eb = vb === "";
      if (ea && eb) return 0;
      if (ea) return 1;
      if (eb) return -1;
      var na = Number(va), nb = Number(vb);
      if (isFinite(na) && isFinite(nb)) return (na - nb) * sign;
      return va.localeCompare(vb, undefined, { numeric: true, sensitivity: "base" }) * sign;
    });
    rows.forEach(function (r) { tbody.appendChild(r); });
  }
  doc.querySelectorAll("table[data-sortable]").forEach(function (table) {
    table.querySelectorAll("th[data-sort]").forEach(function (th) {
      th.setAttribute("tabindex", "0");
      if (!th.hasAttribute("aria-sort")) th.setAttribute("aria-sort", "none");
      th.addEventListener("click", function () { sortTable(table, th); });
      th.addEventListener("keydown", function (ev) {
        if (ev.key === "Enter" || ev.key === " ") { ev.preventDefault(); sortTable(table, th); }
      });
    });
  });

  /* ---------- row filters ---------- */

  doc.querySelectorAll("input[data-filter]").forEach(function (input) {
    var table = doc.querySelector(input.getAttribute("data-filter"));
    if (!table || !table.tBodies[0]) return;
    var counter = doc.querySelector("[data-filter-count='" + input.getAttribute("data-filter") + "']");
    var rows = Array.prototype.slice.call(table.tBodies[0].rows);
    function apply() {
      var q = input.value.trim().toLowerCase();
      var shown = 0;
      rows.forEach(function (r) {
        var hit = !q || r.textContent.toLowerCase().indexOf(q) !== -1;
        r.hidden = !hit;
        if (hit) shown++;
      });
      if (counter) counter.textContent = q ? shown + " of " + rows.length : "";
    }
    input.addEventListener("input", apply);
  });

  /* ---------- copy buttons ---------- */

  doc.querySelectorAll("button[data-copy]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var text = btn.getAttribute("data-copy");
      var done = function () {
        btn.setAttribute("data-copied", "true");
        var label = btn.getAttribute("aria-label");
        btn.setAttribute("aria-label", "Copied");
        setTimeout(function () {
          btn.removeAttribute("data-copied");
          if (label) btn.setAttribute("aria-label", label);
        }, 1400);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, done);
      } else {
        var ta = el("textarea", {}, [text]);
        ta.style.position = "fixed";
        ta.style.opacity = "0";
        doc.body.appendChild(ta);
        ta.select();
        try { doc.execCommand("copy"); } catch (e) { /* ignore */ }
        doc.body.removeChild(ta);
        done();
      }
    });
  });

  /* ---------- charts ---------- */

  function buildChart(container) {
    var spec;
    try { spec = JSON.parse(container.getAttribute("data-chart")); } catch (e) { return; }
    var series = (spec.series || []).map(function (s) {
      return {
        name: s.name,
        color: s.color || "#4a7aa6",
        href: s.href || null,
        points: (s.points || []).filter(function (p) {
          return p && p.length >= 2 && p[1] !== null && isFinite(p[1]);
        })
      };
    });
    var type = spec.type === "scatter" ? "scatter" : "line";
    var height = spec.height || 240;
    var hidden = {};

    var svg = svgEl("svg", { "class": "dd-chart-svg", role: "img" });
    svg.setAttribute("aria-label", spec.title || "chart");
    var tip = el("div", { "class": "dd-chart-tip" });
    var legend = el("div", { "class": "dd-chart-legend" });
    container.appendChild(svg);
    container.appendChild(tip);
    if (series.length > 1 || type === "line" && series.length === 1 && spec.legend) {
      container.appendChild(legend);
    }

    series.forEach(function (s) {
      if (series.length <= 1 && !spec.legend) return;
      var btn = el("button", { type: "button", "aria-pressed": "true" }, [
        el("span", { "class": "dd-swatch" }), s.name
      ]);
      btn.firstChild.style.background = s.color;
      btn.addEventListener("click", function () {
        hidden[s.name] = !hidden[s.name];
        btn.setAttribute("aria-pressed", hidden[s.name] ? "false" : "true");
        draw();
      });
      legend.appendChild(btn);
    });

    var geometry = null;

    function draw() {
      while (svg.firstChild) svg.removeChild(svg.firstChild);
      var width = container.clientWidth - 32;
      if (!(width > 80)) width = 560;
      var m = { l: 54, r: 14, t: 12, b: 30 };
      svg.setAttribute("viewBox", "0 0 " + width + " " + height);
      svg.setAttribute("width", width);
      svg.setAttribute("height", height);

      var visible = series.filter(function (s) { return !hidden[s.name] && s.points.length; });
      var xs = [], ys = [];
      visible.forEach(function (s) {
        s.points.forEach(function (p) { xs.push(p[0]); ys.push(p[1]); });
      });
      if (!xs.length) {
        var t = svgEl("text", { x: width / 2, y: height / 2, "text-anchor": "middle", "class": "dd-chart-empty" });
        t.textContent = "nothing to plot";
        svg.appendChild(t);
        geometry = null;
        return;
      }
      var xmin = Math.min.apply(null, xs), xmax = Math.max.apply(null, xs);
      var ymin = Math.min.apply(null, ys), ymax = Math.max.apply(null, ys);
      var yd = niceDomain(ymin, ymax, 5);
      if (xmin === xmax) { xmin -= 0.5; xmax += 0.5; }
      var pw = width - m.l - m.r, ph = height - m.t - m.b;
      var sx = function (x) { return m.l + (x - xmin) / (xmax - xmin) * pw; };
      var sy = function (y) { return m.t + ph - (y - yd[0]) / (yd[1] - yd[0]) * ph; };

      var allInt = xs.every(function (x) { return Math.round(x) === x; });
      ticksBetween(yd[0], yd[1], 5, false).forEach(function (v) {
        var y = sy(v);
        svg.appendChild(svgEl("line", { x1: m.l, x2: width - m.r, y1: y, y2: y, "class": "dd-chart-grid" }));
        var t = svgEl("text", { x: m.l - 8, y: y + 3.5, "text-anchor": "end", "class": "dd-chart-tick" });
        t.textContent = fmtTick(v);
        svg.appendChild(t);
      });
      ticksBetween(xmin, xmax, Math.max(3, Math.min(7, Math.floor(pw / 80))), allInt).forEach(function (v) {
        var x = sx(v);
        var t = svgEl("text", { x: x, y: height - m.b + 16, "text-anchor": "middle", "class": "dd-chart-tick" });
        t.textContent = type === "scatter" && spec.xprefix ? spec.xprefix + fmtTick(v) : fmtTick(v);
        svg.appendChild(t);
      });
      svg.appendChild(svgEl("line", { x1: m.l, x2: width - m.r, y1: m.t + ph, y2: m.t + ph, "class": "dd-chart-axis" }));
      if (spec.xlabel) {
        var xl = svgEl("text", { x: width - m.r, y: height - 2, "text-anchor": "end", "class": "dd-chart-label" });
        xl.textContent = spec.xlabel;
        svg.appendChild(xl);
      }

      visible.forEach(function (s) {
        var pts = s.points.slice().sort(function (a, b) { return a[0] - b[0]; });
        if (type === "line" && pts.length > 1) {
          var d = "";
          pts.forEach(function (p, i) { d += (i ? " L" : "M") + sx(p[0]).toFixed(2) + " " + sy(p[1]).toFixed(2); });
          var path = svgEl("path", { d: d, "class": "dd-chart-line", stroke: s.color });
          svg.appendChild(path);
          if (visible.length === 1) {
            var area = svgEl("path", {
              d: d + " L" + sx(pts[pts.length - 1][0]).toFixed(2) + " " + (m.t + ph) + " L" + sx(pts[0][0]).toFixed(2) + " " + (m.t + ph) + " Z",
              "class": "dd-chart-area", fill: s.color
            });
            svg.insertBefore(area, path);
          }
        }
        var showPts = type === "scatter" || pts.length <= 40 || pts.length === 1;
        if (showPts) {
          pts.forEach(function (p) {
            svg.appendChild(svgEl("circle", {
              cx: sx(p[0]).toFixed(2), cy: sy(p[1]).toFixed(2),
              r: type === "scatter" ? 4.5 : (pts.length === 1 ? 4 : 2.6),
              fill: s.color, "class": "dd-chart-pt"
            }));
          });
        }
      });

      var cross = svgEl("line", { "class": "dd-chart-cross", y1: m.t, y2: m.t + ph, x1: -10, x2: -10 });
      cross.style.display = "none";
      svg.appendChild(cross);
      var hover = svgEl("rect", { x: m.l, y: m.t, width: pw, height: ph, "class": "dd-chart-hover" });
      svg.appendChild(hover);
      geometry = { sx: sx, sy: sy, xmin: xmin, xmax: xmax, pw: pw, m: m, width: width, cross: cross, visible: visible, hover: hover };

      hover.addEventListener("mousemove", onMove);
      hover.addEventListener("mouseleave", onLeave);
      hover.addEventListener("click", onClick);
    }

    function nearest(points, x) {
      var best = null, bd = Infinity;
      for (var i = 0; i < points.length; i++) {
        var d = Math.abs(points[i][0] - x);
        if (d < bd) { bd = d; best = points[i]; }
      }
      return best;
    }
    function dataX(evt) {
      var g = geometry;
      var rect = svg.getBoundingClientRect();
      var px = (evt.clientX - rect.left) * (g.width / rect.width);
      return g.xmin + (px - g.m.l) / g.pw * (g.xmax - g.xmin);
    }
    var lastHit = null;
    function onMove(evt) {
      var g = geometry;
      if (!g) return;
      var x = dataX(evt);
      var hits = [];
      g.visible.forEach(function (s) {
        var p = nearest(s.points, x);
        if (p) hits.push({ s: s, p: p });
      });
      if (!hits.length) return;
      hits.sort(function (a, b) { return Math.abs(a.p[0] - x) - Math.abs(b.p[0] - x); });
      var anchorX = hits[0].p[0];
      var rows = hits.filter(function (h) { return Math.abs(h.p[0] - anchorX) < 1e-9 || g.visible.length === 1; });
      if (!rows.length) rows = [hits[0]];
      rows.sort(function (a, b) { return b.p[1] - a.p[1]; });
      lastHit = rows[0];

      g.cross.style.display = "";
      g.cross.setAttribute("x1", g.sx(anchorX));
      g.cross.setAttribute("x2", g.sx(anchorX));

      while (tip.firstChild) tip.removeChild(tip.firstChild);
      var head = el("div", { "class": "dd-tip-x" });
      head.textContent = (type === "scatter" ? (spec.xprefix || "") : (spec.xlabel || "x") + " ") + fmtTick(anchorX);
      tip.appendChild(head);
      rows.slice(0, 12).forEach(function (h) {
        var row = el("div", { "class": "dd-tip-row" }, [
          el("span", { "class": "dd-swatch" }),
          el("span", { "class": "dd-tip-name" }, [h.p.length > 2 && h.p[2] ? h.p[2] : h.s.name]),
          el("span", { "class": "dd-tip-val" }, [fmtNumber(h.p[1])])
        ]);
        row.firstChild.style.background = h.s.color;
        tip.appendChild(row);
      });
      if (rows.length > 12) {
        var more = el("div", { "class": "dd-tip-x" });
        more.textContent = "+" + (rows.length - 12) + " more";
        tip.appendChild(more);
      }
      tip.setAttribute("data-show", "true");
      var crect = container.getBoundingClientRect();
      var left = evt.clientX - crect.left + 14;
      var top = evt.clientY - crect.top + 12;
      if (left + tip.offsetWidth > crect.width - 8) left = evt.clientX - crect.left - tip.offsetWidth - 14;
      if (top + tip.offsetHeight > crect.height - 4) top = Math.max(4, crect.height - tip.offsetHeight - 4);
      tip.style.left = left + "px";
      tip.style.top = top + "px";
    }
    function onLeave() {
      tip.removeAttribute("data-show");
      if (geometry) geometry.cross.style.display = "none";
      lastHit = null;
    }
    function onClick() {
      if (lastHit && lastHit.s.href) window.location.href = lastHit.s.href;
    }

    container.__redraw = draw;
    draw();

    if (window.ResizeObserver) {
      var pending = false;
      var lastW = container.clientWidth;
      new ResizeObserver(function () {
        if (container.clientWidth === lastW) return;
        lastW = container.clientWidth;
        if (pending) return;
        pending = true;
        requestAnimationFrame(function () { pending = false; draw(); });
      }).observe(container);
    }
  }
  doc.querySelectorAll("[data-chart]").forEach(buildChart);

  /* ---------- sparklines ---------- */

  doc.querySelectorAll("[data-spark]").forEach(function (node) {
    var pts;
    try { pts = JSON.parse(node.getAttribute("data-spark")); } catch (e) { return; }
    pts = pts.filter(function (v) { return v !== null && isFinite(v); });
    if (pts.length < 2) return;
    var w = 100, h = 26;
    var min = Math.min.apply(null, pts), max = Math.max.apply(null, pts);
    if (max === min) { max += 0.5; min -= 0.5; }
    var d = pts.map(function (v, i) {
      var x = (i / (pts.length - 1)) * w;
      var y = h - 2 - (v - min) / (max - min) * (h - 4);
      return (i ? "L" : "M") + x.toFixed(1) + " " + y.toFixed(1);
    }).join(" ");
    var svg = svgEl("svg", { "class": "dd-spark", viewBox: "0 0 " + w + " " + h, preserveAspectRatio: "none" });
    svg.appendChild(svgEl("path", { d: d, stroke: node.getAttribute("data-spark-color") || "currentColor" }));
    node.appendChild(svg);
  });

  /* ---------- inline editing ---------- */

  function inlineToggle(root, open) {
    var view = root.querySelector("[data-inline-view]");
    var form = root.querySelector("form[data-inline]");
    if (!view || !form) return;
    view.hidden = open;
    form.hidden = !open;
    if (open) {
      var field = form.querySelector("input:not([type=hidden]), textarea, select");
      if (field) { field.focus(); if (field.select) field.select(); }
    }
  }
  doc.querySelectorAll("[data-inline-open]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var root = doc.querySelector(btn.getAttribute("data-inline-open"));
      if (root) inlineToggle(root, true);
    });
  });
  doc.querySelectorAll("[data-inline-cancel]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var root = btn.closest(".dd-inline");
      if (root) inlineToggle(root, false);
    });
  });
  doc.querySelectorAll("form[data-inline]").forEach(function (form) {
    form.addEventListener("keydown", function (ev) {
      if (ev.key === "Escape") { ev.preventDefault(); inlineToggle(form.closest(".dd-inline"), false); }
    });
  });
  // A pointer pick applies at once; a keyboard change reveals the Apply button instead,
  // so arrowing through the options never submits by itself.
  doc.querySelectorAll("select[data-autosubmit]").forEach(function (select) {
    var viaKeyboard = false;
    select.addEventListener("keydown", function () { viaKeyboard = true; });
    select.addEventListener("mousedown", function () { viaKeyboard = false; });
    select.addEventListener("change", function () {
      var form = select.form;
      if (!form) return;
      if (viaKeyboard) {
        var apply = form.querySelector("[data-apply]");
        if (apply) { apply.classList.remove("dd-sr-only"); apply.classList.add("dd-btn", "dd-btn--sm"); }
        return;
      }
      if (form.requestSubmit) form.requestSubmit(); else form.submit();
    });
  });
  doc.querySelectorAll("[aria-disabled='true']").forEach(function (el) {
    el.addEventListener("click", function (ev) { ev.preventDefault(); });
  });

  /* ---------- actions menu ---------- */

  var menus = Array.prototype.slice.call(doc.querySelectorAll("details.dd-menu"));
  function closeMenus(except) {
    menus.forEach(function (m) { if (m !== except) m.open = false; });
  }
  menus.forEach(function (menu) {
    menu.addEventListener("toggle", function () { if (menu.open) closeMenus(menu); });
  });
  doc.addEventListener("click", function (ev) {
    if (!ev.target.closest || !ev.target.closest("details.dd-menu")) closeMenus(null);
  });
  doc.addEventListener("keydown", function (ev) {
    if (ev.key === "Escape") closeMenus(null);
  });

  function editing() {
    if (doc.querySelector("form[data-inline]:not([hidden])")) return true;
    if (doc.querySelector("details.dd-menu[open]")) return true;
    var tag = (doc.activeElement || {}).tagName;
    return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT";
  }

  /* ---------- confirmations ---------- */

  doc.querySelectorAll("form[data-confirm]").forEach(function (form) {
    form.addEventListener("submit", function (ev) {
      if (!window.confirm(form.getAttribute("data-confirm"))) ev.preventDefault();
    });
  });

  /* ---------- live refresh ---------- */

  var live = doc.querySelector("[data-live]");
  if (live) {
    var seconds = parseInt(live.getAttribute("data-live"), 10) || 15;
    var remaining = seconds;
    var paused = false;
    try { paused = sessionStorage.getItem("dd-live-paused") === "true"; } catch (e) { /* ignore */ }
    var label = live.querySelector("[data-live-label]");
    var btn = live.querySelector("button");
    function render() {
      live.setAttribute("data-paused", paused ? "true" : "false");
      if (label) label.textContent = paused ? "Live updates paused" : "Refreshing in " + remaining + " s";
      if (btn) btn.textContent = paused ? "Resume" : "Pause";
    }
    if (btn) {
      btn.addEventListener("click", function () {
        paused = !paused;
        remaining = seconds;
        try { sessionStorage.setItem("dd-live-paused", paused ? "true" : "false"); } catch (e) { /* ignore */ }
        render();
      });
    }
    setInterval(function () {
      if (paused || doc.hidden || editing()) return;
      remaining -= 1;
      if (remaining <= 0) { window.location.reload(); return; }
      render();
    }, 1000);
    render();
  }
})();

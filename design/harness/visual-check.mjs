import { chromium } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import { createServer as createNetServer } from 'node:net';

const explicitBaseURL = process.env.BASE_URL;
const outDir = new URL('../artifacts/', import.meta.url);
await fs.mkdir(outDir, { recursive: true });
const minGlobalTextContrast = 4.5;
const viewports = [
  { name: 'mobile', width: 390, height: 844, minTouchTarget: 44 },
  { name: 'tablet', width: 768, height: 1024, minTouchTarget: 44 },
  { name: 'desktop', width: 1024, height: 768, minTouchTarget: 36 },
  { name: 'wide', width: 1440, height: 1200, minTouchTarget: 36 },
];
const colorSchemes = ['light', 'dark'];
const expectedFocusOrder = ['View proof', 'Run scenario', 'Inspect states'];

async function getAvailablePort() {
  return new Promise((resolve, reject) => {
    const probe = createNetServer();
    probe.unref();
    probe.on('error', reject);
    probe.listen(0, '127.0.0.1', () => {
      const address = probe.address();
      if (!address || typeof address === 'string') {
        reject(new Error('Could not allocate a local port for visual check'));
        return;
      }
      probe.close(() => resolve(address.port));
    });
  });
}

const localPort = process.env.PORT ?? String(await getAvailablePort());
const baseURL = explicitBaseURL ?? `http://127.0.0.1:${localPort}`;

async function isReachable(url) {
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(800) });
    return response.ok || response.status < 500;
  } catch {
    return false;
  }
}

async function waitForServer(url, timeoutMs = 20_000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await isReachable(url)) return;
    await new Promise((resolve) => setTimeout(resolve, 300));
  }
  throw new Error(`Timed out waiting for ${url}`);
}

function parseRgb(value) {
  const match = value.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
  if (!match) return null;
  return match.slice(1, 4).map(Number);
}

function parseRgba(value) {
  const match = value.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([0-9.]+))?\)/);
  if (!match) return null;
  return {
    rgb: match.slice(1, 4).map(Number),
    alpha: match[4] === undefined ? 1 : Number(match[4]),
  };
}

function composite(over, under) {
  return over.rgb.map((channel, index) => Math.round(channel * over.alpha + under[index] * (1 - over.alpha)));
}

function luminance(rgb) {
  const [r, g, b] = rgb.map((v) => {
    const s = v / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrastRatio(fg, bg) {
  const a = luminance(fg);
  const b = luminance(bg);
  const light = Math.max(a, b);
  const dark = Math.min(a, b);
  return (light + 0.05) / (dark + 0.05);
}

async function collectKeyboardAudit(page) {
  await page.evaluate(() => {
    document.body.focus();
    window.scrollTo(0, 0);
  });

  const steps = [];
  for (let index = 0; index < expectedFocusOrder.length; index += 1) {
    await page.keyboard.press('Tab');
    await page.waitForTimeout(30);
    steps.push(await page.evaluate(() => {
      const active = document.activeElement;
      if (!active || active === document.body) {
        return {
          tag: active?.tagName?.toLowerCase() ?? null,
          text: '',
          href: null,
          visible: false,
          focusVisible: false,
          hasFocusIndicator: false,
        };
      }
      const rect = active.getBoundingClientRect();
      const styles = getComputedStyle(active);
      const outlineWidth = Number.parseFloat(styles.outlineWidth) || 0;
      const outlineStyle = styles.outlineStyle;
      const boxShadow = styles.boxShadow;
      const visible = styles.visibility !== 'hidden' && styles.display !== 'none' && rect.width > 0 && rect.height > 0;
      return {
        tag: active.tagName.toLowerCase(),
        text: active.textContent?.trim() ?? '',
        href: active.getAttribute('href'),
        visible,
        focusVisible: active.matches(':focus-visible'),
        outlineWidth,
        outlineStyle,
        outlineColor: styles.outlineColor,
        boxShadow,
        hasFocusIndicator: (outlineStyle !== 'none' && outlineWidth >= 2) || boxShadow !== 'none',
        rect: {
          width: Number(rect.width.toFixed(2)),
          height: Number(rect.height.toFixed(2)),
          left: Number(rect.left.toFixed(2)),
          top: Number(rect.top.toFixed(2)),
        },
      };
    }));
  }

  return {
    expectedOrder: expectedFocusOrder,
    actualOrder: steps.map((step) => step.text),
    steps,
  };
}

async function collectAxeAudit(page) {
  const scan = await new AxeBuilder({ page }).analyze();
  return {
    violations: scan.violations.map((violation) => ({
      id: violation.id,
      impact: violation.impact,
      help: violation.help,
      helpUrl: violation.helpUrl,
      tags: violation.tags,
      nodes: violation.nodes.map((node) => ({
        target: node.target,
        html: node.html,
        failureSummary: node.failureSummary,
      })),
    })),
    passes: scan.passes.length,
    incomplete: scan.incomplete.length,
    inapplicable: scan.inapplicable.length,
  };
}

async function collectDensityAudit(page) {
  return page.evaluate(() => {
    const visible = (node) => {
      const style = getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      return style.visibility !== 'hidden' && style.display !== 'none' && Number(style.opacity) > 0 && rect.width > 0 && rect.height > 0;
    };
    const rectOf = (node) => {
      const rect = node.getBoundingClientRect();
      return {
        left: Number((rect.left + window.scrollX).toFixed(2)),
        right: Number((rect.right + window.scrollX).toFixed(2)),
        top: Number((rect.top + window.scrollY).toFixed(2)),
        bottom: Number((rect.bottom + window.scrollY).toFixed(2)),
        width: Number(rect.width.toFixed(2)),
        height: Number(rect.height.toFixed(2)),
      };
    };
    const gapBetween = (a, b) => {
      const horizontalGap = Math.max(0, Math.max(a.left, b.left) - Math.min(a.right, b.right));
      const verticalGap = Math.max(0, Math.max(a.top, b.top) - Math.min(a.bottom, b.bottom));
      const overlapsX = horizontalGap === 0;
      const overlapsY = verticalGap === 0;
      const overlaps = overlapsX && overlapsY;
      let gap;
      if (overlaps) gap = 0;
      else if (overlapsX) gap = verticalGap;
      else if (overlapsY) gap = horizontalGap;
      else gap = Math.sqrt(horizontalGap ** 2 + verticalGap ** 2);
      return { gap: Number(gap.toFixed(2)), overlaps };
    };
    const pairAudits = (nodes, minGap) => {
      const pairs = [];
      for (let i = 0; i < nodes.length; i += 1) {
        for (let j = i + 1; j < nodes.length; j += 1) {
          const first = nodes[i];
          const second = nodes[j];
          const distance = gapBetween(first.rect, second.rect);
          const audit = {
            first: first.label,
            second: second.label,
            firstRect: first.rect,
            secondRect: second.rect,
            gap: distance.gap,
            overlaps: distance.overlaps,
            minGap,
            fails: distance.overlaps || distance.gap < minGap,
          };
          pairs.push(audit);
        }
      }
      return pairs;
    };

    const groups = [...document.querySelectorAll('[data-density-group]')].map((group) => {
      const name = group.getAttribute('data-density-group') ?? 'group';
      const minGap = Number(group.getAttribute('data-density-min') ?? 12);
      const items = [...group.children]
        .filter((node) => node instanceof HTMLElement && visible(node))
        .map((node, index) => ({
          label: `${name}[${index}] ${node.textContent?.trim().replace(/\s+/g, ' ').slice(0, 48) ?? ''}`,
          rect: rectOf(node),
        }));
      const pairs = pairAudits(items, minGap);
      const minObservedGap = pairs.length ? Math.min(...pairs.map((pair) => pair.gap)) : null;
      return {
        name,
        minGap,
        itemCount: items.length,
        minObservedGap,
        failures: pairs.filter((pair) => pair.fails),
        closestPairs: pairs.sort((a, b) => a.gap - b.gap).slice(0, 4),
      };
    });

    const hitTargets = [...document.querySelectorAll('a')]
      .filter(visible)
      .map((node) => ({
        label: node.textContent?.trim().replace(/\s+/g, ' ').slice(0, 48) || node.getAttribute('href') || 'link',
        rect: rectOf(node),
      }));
    const hitAreaMinGap = 8;
    const hitAreaPairs = pairAudits(hitTargets, hitAreaMinGap);

    return {
      groupCount: groups.length,
      groups,
      groupFailures: groups.flatMap((group) => group.failures.map((failure) => ({ group: group.name, ...failure }))),
      hitAreaMinGap,
      hitTargetCount: hitTargets.length,
      hitAreaFailures: hitAreaPairs.filter((pair) => pair.fails),
      closestHitAreaPairs: hitAreaPairs.sort((a, b) => a.gap - b.gap).slice(0, 6),
    };
  });
}

async function collectInteractionAudit(page) {
  const styleChanged = (before, after) => [
    'backgroundColor',
    'borderTopColor',
    'boxShadow',
    'color',
    'filter',
    'outlineColor',
    'outlineStyle',
    'outlineWidth',
    'transform',
    'translate',
  ].some((key) => before[key] !== after[key])
    || Math.abs(before.rect.left - after.rect.left) > 0.5
    || Math.abs(before.rect.top - after.rect.top) > 0.5
    || Math.abs(before.rect.width - after.rect.width) > 0.5
    || Math.abs(before.rect.height - after.rect.height) > 0.5;

  const snapshot = async (locator) => locator.evaluate((node) => {
    const style = getComputedStyle(node);
    const rect = node.getBoundingClientRect();
    return {
      tag: node.tagName.toLowerCase(),
      name: node.getAttribute('data-interaction-probe') ?? node.getAttribute('data-interaction-state') ?? '',
      text: node.textContent?.trim().replace(/\s+/g, ' ') ?? '',
      visible: style.visibility !== 'hidden' && style.display !== 'none' && Number(style.opacity) > 0 && rect.width > 0 && rect.height > 0,
      disabled: node.matches(':disabled'),
      ariaDisabled: node.getAttribute('aria-disabled'),
      ariaBusy: node.getAttribute('aria-busy'),
      cursor: style.cursor,
      opacity: style.opacity,
      backgroundColor: style.backgroundColor,
      borderTopColor: style.borderTopColor,
      borderTopStyle: style.borderTopStyle,
      borderTopWidth: style.borderTopWidth,
      boxShadow: style.boxShadow,
      color: style.color,
      filter: style.filter,
      outlineColor: style.outlineColor,
      outlineStyle: style.outlineStyle,
      outlineWidth: style.outlineWidth,
      transform: style.transform,
      translate: style.translate,
      rect: {
        width: Number(rect.width.toFixed(2)),
        height: Number(rect.height.toFixed(2)),
        left: Number(rect.left.toFixed(2)),
        top: Number(rect.top.toFixed(2)),
      },
    };
  });

  const probes = [];
  const probeLocator = page.locator('[data-interaction-probe]');
  const probeCount = await probeLocator.count();
  for (let index = 0; index < probeCount; index += 1) {
    const target = probeLocator.nth(index);
    if (!(await target.isVisible())) continue;
    await target.scrollIntoViewIfNeeded();
    await page.waitForTimeout(30);
    const baseline = await snapshot(target);
    await target.hover();
    await page.waitForTimeout(80);
    const hover = await snapshot(target);
    const box = await target.boundingBox();
    if (box) {
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.down();
      await page.waitForTimeout(80);
    }
    const active = await snapshot(target);
    await page.mouse.up();
    await page.evaluate(() => {
      if (document.activeElement instanceof HTMLElement) document.activeElement.blur();
      window.history.replaceState(null, '', window.location.pathname);
      window.scrollTo(0, 0);
    });
    probes.push({
      name: baseline.name,
      text: baseline.text,
      baseline,
      hover,
      active,
      hoverChanged: styleChanged(baseline, hover),
      activeChanged: styleChanged(hover, active) || styleChanged(baseline, active),
    });
  }

  const stateSamples = await page.evaluate(() => {
    const visible = (node) => {
      const style = getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      return style.visibility !== 'hidden' && style.display !== 'none' && Number(style.opacity) > 0 && rect.width > 0 && rect.height > 0;
    };
    return [...document.querySelectorAll('[data-interaction-state]')]
      .filter(visible)
      .map((node) => {
        const style = getComputedStyle(node);
        const rect = node.getBoundingClientRect();
        return {
          state: node.getAttribute('data-interaction-state'),
          tag: node.tagName.toLowerCase(),
          text: node.textContent?.trim().replace(/\s+/g, ' ') ?? '',
          disabled: node.matches(':disabled'),
          ariaDisabled: node.getAttribute('aria-disabled'),
          ariaBusy: node.getAttribute('aria-busy'),
          busyIndicatorVisible: Boolean(node.querySelector('[aria-hidden="true"]')),
          cursor: style.cursor,
          opacity: style.opacity,
          backgroundColor: style.backgroundColor,
          borderTopColor: style.borderTopColor,
          borderTopStyle: style.borderTopStyle,
          color: style.color,
          minHeight: Number(rect.height.toFixed(2)),
          width: Number(rect.width.toFixed(2)),
        };
      });
  });

  const loading = stateSamples.find((sample) => sample.state === 'loading');
  const disabled = stateSamples.find((sample) => sample.state === 'disabled');
  const stateFailures = [];
  if (!loading) {
    stateFailures.push('missing loading interaction state');
  } else {
    if (loading.ariaBusy !== 'true') stateFailures.push('loading state must expose aria-busy=true');
    if (!loading.disabled) stateFailures.push('loading state must be disabled while busy');
    if (!loading.busyIndicatorVisible) stateFailures.push('loading state must include a visible busy indicator');
    if (loading.cursor !== 'wait') stateFailures.push(`loading state cursor must be wait, got ${loading.cursor}`);
  }
  if (!disabled) {
    stateFailures.push('missing disabled interaction state');
  } else {
    if (!disabled.disabled) stateFailures.push('disabled state must use disabled attribute');
    if (disabled.ariaDisabled !== 'true') stateFailures.push('disabled state must expose aria-disabled=true');
    if (disabled.cursor !== 'not-allowed') stateFailures.push(`disabled state cursor must be not-allowed, got ${disabled.cursor}`);
  }
  if (loading && disabled) {
    const loadingSignature = `${loading.backgroundColor}|${loading.borderTopColor}|${loading.color}|${loading.borderTopStyle}`;
    const disabledSignature = `${disabled.backgroundColor}|${disabled.borderTopColor}|${disabled.color}|${disabled.borderTopStyle}`;
    if (loadingSignature === disabledSignature) stateFailures.push('loading and disabled states must be visually distinct');
  }

  return {
    probeCount: probes.length,
    probes,
    hoverFailures: probes.filter((probe) => !probe.hoverChanged),
    activeFailures: probes.filter((probe) => !probe.activeChanged),
    stateSamples,
    stateFailures,
  };
}

async function collectHierarchyAudit(page) {
  return page.evaluate(() => {
    const parseRgba = (value) => {
      const match = value.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([0-9.]+))?\)/);
      if (!match) return null;
      return {
        rgb: match.slice(1, 4).map(Number),
        alpha: match[4] === undefined ? 1 : Number(match[4]),
      };
    };
    const visible = (node) => {
      const style = getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      return style.visibility !== 'hidden' && style.display !== 'none' && Number(style.opacity) > 0 && rect.width > 0 && rect.height > 0;
    };
    const bgDistance = (a, b) => {
      const first = parseRgba(a);
      const second = parseRgba(b);
      if (!first || !second) return null;
      return Number(Math.sqrt(first.rgb.reduce((sum, value, index) => sum + (value - second.rgb[index]) ** 2, 0)).toFixed(2));
    };
    const read = (selector, label = selector) => {
      const node = document.querySelector(selector);
      if (!node || !visible(node)) return null;
      const style = getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      return {
        label,
        tag: node.tagName.toLowerCase(),
        text: node.textContent?.trim().replace(/\s+/g, ' ').slice(0, 96) ?? '',
        fontSize: Number.parseFloat(style.fontSize) || 0,
        fontWeight: Number.parseFloat(style.fontWeight) || 0,
        lineHeight: Number.parseFloat(style.lineHeight) || 0,
        color: style.color,
        backgroundColor: style.backgroundColor,
        borderTopWidth: Number.parseFloat(style.borderTopWidth) || 0,
        borderTopStyle: style.borderTopStyle,
        boxShadow: style.boxShadow,
        area: Number((rect.width * rect.height).toFixed(2)),
        rect: {
          width: Number(rect.width.toFixed(2)),
          height: Number(rect.height.toFixed(2)),
          top: Number(rect.top.toFixed(2)),
          left: Number(rect.left.toFixed(2)),
          bottom: Number(rect.bottom.toFixed(2)),
        },
      };
    };

    const heroTitle = read('[data-visual-priority="hero-title"]', 'hero-title');
    const sectionTitle = read('[data-visual-priority="section-title"]', 'section-title');
    const protocolTitle = read('[data-visual-priority="protocol-title"]', 'protocol-title');
    const verificationTitle = read('[data-visual-priority="verification-title"]', 'verification-title');
    const featureTitles = [...document.querySelectorAll('[data-visual-priority="feature-title"]')]
      .filter(visible)
      .map((node, index) => read(`[data-visual-priority="feature-title"]:nth-of-type(${index + 1})`, `feature-title-${index + 1}`) ?? (() => {
        const style = getComputedStyle(node);
        const rect = node.getBoundingClientRect();
        return {
          label: `feature-title-${index + 1}`,
          tag: node.tagName.toLowerCase(),
          text: node.textContent?.trim().replace(/\s+/g, ' ').slice(0, 96) ?? '',
          fontSize: Number.parseFloat(style.fontSize) || 0,
          fontWeight: Number.parseFloat(style.fontWeight) || 0,
          lineHeight: Number.parseFloat(style.lineHeight) || 0,
          color: style.color,
          backgroundColor: style.backgroundColor,
          borderTopWidth: Number.parseFloat(style.borderTopWidth) || 0,
          borderTopStyle: style.borderTopStyle,
          boxShadow: style.boxShadow,
          area: Number((rect.width * rect.height).toFixed(2)),
          rect: {
            width: Number(rect.width.toFixed(2)),
            height: Number(rect.height.toFixed(2)),
            top: Number(rect.top.toFixed(2)),
            left: Number(rect.left.toFixed(2)),
            bottom: Number(rect.bottom.toFixed(2)),
          },
        };
      })());
    const primaryAction = read('[data-visual-priority="primary-action"]', 'primary-action');
    const secondaryAction = read('[data-visual-priority="secondary-action"]', 'secondary-action');
    const verificationPanel = read('[data-visual-priority="verification-panel"]', 'verification-panel');
    const bodyStyle = getComputedStyle(document.body);
    const maxFeatureFont = Math.max(...featureTitles.map((item) => item.fontSize), 0);
    const primaryToBodyBgDistance = primaryAction ? bgDistance(primaryAction.backgroundColor, bodyStyle.backgroundColor) : null;
    const primaryToSecondaryBgDistance = primaryAction && secondaryAction ? bgDistance(primaryAction.backgroundColor, secondaryAction.backgroundColor) : null;

    const failures = [];
    if (document.querySelectorAll('h1').length !== 1) failures.push(`expected exactly one h1, got ${document.querySelectorAll('h1').length}`);
    if (!heroTitle) failures.push('missing visible hero title');
    if (!sectionTitle) failures.push('missing visible section title');
    if (!protocolTitle) failures.push('missing visible protocol title');
    if (!verificationTitle) failures.push('missing visible verification title');
    if (featureTitles.length < 3) failures.push(`expected at least 3 feature titles, got ${featureTitles.length}`);
    if (!primaryAction) failures.push('missing visible primary action');
    if (!secondaryAction) failures.push('missing visible secondary action');
    if (!verificationPanel) failures.push('missing visible verification panel');

    if (heroTitle && sectionTitle && heroTitle.fontSize < sectionTitle.fontSize + 8) {
      failures.push(`hero title font size ${heroTitle.fontSize}px must exceed section title ${sectionTitle.fontSize}px by at least 8px`);
    }
    if (heroTitle && protocolTitle && heroTitle.fontSize < protocolTitle.fontSize + 12) {
      failures.push(`hero title font size ${heroTitle.fontSize}px must exceed protocol title ${protocolTitle.fontSize}px by at least 12px`);
    }
    if (sectionTitle && maxFeatureFont && sectionTitle.fontSize < maxFeatureFont + 8) {
      failures.push(`section title font size ${sectionTitle.fontSize}px must exceed feature title ${maxFeatureFont}px by at least 8px`);
    }
    if (heroTitle && heroTitle.fontWeight < 600) failures.push(`hero title weight ${heroTitle.fontWeight} must be at least 600`);
    if (primaryAction && secondaryAction && primaryAction.fontWeight < secondaryAction.fontWeight) {
      failures.push(`primary action weight ${primaryAction.fontWeight} must be >= secondary action weight ${secondaryAction.fontWeight}`);
    }
    if (primaryAction && secondaryAction && primaryAction.area < secondaryAction.area * 0.8) {
      failures.push(`primary action area ${primaryAction.area} is too small relative to secondary action ${secondaryAction.area}`);
    }
    if (primaryToBodyBgDistance !== null && primaryToBodyBgDistance < 80) {
      failures.push(`primary action background distance from body is too low: ${primaryToBodyBgDistance}`);
    }
    if (primaryToSecondaryBgDistance !== null && primaryToSecondaryBgDistance < 80) {
      failures.push(`primary and secondary action backgrounds are too similar: ${primaryToSecondaryBgDistance}`);
    }
    if (secondaryAction && secondaryAction.borderTopWidth < 1) failures.push('secondary action must keep a visible border');
    if (verificationPanel && verificationPanel.boxShadow === 'none') failures.push('verification panel must keep elevation shadow');
    if (heroTitle && primaryAction && primaryAction.rect.top <= heroTitle.rect.bottom) {
      failures.push('primary action must appear below hero title');
    }
    if (heroTitle && heroTitle.rect.top > window.innerHeight * 0.45) {
      failures.push(`hero title starts too low in viewport: ${heroTitle.rect.top}px`);
    }

    return {
      failures,
      h1Count: document.querySelectorAll('h1').length,
      heroTitle,
      sectionTitle,
      protocolTitle,
      verificationTitle,
      featureTitles,
      primaryAction,
      secondaryAction,
      verificationPanel,
      primaryToBodyBgDistance,
      primaryToSecondaryBgDistance,
      maxFeatureFont,
    };
  });
}

async function collectCopyQualityAudit(page) {
  return page.evaluate(() => {
    const bannedPatterns = [
      /lorem ipsum/i,
      /click here/i,
      /learn more/i,
      /get started/i,
      /seamless(?:ly)?/i,
      /revolutionary/i,
      /game[- ]changing/i,
      /next[- ]gen/i,
      /all[- ]in[- ]one/i,
      /world[- ]class/i,
      /cutting[- ]edge/i,
      /unlock (?:the )?(?:power|potential)/i,
      /transform your (?:business|workflow|product)/i,
      /powerful solution/i,
      /intuitive platform/i,
      /robust platform/i,
      /supercharge/i,
      /AI[- ]powered/i,
    ];
    const concretePatterns = [
      /DESIGN\.md/i,
      /Claude Code/i,
      /Codex/i,
      /getdesign/i,
      /omx doctor/i,
      /sha256/i,
      /hash/i,
      /screenshot/i,
      /DOM/i,
      /evidence/i,
      /lint/i,
      /build/i,
      /visual checks?/i,
      /loading\/empty\/error\/success/i,
      /Loading|Empty|Error|Success/,
      /recovery/i,
      /symlink/i,
      /skill manifest|skill counts/i,
      /design entrypoints/i,
      /project-local/i,
      /MacBook Pro|MacBook Air/i,
      /viewport|responsive/i,
      /contrast/i,
      /typography|elevation|state/i,
      /prompt guide|prompt/i,
      /component rules|visual language/i,
      /operator/i,
    ];
    const actionVerbs = /^(Load|Generate|Run|Compare|Rebuilding|Resolving|No|A broken|DESIGN\.md|\$|omx|design)/;
    const visible = (node) => {
      const style = getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      return style.visibility !== 'hidden' && style.display !== 'none' && Number(style.opacity) > 0 && rect.width > 0 && rect.height > 0;
    };
    const wordCount = (text) => (text.match(/[A-Za-z0-9가-힣._:-]+/g) ?? []).length;
    const concreteCount = (text) => concretePatterns.filter((pattern) => pattern.test(text)).length;
    const targets = [...document.querySelectorAll('[data-copy-quality]')]
      .filter(visible)
      .map((node) => {
        const role = node.getAttribute('data-copy-quality') ?? 'copy';
        const text = node.textContent?.trim().replace(/\s+/g, ' ') ?? '';
        return {
          role,
          tag: node.tagName.toLowerCase(),
          text,
          wordCount: wordCount(text),
          characterCount: text.length,
          concreteCount: concreteCount(text),
          bannedMatches: bannedPatterns.filter((pattern) => pattern.test(text)).map((pattern) => pattern.source),
          startsWithAction: actionVerbs.test(text),
        };
      });

    const byRole = (role) => targets.filter((target) => target.role === role);
    const failures = [];
    if (targets.length < 24) failures.push(`expected at least 24 copy-quality targets, got ${targets.length}`);
    const banned = targets.filter((target) => target.bannedMatches.length);
    if (banned.length) failures.push(`generic/banned copy detected: ${banned.map((target) => `${target.role} "${target.text}"`).join(', ')}`);

    for (const target of targets) {
      if (target.characterCount > 180 && !['command-copy', 'attestation-copy', 'hash-copy'].includes(target.role)) {
        failures.push(`${target.role} is too long for scannable UI copy: ${target.characterCount} chars`);
      }
      if (['hero-copy', 'feature-body', 'section-copy', 'state-copy', 'protocol-copy'].includes(target.role) && target.concreteCount < 1) {
        failures.push(`${target.role} lacks concrete product/evidence language: "${target.text}"`);
      }
    }

    const heroCopy = byRole('hero-copy')[0];
    if (!heroCopy || heroCopy.concreteCount < 3) failures.push('hero copy must include at least three concrete evidence/domain anchors');
    if (byRole('feature-body').length < 3) failures.push(`expected at least 3 feature body copy targets, got ${byRole('feature-body').length}`);
    for (const feature of byRole('feature-body')) {
      if (feature.concreteCount < 2) failures.push(`feature body must include at least two concrete anchors: "${feature.text}"`);
    }

    const stateCopies = byRole('state-copy');
    if (stateCopies.length < 4) failures.push(`expected 4 state copy targets, got ${stateCopies.length}`);
    const errorCopy = stateCopies.find((target) => /broken symlink|Run getdesign doctor/i.test(target.text));
    if (!errorCopy) failures.push('error state must name the failure and include Run getdesign doctor recovery path');
    const loadingCopy = stateCopies.find((target) => /Rebuilding|resolving|…|\.\.\./i.test(target.text));
    if (!loadingCopy) failures.push('loading state must describe active work, not a generic loading label');
    const emptyCopy = stateCopies.find((target) => /No design drift/i.test(target.text));
    if (!emptyCopy) failures.push('empty state must explain what absence means');
    const successCopy = stateCopies.find((target) => /linked/i.test(target.text) && /DESIGN\.md/i.test(target.text));
    if (!successCopy) failures.push('success state must name the verified artifact and outcome');

    const protocolCopies = byRole('protocol-copy');
    if (protocolCopies.length !== 4) failures.push(`expected 4 protocol copy targets, got ${protocolCopies.length}`);
    for (const protocol of protocolCopies) {
      if (!/^(Load|Generate|Run|Compare)\b/.test(protocol.text)) {
        failures.push(`protocol copy must start with an operator verb: "${protocol.text}"`);
      }
      if (protocol.concreteCount < 1) {
        failures.push(`protocol copy must include a concrete artifact/check: "${protocol.text}"`);
      }
    }

    const evidenceCopies = ['command-copy', 'attestation-copy', 'hash-copy'].flatMap(byRole);
    if (evidenceCopies.length < 3) failures.push(`expected command, attestation, and hash evidence copy, got ${evidenceCopies.length}`);
    if (!evidenceCopies.some((target) => /omx doctor: 14 passed · 0 warnings · 0 failed/.test(target.text))) {
      failures.push('attestation copy must include concrete pass/warning/fail counts');
    }
    if (!evidenceCopies.some((target) => /sha256: [a-f0-9]{16}/i.test(target.text))) {
      failures.push('hash copy must include a sha256 prefix');
    }

    return {
      targetCount: targets.length,
      targets,
      failures,
      bannedPatternCount: bannedPatterns.length,
      concretePatternCount: concretePatterns.length,
      roleCounts: targets.reduce((acc, target) => {
        acc[target.role] = (acc[target.role] ?? 0) + 1;
        return acc;
      }, {}),
    };
  });
}

function rectChanged(before, after) {
  return ['width', 'height', 'docLeft', 'docTop'].some((key) => Math.abs(before[key] - after[key]) > 0.5);
}

function normalizeNoOpTransform(value) {
  return ['none', 'matrix(1, 0, 0, 1, 0, 0)', 'translate(0px)', 'translate(0)'].includes(value) ? 'none' : value;
}

function normalizeNoOpTranslate(value) {
  return ['none', '0px', '0px 0px', '0px 0px 0px', '0 0', '0'].includes(value) ? 'none' : value;
}

function transformChanged(before, after) {
  return normalizeNoOpTransform(before.transform) !== normalizeNoOpTransform(after.transform)
    || normalizeNoOpTranslate(before.translate) !== normalizeNoOpTranslate(after.translate);
}

async function collectReducedMotionAudit(browser, viewport, colorScheme) {
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: 1,
    colorScheme,
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();
  await page.goto(baseURL, { waitUntil: 'networkidle' });

  const staticAudit = await page.evaluate(() => {
    const parseTimeList = (value) => value
      .split(',')
      .map((part) => part.trim())
      .filter(Boolean)
      .map((part) => {
        if (part.endsWith('ms')) return Number.parseFloat(part);
        if (part.endsWith('s')) return Number.parseFloat(part) * 1000;
        return Number.parseFloat(part) || 0;
      });
    const visible = (node) => {
      const style = getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      return style.visibility !== 'hidden' && style.display !== 'none' && Number(style.opacity) > 0 && rect.width > 0 && rect.height > 0;
    };
    const motionOffenders = [...document.querySelectorAll('body *')]
      .filter(visible)
      .map((node) => {
        const style = getComputedStyle(node);
        const transitionMs = Math.max(...parseTimeList(style.transitionDuration), 0);
        const transitionDelayMs = Math.max(...parseTimeList(style.transitionDelay), 0);
        const animationMs = style.animationName === 'none' ? 0 : Math.max(...parseTimeList(style.animationDuration), 0);
        const animationDelayMs = style.animationName === 'none' ? 0 : Math.max(...parseTimeList(style.animationDelay), 0);
        return {
          tag: node.tagName.toLowerCase(),
          text: node.textContent?.trim().replace(/\s+/g, ' ').slice(0, 80) ?? '',
          transitionDuration: style.transitionDuration,
          transitionDelay: style.transitionDelay,
          animationName: style.animationName,
          animationDuration: style.animationDuration,
          animationDelay: style.animationDelay,
          transitionMs,
          transitionDelayMs,
          animationMs,
          animationDelayMs,
        };
      })
      .filter((item) => item.transitionMs > 0 || item.transitionDelayMs > 0 || item.animationMs > 0 || item.animationDelayMs > 0);

    return {
      mediaMatches: window.matchMedia('(prefers-reduced-motion: reduce)').matches,
      scrollBehavior: getComputedStyle(document.documentElement).scrollBehavior,
      motionOffenders,
    };
  });

  const hoverTargets = [];
  const targetLocator = page.locator('a, article, .motion-accent-bar');
  const targetCount = await targetLocator.count();
  for (let index = 0; index < targetCount; index += 1) {
    const target = targetLocator.nth(index);
    if (!(await target.isVisible())) continue;
    const before = await target.evaluate((node) => {
      const rect = node.getBoundingClientRect();
      return {
        tag: node.tagName.toLowerCase(),
        text: node.textContent?.trim().replace(/\s+/g, ' ').slice(0, 80) ?? '',
        transform: getComputedStyle(node).transform,
        translate: getComputedStyle(node).translate,
        width: Number(rect.width.toFixed(2)),
        height: Number(rect.height.toFixed(2)),
        left: Number(rect.left.toFixed(2)),
        top: Number(rect.top.toFixed(2)),
        docLeft: Number((rect.left + window.scrollX).toFixed(2)),
        docTop: Number((rect.top + window.scrollY).toFixed(2)),
      };
    });
    await target.hover();
    await page.waitForTimeout(50);
    const after = await target.evaluate((node) => {
      const rect = node.getBoundingClientRect();
      return {
        transform: getComputedStyle(node).transform,
        translate: getComputedStyle(node).translate,
        width: Number(rect.width.toFixed(2)),
        height: Number(rect.height.toFixed(2)),
        left: Number(rect.left.toFixed(2)),
        top: Number(rect.top.toFixed(2)),
        docLeft: Number((rect.left + window.scrollX).toFixed(2)),
        docTop: Number((rect.top + window.scrollY).toFixed(2)),
      };
    });
    hoverTargets.push({
      ...before,
      after,
      transformChanged: transformChanged(before, after),
      rectChanged: rectChanged(before, after),
    });
  }

  await context.close();

  return {
    ...staticAudit,
    hoverTargets,
    hoverMotionOffenders: hoverTargets.filter((target) => target.transformChanged || target.rectChanged),
  };
}

async function collectForcedColorsAudit(browser, viewport, colorScheme) {
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: 1,
    colorScheme,
    forcedColors: 'active',
  });
  const page = await context.newPage();
  await page.goto(baseURL, { waitUntil: 'networkidle' });

  const staticAudit = await page.evaluate(() => {
    const minTextContrast = 4.5;
    const parseRgba = (value) => {
      const match = value.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([0-9.]+))?\)/);
      if (!match) return null;
      return {
        rgb: match.slice(1, 4).map(Number),
        alpha: match[4] === undefined ? 1 : Number(match[4]),
      };
    };
    const composite = (over, under) => over.rgb.map((channel, index) => channel * over.alpha + under[index] * (1 - over.alpha));
    const luminance = (rgb) => {
      const [r, g, b] = rgb.map((v) => {
        const s = v / 255;
        return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
      });
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    };
    const contrastRatio = (fg, bg) => {
      const a = luminance(fg);
      const b = luminance(bg);
      const light = Math.max(a, b);
      const dark = Math.min(a, b);
      return (light + 0.05) / (dark + 0.05);
    };
    const visible = (node) => {
      const style = getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      return style.visibility !== 'hidden' && style.display !== 'none' && Number(style.opacity) > 0 && rect.width > 0 && rect.height > 0;
    };
    const hasDirectText = (node) => [...node.childNodes].some((child) => child.nodeType === Node.TEXT_NODE && child.textContent?.trim());
    const effectiveBackground = (node) => {
      const chain = [];
      let current = node;
      while (current && current.nodeType === Node.ELEMENT_NODE) {
        chain.push(current);
        current = current.parentElement;
      }
      let background = [255, 255, 255];
      for (const element of chain.reverse()) {
        const color = parseRgba(getComputedStyle(element).backgroundColor);
        if (color && color.alpha > 0) {
          background = composite(color, background);
        }
      }
      return background;
    };
    const backgroundImageActive = (value) => value
      .split(',')
      .map((part) => part.trim())
      .some((part) => part && part !== 'none');

    const contrastAudits = [...document.querySelectorAll('body *')]
      .filter((node) => visible(node) && hasDirectText(node))
      .map((node) => {
        const style = getComputedStyle(node);
        const foreground = parseRgba(style.color);
        const background = effectiveBackground(node);
        const ratio = foreground ? contrastRatio(foreground.rgb, background) : null;
        const text = [...node.childNodes]
          .filter((child) => child.nodeType === Node.TEXT_NODE)
          .map((child) => child.textContent?.trim())
          .filter(Boolean)
          .join(' ')
          .slice(0, 96);
        return {
          tag: node.tagName.toLowerCase(),
          text,
          color: style.color,
          effectiveBackground: `rgb(${background.map((value) => Math.round(value)).join(', ')})`,
          contrastRatio: ratio === null ? null : Number(ratio.toFixed(2)),
        };
      });
    const lowContrastText = contrastAudits
      .filter((audit) => audit.contrastRatio === null || audit.contrastRatio < minTextContrast)
      .sort((a, b) => (a.contrastRatio ?? 0) - (b.contrastRatio ?? 0));

    const boundaries = [...document.querySelectorAll('[data-forced-colors-boundary]')]
      .filter(visible)
      .map((node) => {
        const style = getComputedStyle(node);
        const rect = node.getBoundingClientRect();
        const borderWidth = Number.parseFloat(style.borderTopWidth) || 0;
        const borderColor = parseRgba(style.borderTopColor);
        const borderVisible = style.borderTopStyle !== 'none' && borderWidth >= 1 && (!borderColor || borderColor.alpha > 0);
        return {
          tag: node.tagName.toLowerCase(),
          text: node.textContent?.trim().replace(/\s+/g, ' ').slice(0, 80) ?? '',
          width: Number(rect.width.toFixed(2)),
          height: Number(rect.height.toFixed(2)),
          color: style.color,
          backgroundColor: style.backgroundColor,
          borderColor: style.borderTopColor,
          borderStyle: style.borderTopStyle,
          borderWidth,
          borderVisible,
        };
      });

    const backgroundImageOffenders = [...document.querySelectorAll('body *')]
      .filter(visible)
      .map((node) => {
        const style = getComputedStyle(node);
        return {
          tag: node.tagName.toLowerCase(),
          text: node.textContent?.trim().replace(/\s+/g, ' ').slice(0, 80) ?? '',
          backgroundImage: style.backgroundImage,
        };
      })
      .filter((item) => backgroundImageActive(item.backgroundImage));

    return {
      mediaMatches: window.matchMedia('(forced-colors: active)').matches,
      contrastAudit: {
        minRequired: minTextContrast,
        checkedTextNodes: contrastAudits.length,
        lowest: contrastAudits
          .filter((audit) => audit.contrastRatio !== null)
          .sort((a, b) => a.contrastRatio - b.contrastRatio)
          .slice(0, 8),
        failures: lowContrastText.slice(0, 12),
      },
      boundaryAudit: {
        checkedBoundaries: boundaries.length,
        failures: boundaries.filter((boundary) => !boundary.borderVisible),
        sample: boundaries.slice(0, 12),
      },
      backgroundImageOffenders,
    };
  });

  const keyboardAudit = await collectKeyboardAudit(page);
  const screenshotName = `design-loop-home-forced-colors-${viewport.name}-${colorScheme}.png`;
  await page.screenshot({ path: new URL(screenshotName, outDir).pathname, fullPage: true });
  await context.close();

  return {
    ...staticAudit,
    keyboardAudit,
    screenshot: `artifacts/${screenshotName}`,
  };
}

async function collectTextZoomAudit(browser, viewport, colorScheme) {
  const zoomLevels = [150, 200];
  const audits = [];
  const screenshots = [];

  for (const zoomPercent of zoomLevels) {
    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      deviceScaleFactor: 1,
      colorScheme,
    });
    const page = await context.newPage();
    await page.goto(baseURL, { waitUntil: 'networkidle' });
    await page.addStyleTag({ content: `html { font-size: ${zoomPercent}% !important; }` });
    await page.waitForTimeout(100);

    const audit = await page.evaluate(({ minTouchTarget }) => {
      const visible = (node) => {
        const style = getComputedStyle(node);
        const rect = node.getBoundingClientRect();
        return style.visibility !== 'hidden' && style.display !== 'none' && Number(style.opacity) > 0 && rect.width > 0 && rect.height > 0;
      };
      const rectSummary = (selector) => {
        const node = document.querySelector(selector);
        if (!node) return { selector, exists: false, visible: false };
        const rect = node.getBoundingClientRect();
        const style = getComputedStyle(node);
        return {
          selector,
          exists: true,
          visible: style.visibility !== 'hidden' && style.display !== 'none' && rect.width > 0 && rect.height > 0,
          width: Number(rect.width.toFixed(2)),
          height: Number(rect.height.toFixed(2)),
          left: Number(rect.left.toFixed(2)),
          right: Number(rect.right.toFixed(2)),
          horizontallyClipped: rect.left < -1 || rect.right > window.innerWidth + 1,
        };
      };
      const sections = ['main', 'nav', '#verification', '#scenario', '#states', '#protocol'].map(rectSummary);
      const anchorTargets = [...document.querySelectorAll('a')]
        .filter((node) => visible(node))
        .map((node) => {
          const rect = node.getBoundingClientRect();
          return {
            text: node.textContent?.trim() ?? '',
            width: Number(rect.width.toFixed(2)),
            height: Number(rect.height.toFixed(2)),
            left: Number(rect.left.toFixed(2)),
            right: Number(rect.right.toFixed(2)),
            meetsTarget: rect.width >= minTouchTarget && rect.height >= minTouchTarget,
            horizontallyClipped: rect.left < -1 || rect.right > window.innerWidth + 1,
          };
        });
      const horizontalOverflowPx = Math.max(
        0,
        document.documentElement.scrollWidth - document.documentElement.clientWidth,
        document.body.scrollWidth - document.body.clientWidth,
      );
      return {
        rootFontSize: getComputedStyle(document.documentElement).fontSize,
        horizontalOverflowPx,
        sections,
        missingOrHiddenSections: sections.filter((section) => !section.exists || !section.visible),
        horizontallyClippedSections: sections.filter((section) => section.horizontallyClipped),
        anchorTargets,
        undersizedAnchorTargets: anchorTargets.filter((target) => !target.meetsTarget),
        clippedAnchorTargets: anchorTargets.filter((target) => target.horizontallyClipped),
      };
    }, { minTouchTarget: viewport.minTouchTarget });

    let screenshot = null;
    if (zoomPercent === 200) {
      const screenshotName = `design-loop-home-text-zoom-${zoomPercent}-${viewport.name}-${colorScheme}.png`;
      await page.screenshot({ path: new URL(screenshotName, outDir).pathname, fullPage: true });
      screenshot = `artifacts/${screenshotName}`;
      screenshots.push(screenshot);
    }

    audits.push({
      zoomPercent,
      screenshot,
      ...audit,
    });
    await context.close();
  }

  return {
    levels: audits,
    screenshots,
  };
}

async function collectContentStressAudit(browser, viewport, colorScheme) {
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: 1,
    colorScheme,
  });
  const page = await context.newPage();
  await page.goto(baseURL, { waitUntil: 'networkidle' });

  const injection = await page.evaluate(() => {
    const stressValues = {
      'nav-title': 'DesignLoopOS_운영콘솔_CompanyMacBookPro_HomeMacBookAir',
      'nav-subtitle': 'ClaudeCode↔Codex↔getdesign.md↔DESIGN.md',
      'hero-heading': 'Same design brain, verified across every agent surface — 한국어긴제목검증문자열UI깨짐방지',
      'hero-copy': '긴 한국어 설명과 English localization fallback text must wrap predictably without clipping cards, buttons, or evidence panels across every viewport.',
      'metric-label': 'SYNCHRONIZATION_ATTESTATION_LABEL',
      'metric-value': '61a068167a206030dbf9e7c3a5c2d1e0f9a8b7c6',
      'feature-eyebrow': 'LOCALIZATION_STRESS_TEST',
      'feature-title': 'Long unbroken product title: ClaudeCodeCodexDesignLoopSynchronization',
      'feature-body': '사용자가붙여넣은긴한국어문장과SuperLongEnglishIdentifierWithoutSpacesShouldStillWrapInsideTheCardInsteadOfBreakingTheLayout.',
      'section-heading': 'State coverage with localization stress and long operator-facing copy',
      'section-copy': '번역문이 길어지고 회복 경로 설명이 추가되어도 섹션은 화면 폭 안에서 재배치되어야 하며 CTA와 카드가 잘리면 실패입니다.',
      'state-name': 'Localized state label with long fallback',
      'state-copy': 'Recovery path: run getdesign doctor --sync --verify --machine company-macbook-pro --target home-macbook-air and compare evidence.',
      'protocol-heading': 'Use the same design loop in Claude Code and Codex with long localized protocol headings.',
      'protocol-copy': 'Load getdesign.md, DESIGN.md, project-local docs, screenshots, DOM evidence, sha256 hashes, and compare every artifact before claiming completion.',
    };
    const targets = [...document.querySelectorAll('[data-content-stress]')];
    targets.forEach((node, index) => {
      const key = node.getAttribute('data-content-stress');
      const value = stressValues[key] ?? `StressTarget_${key}_${index}_SuperLongUnbrokenIdentifier`;
      if (key === 'code-panel') {
        node.textContent = '$ /Users/manager/development/design-loop-test/scripts/sync-attest --design-sha=61a068167a206030dbf9e7c3a5c2d1e0f9a8b7c6 --compare=claude-code,codex --localization=한국어긴명령어검증 --output=artifacts/very-long-proof-path.json';
        node.style.whiteSpace = 'nowrap';
      } else {
        node.textContent = value;
      }
    });
    return { mutatedTargets: targets.length };
  });
  await page.waitForTimeout(100);

  const audit = await page.evaluate(({ minTouchTarget }) => {
    const visible = (node) => {
      const style = getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      return style.visibility !== 'hidden' && style.display !== 'none' && Number(style.opacity) > 0 && rect.width > 0 && rect.height > 0;
    };
    const rectSummary = (selector) => {
      const node = document.querySelector(selector);
      if (!node) return { selector, exists: false, visible: false };
      const rect = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return {
        selector,
        exists: true,
        visible: style.visibility !== 'hidden' && style.display !== 'none' && rect.width > 0 && rect.height > 0,
        width: Number(rect.width.toFixed(2)),
        height: Number(rect.height.toFixed(2)),
        left: Number(rect.left.toFixed(2)),
        right: Number(rect.right.toFixed(2)),
        horizontallyClipped: rect.left < -1 || rect.right > window.innerWidth + 1,
      };
    };
    const sections = ['main', 'nav', '#verification', '#scenario', '#states', '#protocol'].map(rectSummary);
    const stressTargets = [...document.querySelectorAll('[data-content-stress]')]
      .filter(visible)
      .map((node) => {
        const rect = node.getBoundingClientRect();
        return {
          key: node.getAttribute('data-content-stress'),
          tag: node.tagName.toLowerCase(),
          text: node.textContent?.trim().replace(/\s+/g, ' ').slice(0, 96) ?? '',
          width: Number(rect.width.toFixed(2)),
          height: Number(rect.height.toFixed(2)),
          left: Number(rect.left.toFixed(2)),
          right: Number(rect.right.toFixed(2)),
          scrollWidth: node.scrollWidth,
          clientWidth: node.clientWidth,
          horizontallyClipped: rect.left < -1 || rect.right > window.innerWidth + 1,
        };
      });
    const anchorTargets = [...document.querySelectorAll('a')]
      .filter(visible)
      .map((node) => {
        const rect = node.getBoundingClientRect();
        return {
          text: node.textContent?.trim() ?? '',
          width: Number(rect.width.toFixed(2)),
          height: Number(rect.height.toFixed(2)),
          left: Number(rect.left.toFixed(2)),
          right: Number(rect.right.toFixed(2)),
          meetsTarget: rect.width >= minTouchTarget && rect.height >= minTouchTarget,
          horizontallyClipped: rect.left < -1 || rect.right > window.innerWidth + 1,
        };
      });
    const scrollContainers = [...document.querySelectorAll('body *')]
      .filter(visible)
      .map((node) => {
        const overflowX = node.scrollWidth - node.clientWidth;
        return {
          tag: node.tagName.toLowerCase(),
          text: node.textContent?.trim().replace(/\s+/g, ' ').slice(0, 96) ?? '',
          key: node.getAttribute('data-content-stress'),
          scrollWidth: node.scrollWidth,
          clientWidth: node.clientWidth,
          overflowX,
          allowed: node.hasAttribute('data-horizontal-scroll-ok'),
        };
      })
      .filter((item) => item.overflowX > 1);
    const horizontalOverflowPx = Math.max(
      0,
      document.documentElement.scrollWidth - document.documentElement.clientWidth,
      document.body.scrollWidth - document.body.clientWidth,
    );
    return {
      mutatedTargets: document.querySelectorAll('[data-content-stress]').length,
      horizontalOverflowPx,
      sections,
      missingOrHiddenSections: sections.filter((section) => !section.exists || !section.visible),
      horizontallyClippedSections: sections.filter((section) => section.horizontallyClipped),
      stressTargets,
      clippedStressTargets: stressTargets.filter((target) => target.horizontallyClipped),
      anchorTargets,
      undersizedAnchorTargets: anchorTargets.filter((target) => !target.meetsTarget),
      clippedAnchorTargets: anchorTargets.filter((target) => target.horizontallyClipped),
      scrollContainers,
      scrollContainerOffenders: scrollContainers.filter((item) => !item.allowed),
      allowedHorizontalScrollContainers: scrollContainers.filter((item) => item.allowed),
    };
  }, { minTouchTarget: viewport.minTouchTarget });

  const screenshotName = `design-loop-home-content-stress-${viewport.name}-${colorScheme}.png`;
  await page.screenshot({ path: new URL(screenshotName, outDir).pathname, fullPage: true });
  await context.close();

  return {
    ...injection,
    ...audit,
    screenshot: `artifacts/${screenshotName}`,
  };
}

let server;
if (!explicitBaseURL) {
  server = spawn('pnpm', ['exec', 'next', 'start', '--port', localPort], {
    stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, NEXT_TELEMETRY_DISABLED: '1' },
  });
  server.stdout.on('data', (data) => process.stdout.write(`[next] ${data}`));
  server.stderr.on('data', (data) => process.stderr.write(`[next] ${data}`));
  await waitForServer(baseURL);
} else if (!(await isReachable(baseURL))) {
  throw new Error(`BASE_URL is not reachable: ${baseURL}`);
}

const browser = await chromium.launch({ headless: true });
try {
  const results = [];
  const screenshots = [];

  for (const viewport of viewports) {
    for (const colorScheme of colorSchemes) {
      const context = await browser.newContext({
        viewport: { width: viewport.width, height: viewport.height },
        deviceScaleFactor: 1,
        colorScheme,
      });
      const page = await context.newPage();
      await page.goto(baseURL, { waitUntil: 'networkidle' });

      const result = await page.evaluate(({ scheme, viewportName, viewportWidth, viewportHeight, minTouchTarget }) => {
        const minGlobalTextContrast = 4.5;
        const parseRgba = (value) => {
          const match = value.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([0-9.]+))?\)/);
          if (!match) return null;
          return {
            rgb: match.slice(1, 4).map(Number),
            alpha: match[4] === undefined ? 1 : Number(match[4]),
          };
        };
        const composite = (over, under) => over.rgb.map((channel, index) => channel * over.alpha + under[index] * (1 - over.alpha));
        const luminance = (rgb) => {
          const [r, g, b] = rgb.map((v) => {
            const s = v / 255;
            return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
          });
          return 0.2126 * r + 0.7152 * g + 0.0722 * b;
        };
        const contrastRatio = (fg, bg) => {
          const a = luminance(fg);
          const b = luminance(bg);
          const light = Math.max(a, b);
          const dark = Math.min(a, b);
          return (light + 0.05) / (dark + 0.05);
        };
        const visible = (node) => {
          const style = getComputedStyle(node);
          const rect = node.getBoundingClientRect();
          return style.visibility !== 'hidden' && style.display !== 'none' && Number(style.opacity) > 0 && rect.width > 0 && rect.height > 0;
        };
        const hasDirectText = (node) => [...node.childNodes].some((child) => child.nodeType === Node.TEXT_NODE && child.textContent?.trim());
        const effectiveBackground = (node) => {
          const chain = [];
          let current = node;
          while (current && current.nodeType === Node.ELEMENT_NODE) {
            chain.push(current);
            current = current.parentElement;
          }
          let background = [255, 255, 255];
          for (const element of chain.reverse()) {
            const color = parseRgba(getComputedStyle(element).backgroundColor);
            if (color && color.alpha > 0) {
              background = composite(color, background);
            }
          }
          return background;
        };
        const rectSummary = (selector) => {
          const node = document.querySelector(selector);
          if (!node) return { selector, exists: false, visible: false };
          const rect = node.getBoundingClientRect();
          const style = getComputedStyle(node);
          return {
            selector,
            exists: true,
            visible: style.visibility !== 'hidden' && style.display !== 'none' && rect.width > 0 && rect.height > 0,
            width: Number(rect.width.toFixed(2)),
            height: Number(rect.height.toFixed(2)),
            left: Number(rect.left.toFixed(2)),
            right: Number(rect.right.toFixed(2)),
            horizontallyClipped: rect.left < -1 || rect.right > window.innerWidth + 1,
          };
        };
        const contrastAudits = [...document.querySelectorAll('body *')]
          .filter((node) => visible(node) && hasDirectText(node))
          .map((node) => {
            const style = getComputedStyle(node);
            const foreground = parseRgba(style.color);
            const background = effectiveBackground(node);
            const ratio = foreground ? contrastRatio(foreground.rgb, background) : null;
            const text = [...node.childNodes]
              .filter((child) => child.nodeType === Node.TEXT_NODE)
              .map((child) => child.textContent?.trim())
              .filter(Boolean)
              .join(' ')
              .slice(0, 96);
            return {
              tag: node.tagName.toLowerCase(),
              text,
              color: style.color,
              effectiveBackground: `rgb(${background.map((value) => Math.round(value)).join(', ')})`,
              contrastRatio: ratio === null ? null : Number(ratio.toFixed(2)),
            };
          });
        const lowContrastText = contrastAudits
          .filter((audit) => audit.contrastRatio === null || audit.contrastRatio < minGlobalTextContrast)
          .sort((a, b) => (a.contrastRatio ?? 0) - (b.contrastRatio ?? 0));
        const anchorTargets = [...document.querySelectorAll('a')]
          .filter((node) => visible(node))
          .map((node) => {
            const rect = node.getBoundingClientRect();
            return {
              text: node.textContent?.trim() ?? '',
              width: Number(rect.width.toFixed(2)),
              height: Number(rect.height.toFixed(2)),
              meetsTarget: rect.width >= minTouchTarget && rect.height >= minTouchTarget,
            };
          });
        const text = document.body.innerText;
        const heading = document.querySelector('h1')?.textContent?.trim() ?? '';
        const states = ['Loading', 'Empty', 'Error', 'Success'].filter((label) => text.includes(label));
        const ctaCount = [...document.querySelectorAll('a')].filter((a) => a.textContent?.trim()).length;
        const cards = document.querySelectorAll('article').length;
        const styles = getComputedStyle(document.body);
        const protocolPanel = document.querySelector('#protocol-panel');
        const protocolCopies = [...document.querySelectorAll('.protocol-step-copy')];
        const protocolPanelStyles = protocolPanel ? getComputedStyle(protocolPanel) : null;
        const protocolCopyStyles = protocolCopies.map((node) => {
          const nodeStyles = getComputedStyle(node);
          const cardStyles = getComputedStyle(node.closest('li') ?? protocolPanel ?? node);
          return {
            text: node.textContent?.trim() ?? '',
            color: nodeStyles.color,
            fontSize: nodeStyles.fontSize,
            cardBackground: cardStyles.backgroundColor,
            panelBackground: protocolPanelStyles?.backgroundColor ?? null,
          };
        });
        const sections = ['main', 'nav', '#verification', '#scenario', '#states', '#protocol'].map(rectSummary);
        const horizontallyClippedSections = sections.filter((section) => section.horizontallyClipped);
        const missingOrHiddenSections = sections.filter((section) => !section.exists || !section.visible);
        const horizontalOverflowPx = Math.max(
          0,
          document.documentElement.scrollWidth - document.documentElement.clientWidth,
          document.body.scrollWidth - document.body.clientWidth,
        );
        return {
          colorScheme: scheme,
          viewport: {
            name: viewportName,
            width: viewportWidth,
            height: viewportHeight,
            minTouchTarget,
          },
          title: document.title,
          heading,
          states,
          ctaCount,
          cards,
          background: styles.backgroundColor,
          color: styles.color,
          hasDesignHash: text.includes('61a06816'),
          hasAttestation: text.includes('omx doctor: 14 passed'),
          hasProtocolCopy: text.includes('Use the same design loop in Claude') && text.includes('Compare Claude Code and Codex evidence'),
          protocolTextColor: protocolCopyStyles[0]?.color ?? null,
          protocolTextFontSize: protocolCopyStyles[0]?.fontSize ?? null,
          protocolPanelBackground: protocolPanelStyles?.backgroundColor ?? null,
          protocolCopyStyles,
          contrastAudit: {
            minRequired: minGlobalTextContrast,
            checkedTextNodes: contrastAudits.length,
            lowest: contrastAudits
              .filter((audit) => audit.contrastRatio !== null)
              .sort((a, b) => a.contrastRatio - b.contrastRatio)
              .slice(0, 8),
            failures: lowContrastText.slice(0, 12),
          },
          layoutAudit: {
            horizontalOverflowPx,
            sections,
            missingOrHiddenSections,
            horizontallyClippedSections,
            anchorTargets,
            undersizedAnchorTargets: anchorTargets.filter((target) => !target.meetsTarget),
          },
        };
      }, {
        scheme: colorScheme,
        viewportName: viewport.name,
        viewportWidth: viewport.width,
        viewportHeight: viewport.height,
        minTouchTarget: viewport.minTouchTarget,
      });
      result.axeAudit = await collectAxeAudit(page);
      result.keyboardAudit = await collectKeyboardAudit(page);
      result.densityAudit = await collectDensityAudit(page);
      result.interactionAudit = await collectInteractionAudit(page);
      result.hierarchyAudit = await collectHierarchyAudit(page);
      result.copyQualityAudit = await collectCopyQualityAudit(page);
      result.reducedMotionAudit = await collectReducedMotionAudit(browser, viewport, colorScheme);
      result.forcedColorsAudit = await collectForcedColorsAudit(browser, viewport, colorScheme);
      screenshots.push(result.forcedColorsAudit.screenshot);
      result.textZoomAudit = await collectTextZoomAudit(browser, viewport, colorScheme);
      screenshots.push(...result.textZoomAudit.screenshots);
      result.contentStressAudit = await collectContentStressAudit(browser, viewport, colorScheme);
      screenshots.push(result.contentStressAudit.screenshot);

      const screenshotName = `design-loop-home-${viewport.name}-${colorScheme}.png`;
      await page.screenshot({ path: new URL(screenshotName, outDir).pathname, fullPage: true });
      screenshots.push(`artifacts/${screenshotName}`);
      if (viewport.name === 'wide' && colorScheme === 'light') {
        await page.screenshot({ path: new URL('design-loop-home.png', outDir).pathname, fullPage: true });
      }
      if (viewport.name === 'wide') {
        await page.screenshot({ path: new URL(`design-loop-home-${colorScheme}.png`, outDir).pathname, fullPage: true });
      }
      await context.close();
      results.push(result);
    }
  }

  const failures = [];
  for (const result of results) {
    const prefix = `[${result.viewport.name}/${result.colorScheme}]`;
    if (result.title !== 'Design Loop OS') failures.push(`${prefix} unexpected title: ${result.title}`);
    if (!result.heading.includes('Same design brain')) failures.push(`${prefix} missing expected hero heading`);
    if (result.states.length !== 4) failures.push(`${prefix} expected 4 states, got ${result.states.length}: ${result.states.join(', ')}`);
    if (result.cards < 3) failures.push(`${prefix} expected at least 3 feature cards, got ${result.cards}`);
    if (result.ctaCount < 3) failures.push(`${prefix} expected at least 3 links/CTAs, got ${result.ctaCount}`);
    if (!result.hasDesignHash) failures.push(`${prefix} missing design hash evidence`);
    if (!result.hasAttestation) failures.push(`${prefix} missing attestation text`);
    if (!result.hasProtocolCopy) failures.push(`${prefix} missing updated protocol copy`);
    if (result.contrastAudit.failures.length) {
      failures.push(`${prefix} ${result.contrastAudit.failures.length} visible text contrast failures below ${minGlobalTextContrast}`);
    }
    if (result.layoutAudit.horizontalOverflowPx > 1) {
      failures.push(`${prefix} horizontal overflow ${result.layoutAudit.horizontalOverflowPx}px`);
    }
    if (result.layoutAudit.missingOrHiddenSections.length) {
      failures.push(`${prefix} missing/hidden sections: ${result.layoutAudit.missingOrHiddenSections.map((section) => section.selector).join(', ')}`);
    }
    if (result.layoutAudit.horizontallyClippedSections.length) {
      failures.push(`${prefix} horizontally clipped sections: ${result.layoutAudit.horizontallyClippedSections.map((section) => section.selector).join(', ')}`);
    }
    if (result.layoutAudit.undersizedAnchorTargets.length) {
      failures.push(`${prefix} undersized anchor targets: ${result.layoutAudit.undersizedAnchorTargets.map((target) => `${target.text} ${target.width}x${target.height}`).join(', ')}`);
    }
    if (result.keyboardAudit.actualOrder.join('|') !== expectedFocusOrder.join('|')) {
      failures.push(`${prefix} unexpected focus order: ${result.keyboardAudit.actualOrder.join(' -> ')}`);
    }
    const weakFocusSteps = result.keyboardAudit.steps.filter((step) => !step.visible || !step.focusVisible || !step.hasFocusIndicator);
    if (weakFocusSteps.length) {
      failures.push(`${prefix} weak focus indicators: ${weakFocusSteps.map((step) => `${step.text || step.tag} visible=${step.visible} focusVisible=${step.focusVisible} indicator=${step.hasFocusIndicator}`).join(', ')}`);
    }
    if (result.axeAudit.violations.length) {
      failures.push(`${prefix} axe violations: ${result.axeAudit.violations.map((violation) => `${violation.id}(${violation.impact})`).join(', ')}`);
    }
    if (result.densityAudit.groupCount < 5) {
      failures.push(`${prefix} expected at least 5 density groups, got ${result.densityAudit.groupCount}`);
    }
    if (result.densityAudit.groupFailures.length) {
      failures.push(`${prefix} density group spacing failures: ${result.densityAudit.groupFailures.map((item) => `${item.group} ${item.first} ↔ ${item.second} gap=${item.gap} min=${item.minGap} overlaps=${item.overlaps}`).join(', ')}`);
    }
    if (result.densityAudit.hitAreaFailures.length) {
      failures.push(`${prefix} hit-area separation failures: ${result.densityAudit.hitAreaFailures.map((item) => `${item.first} ↔ ${item.second} gap=${item.gap} min=${item.minGap} overlaps=${item.overlaps}`).join(', ')}`);
    }
    if (result.interactionAudit.probeCount < 3) {
      failures.push(`${prefix} expected at least 3 interaction probes, got ${result.interactionAudit.probeCount}`);
    }
    if (result.interactionAudit.hoverFailures.length) {
      failures.push(`${prefix} hover state did not produce visible style changes: ${result.interactionAudit.hoverFailures.map((item) => item.name).join(', ')}`);
    }
    if (result.interactionAudit.activeFailures.length) {
      failures.push(`${prefix} active state did not produce visible style changes: ${result.interactionAudit.activeFailures.map((item) => item.name).join(', ')}`);
    }
    if (result.interactionAudit.stateFailures.length) {
      failures.push(`${prefix} interaction state failures: ${result.interactionAudit.stateFailures.join(', ')}`);
    }
    if (result.hierarchyAudit.failures.length) {
      failures.push(`${prefix} visual hierarchy failures: ${result.hierarchyAudit.failures.join(', ')}`);
    }
    if (result.copyQualityAudit.failures.length) {
      failures.push(`${prefix} copy quality failures: ${result.copyQualityAudit.failures.join(', ')}`);
    }
    if (!result.reducedMotionAudit.mediaMatches) {
      failures.push(`${prefix} reduced motion media query did not match in audit context`);
    }
    if (result.reducedMotionAudit.scrollBehavior !== 'auto') {
      failures.push(`${prefix} reduced motion scroll-behavior should be auto, got ${result.reducedMotionAudit.scrollBehavior}`);
    }
    if (result.reducedMotionAudit.motionOffenders.length) {
      failures.push(`${prefix} reduced motion CSS offenders: ${result.reducedMotionAudit.motionOffenders.map((item) => `${item.tag} "${item.text}" transition=${item.transitionDuration}/${item.transitionDelay} animation=${item.animationName} ${item.animationDuration}/${item.animationDelay}`).join(', ')}`);
    }
    if (result.reducedMotionAudit.hoverMotionOffenders.length) {
      failures.push(`${prefix} reduced motion hover movement: ${result.reducedMotionAudit.hoverMotionOffenders.map((item) => `${item.tag} "${item.text}" transformChanged=${item.transformChanged} rectChanged=${item.rectChanged}`).join(', ')}`);
    }
    if (!result.forcedColorsAudit.mediaMatches) {
      failures.push(`${prefix} forced-colors media query did not match in audit context`);
    }
    if (result.forcedColorsAudit.contrastAudit.failures.length) {
      failures.push(`${prefix} ${result.forcedColorsAudit.contrastAudit.failures.length} forced-colors text contrast failures below ${result.forcedColorsAudit.contrastAudit.minRequired}`);
    }
    if (result.forcedColorsAudit.boundaryAudit.checkedBoundaries < 10) {
      failures.push(`${prefix} expected at least 10 forced-colors boundaries, got ${result.forcedColorsAudit.boundaryAudit.checkedBoundaries}`);
    }
    if (result.forcedColorsAudit.boundaryAudit.failures.length) {
      failures.push(`${prefix} forced-colors boundary failures: ${result.forcedColorsAudit.boundaryAudit.failures.map((item) => `${item.tag} "${item.text}" border=${item.borderWidth}px ${item.borderStyle} ${item.borderColor}`).join(', ')}`);
    }
    if (result.forcedColorsAudit.backgroundImageOffenders.length) {
      failures.push(`${prefix} forced-colors background image offenders: ${result.forcedColorsAudit.backgroundImageOffenders.map((item) => `${item.tag} "${item.text}" bg=${item.backgroundImage}`).join(', ')}`);
    }
    if (result.forcedColorsAudit.keyboardAudit.actualOrder.join('|') !== expectedFocusOrder.join('|')) {
      failures.push(`${prefix} forced-colors unexpected focus order: ${result.forcedColorsAudit.keyboardAudit.actualOrder.join(' -> ')}`);
    }
    const weakForcedColorsFocusSteps = result.forcedColorsAudit.keyboardAudit.steps.filter((step) => !step.visible || !step.focusVisible || !step.hasFocusIndicator);
    if (weakForcedColorsFocusSteps.length) {
      failures.push(`${prefix} forced-colors weak focus indicators: ${weakForcedColorsFocusSteps.map((step) => `${step.text || step.tag} visible=${step.visible} focusVisible=${step.focusVisible} indicator=${step.hasFocusIndicator}`).join(', ')}`);
    }
    for (const zoomLevel of result.textZoomAudit.levels) {
      const zoomPrefix = `${prefix} text zoom ${zoomLevel.zoomPercent}%`;
      if (zoomLevel.horizontalOverflowPx > 1) {
        failures.push(`${zoomPrefix} horizontal overflow ${zoomLevel.horizontalOverflowPx}px`);
      }
      if (zoomLevel.missingOrHiddenSections.length) {
        failures.push(`${zoomPrefix} missing/hidden sections: ${zoomLevel.missingOrHiddenSections.map((section) => section.selector).join(', ')}`);
      }
      if (zoomLevel.horizontallyClippedSections.length) {
        failures.push(`${zoomPrefix} horizontally clipped sections: ${zoomLevel.horizontallyClippedSections.map((section) => section.selector).join(', ')}`);
      }
      if (zoomLevel.undersizedAnchorTargets.length) {
        failures.push(`${zoomPrefix} undersized anchor targets: ${zoomLevel.undersizedAnchorTargets.map((target) => `${target.text} ${target.width}x${target.height}`).join(', ')}`);
      }
      if (zoomLevel.clippedAnchorTargets.length) {
        failures.push(`${zoomPrefix} clipped anchor targets: ${zoomLevel.clippedAnchorTargets.map((target) => `${target.text} left=${target.left} right=${target.right}`).join(', ')}`);
      }
      if (zoomLevel.zoomPercent === 200 && !zoomLevel.screenshot) {
        failures.push(`${zoomPrefix} missing 200% text zoom screenshot`);
      }
    }
    if (result.contentStressAudit.mutatedTargets < 16) {
      failures.push(`${prefix} expected at least 16 content stress targets, got ${result.contentStressAudit.mutatedTargets}`);
    }
    if (result.contentStressAudit.horizontalOverflowPx > 1) {
      failures.push(`${prefix} content stress horizontal overflow ${result.contentStressAudit.horizontalOverflowPx}px`);
    }
    if (result.contentStressAudit.missingOrHiddenSections.length) {
      failures.push(`${prefix} content stress missing/hidden sections: ${result.contentStressAudit.missingOrHiddenSections.map((section) => section.selector).join(', ')}`);
    }
    if (result.contentStressAudit.horizontallyClippedSections.length) {
      failures.push(`${prefix} content stress horizontally clipped sections: ${result.contentStressAudit.horizontallyClippedSections.map((section) => section.selector).join(', ')}`);
    }
    if (result.contentStressAudit.clippedStressTargets.length) {
      failures.push(`${prefix} content stress clipped targets: ${result.contentStressAudit.clippedStressTargets.map((target) => `${target.key}:${target.tag} left=${target.left} right=${target.right}`).join(', ')}`);
    }
    if (result.contentStressAudit.undersizedAnchorTargets.length) {
      failures.push(`${prefix} content stress undersized anchor targets: ${result.contentStressAudit.undersizedAnchorTargets.map((target) => `${target.text} ${target.width}x${target.height}`).join(', ')}`);
    }
    if (result.contentStressAudit.clippedAnchorTargets.length) {
      failures.push(`${prefix} content stress clipped anchor targets: ${result.contentStressAudit.clippedAnchorTargets.map((target) => `${target.text} left=${target.left} right=${target.right}`).join(', ')}`);
    }
    if (result.contentStressAudit.scrollContainerOffenders.length) {
      failures.push(`${prefix} content stress unapproved horizontal scroll containers: ${result.contentStressAudit.scrollContainerOffenders.map((item) => `${item.key || item.tag} overflow=${item.overflowX}`).join(', ')}`);
    }
    if (!result.contentStressAudit.screenshot) {
      failures.push(`${prefix} missing content stress screenshot`);
    }
    if (result.protocolTextFontSize !== '16px') failures.push(`${prefix} protocol copy should be 16px, got ${result.protocolTextFontSize}`);
    if (result.protocolCopyStyles.length !== 4) failures.push(`${prefix} expected 4 protocol copy items, got ${result.protocolCopyStyles.length}`);
    const fg = parseRgb(result.protocolTextColor ?? '');
    const bg = parseRgb(result.protocolPanelBackground ?? '');
    if (!fg || !bg) {
      failures.push(`${prefix} cannot parse protocol contrast colors: fg=${result.protocolTextColor}, bg=${result.protocolPanelBackground}`);
    } else {
      const ratio = contrastRatio(fg, bg);
      result.protocolContrastRatio = Number(ratio.toFixed(2));
      if (ratio < 7) failures.push(`${prefix} protocol contrast below AAA target: ${ratio.toFixed(2)}`);
    }
    result.protocolCopyContrastRatios = result.protocolCopyStyles.map((copy, index) => {
      const copyFg = parseRgb(copy.color ?? '');
      const panelBg = parseRgb(copy.panelBackground ?? '');
      const cardBg = parseRgba(copy.cardBackground ?? '');
      const copyBg = cardBg && panelBg ? composite(cardBg, panelBg) : panelBg;
      if (!copyFg || !copyBg) {
        failures.push(`${prefix} cannot parse protocol card ${index + 1} contrast colors: fg=${copy.color}, bg=${copy.cardBackground}`);
        return null;
      }
      const ratio = contrastRatio(copyFg, copyBg);
      const rounded = Number(ratio.toFixed(2));
      if (ratio < 7) failures.push(`${prefix} protocol card ${index + 1} contrast below AAA target: ${rounded}`);
      return rounded;
    });
  }

  await fs.writeFile(new URL('visual-check.json', outDir), JSON.stringify({ results, failures, screenshots }, null, 2));

  if (failures.length) {
    console.error(JSON.stringify({ ok: false, failures, results }, null, 2));
    process.exitCode = 1;
  } else {
    console.log(JSON.stringify({ ok: true, screenshots, checkedScenarios: results.length, results }, null, 2));
  }
} finally {
  await browser.close();
  if (server && !server.killed) {
    server.kill('SIGTERM');
  }
}

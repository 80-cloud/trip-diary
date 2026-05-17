// a11y 監査の共通 helper (sns-board 踏襲)。
// 本 PR (Pivot-3 PR-A) では smoke のみで使わないが、後続 PR-E の a11y spec で利用するため雛形を配置。
//
// 戦略: critical のみ fail させ、serious/moderate/minor は console.log で可視化 (段階的解消)。

import AxeBuilder from '@axe-core/playwright';

async function runA11yScan(page, { disableRules = [] } = {}) {
  const builder = new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a']);
  if (disableRules.length > 0) {
    builder.disableRules(disableRules);
  }
  return builder.analyze();
}

export async function expectNoCriticalA11yViolations(page, { label = page.url() } = {}) {
  const results = await runA11yScan(page);
  const violations = results.violations || [];

  if (violations.length > 0) {
    console.log(`\n[a11y] ${label} に ${violations.length} 件の違反:`);
    for (const v of violations) {
      console.log(`  - [${v.impact}] ${v.id}: ${v.help} (${v.nodes.length} nodes)`);
    }
  }

  const critical = violations.filter((v) => v.impact === 'critical');
  if (critical.length > 0) {
    throw new Error(
      `[a11y] critical violations on ${label}:\n` +
        JSON.stringify(critical, null, 2),
    );
  }
  return violations;
}

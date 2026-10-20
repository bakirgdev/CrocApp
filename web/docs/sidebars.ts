import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// Hand-written so the groups follow the task the reader is doing, not the
// directory a file sits in. Every doc under content/ must appear here once: a
// missing one gets no sidebar.
//
// Groups are plain `html` headings, not categories: a category with no `link`
// renders its label as an <a> without href (fails Lighthouse crawlable-anchors),
// and one with a `link` generates a thin /category/ page.
function group(label: string, items: string[]) {
  return [
    {type: 'html' as const, value: label, className: 'sidebar-group', defaultStyle: true},
    ...items,
  ];
}

const sidebars: SidebarsConfig = {
  docs: [
    'index',
    ...group('Getting started', [
      'getting-started/install',
      'getting-started/first-transfer',
      'getting-started/verify-downloads',
    ]),
    ...group('Send and receive', [
      'guide/sending',
      'guide/receiving',
      'guide/code-phrases',
      'guide/send-as-link',
    ]),
    ...group('Customize', [
      'guide/settings',
      'guide/history',
      'guide/menu-bar',
      'guide/shortcuts',
    ]),
    ...group('Help', ['troubleshooting', 'faq', 'security-and-privacy', 'uninstall']),
    ...group('Reference', ['reference/croc-cli-interop']),
    'contribute',
  ],
};

export default sidebars;

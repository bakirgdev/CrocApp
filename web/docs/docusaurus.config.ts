import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

// crocapp.dev is the landing page. GitHub Pages serves one site per repo, so
// the docs live under /docs/ of that same artifact and both surfaces are
// published together by scripts/assemble-site.sh.
const config: Config = {
  title: 'CrocApp',
  tagline: 'Encrypted file transfer for iOS and macOS',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://crocapp.dev',
  baseUrl: '/docs/',
  trailingSlash: true,

  organizationName: 'bakirgdev',
  projectName: 'CrocApp',

  onBrokenLinks: 'throw',
  onBrokenAnchors: 'throw',

  markdown: {
    // `.md` is CommonMark, `.mdx` is MDX. The default ('mdx' for both) makes a
    // bare `{` open a JavaScript expression, which breaks `## Heading {#id}`
    // and turns any brace a translator types into a build failure. No page here
    // uses JSX, so nothing is given up.
    format: 'detect',
    hooks: {
      onBrokenMarkdownLinks: 'throw',
      onBrokenMarkdownImages: 'throw',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'bs', 'de', 'es', 'fr', 'ru'],
    localeConfigs: {
      en: {label: 'English', htmlLang: 'en-US'},
      bs: {label: 'Bosanski', htmlLang: 'bs-BA'},
      de: {label: 'Deutsch', htmlLang: 'de-DE'},
      es: {label: 'Español', htmlLang: 'es-ES'},
      fr: {label: 'Français', htmlLang: 'fr-FR'},
      ru: {label: 'Русский', htmlLang: 'ru-RU'},
    },
  },

  presets: [
    [
      'classic',
      {
        docs: {
          // `content/`, not `docs/`: the repo already has a docs/ directory and
          // it means something else (contributor and architecture material).
          path: 'content',
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/bakirgdev/CrocApp/tree/main/web/docs/',
          editLocalizedFiles: true,
          showLastUpdateTime: true,
          // Current *is* 0.9.9, rather than an unlabeled "Next" sitting on top
          // of a duplicated snapshot. Nothing has shipped yet, so a
          // versioned_docs/ copy would only be a second place to edit. Cut the
          // first snapshot when 1.0.0 tags: `pnpm run docusaurus docs:version`.
          lastVersion: 'current',
          versions: {
            current: {label: '0.9.9'},
          },
        },
        // No blog. Release notes belong in GitHub Releases and CHANGELOG.md.
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/og.jpg',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'CrocApp',
      logo: {
        alt: 'CrocApp',
        src: 'img/mascot.webp',
      },
      items: [
        {
          href: 'https://crocapp.dev/',
          label: 'crocapp.dev',
          position: 'left',
          target: '_self',
        },
        {
          type: 'docsVersionDropdown',
          position: 'right',
        },
        {
          type: 'localeDropdown',
          position: 'right',
        },
        {
          href: 'https://github.com/bakirgdev/CrocApp',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {label: 'Install', to: '/getting-started/install'},
            {label: 'First transfer', to: '/getting-started/first-transfer'},
            {label: 'Security and privacy', to: '/security-and-privacy'},
            {label: 'Troubleshooting', to: '/troubleshooting'},
          ],
        },
        {
          title: 'Project',
          items: [
            {label: 'crocapp.dev', href: 'https://crocapp.dev/'},
            {label: 'GitHub', href: 'https://github.com/bakirgdev/CrocApp'},
            {
              label: 'Issues',
              href: 'https://github.com/bakirgdev/CrocApp/issues',
            },
            {
              label: 'Discussions',
              href: 'https://github.com/bakirgdev/CrocApp/discussions',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'Contributing',
              href: 'https://github.com/bakirgdev/CrocApp/blob/main/CONTRIBUTING.md',
            },
            {
              label: 'Security policy',
              href: 'https://github.com/bakirgdev/CrocApp/blob/main/SECURITY.md',
            },
            {
              label: 'croc',
              href: 'https://github.com/schollz/croc',
            },
            {
              label: 'License',
              href: 'https://github.com/bakirgdev/CrocApp/blob/main/LICENSE',
            },
          ],
        },
      ],
      copyright:
        'CrocApp is MIT licensed and unaffiliated with croc. Built with Docusaurus.',
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'json', 'swift', 'go'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;

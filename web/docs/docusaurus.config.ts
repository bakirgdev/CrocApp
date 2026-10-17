import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import prismTheme from './src/prismTheme';

// crocapp.dev is the landing page. GitHub Pages serves one site per repo, so
// the docs live under /docs/ of that same artifact and both surfaces are
// published together by scripts/assemble-site.sh.
const config: Config = {
  title: 'CrocApp',
  tagline: 'End-to-end encrypted file transfer for iPhone, iPad and Mac',
  favicon: 'img/favicon.ico',

  // `faster` is what makes @docusaurus/faster a real dependency: Rspack, SWC
  // and Lightning CSS instead of webpack, Babel and cssnano.
  future: {
    v4: true,
    faster: true,
  },

  // The theme-color values are the two literals web may write (design/web.md):
  // browser chrome cannot take a custom property. They are --bg-base light and dark.
  headTags: [
    {
      tagName: 'meta',
      attributes: {
        name: 'theme-color',
        content: '#FFFFFF',
        media: '(prefers-color-scheme: light)',
      },
    },
    {
      tagName: 'meta',
      attributes: {
        name: 'theme-color',
        content: '#000000',
        media: '(prefers-color-scheme: dark)',
      },
    },
    {
      tagName: 'link',
      attributes: {
        rel: 'apple-touch-icon',
        href: '/docs/img/apple-touch-icon.png',
      },
    },
  ],

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
    locales: ['en'],
    localeConfigs: {
      en: {label: 'English', htmlLang: 'en-US'},
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
          showLastUpdateTime: true,
          // Current *is* 1.0 (release 1.0.0, see package.json), rather than an
          // unlabeled "Next" sitting on top of a duplicated snapshot, so a
          // versioned_docs/ copy would only be a second place to edit. No
          // snapshot of the earlier build is cut. Cut the first one when a
          // release changes behavior this site must still describe for the
          // old version: `pnpm run docusaurus docs:version 1.0`.
          lastVersion: 'current',
          versions: {
            current: {label: '1.0'},
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
          href: 'https://github.com/bakirgdev/CrocApp',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    // No `style: 'dark'`: it pins Infima's own slate footer palette locally and
    // beats the token mappings in src/css/custom.css.
    footer: {
      links: [
        {
          title: 'Docs',
          items: [
            {label: 'Install', to: '/getting-started/install'},
            {label: 'First Transfer', to: '/getting-started/first-transfer'},
            {label: 'Security and Privacy', to: '/security-and-privacy'},
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
              label: 'Security Policy',
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
        'Built on croc by Zack Scholl (MIT). CrocApp is unofficial and not affiliated with croc.',
    },
    prism: {
      theme: prismTheme,
      darkTheme: prismTheme,
      additionalLanguages: ['bash', 'json', 'swift', 'go'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
